// antphone_updater — pull-based update agent for the Star Learner phone.
//
// Runs as root from the Magisk boot agent. Polls the hub on 245 for a
// manifest, sha256-verifies and installs changed APKs, refreshes the
// launcher catalog. Designed to work from any network the phone is on.
//
// TLS: either pin the server's SPKI (pin=<hex sha256>, works with the
// self-signed hub cert) or verify against the embedded ISRG Root X1
// (Let's Encrypt) once the domain + ACME cert are live.
//
// Android note: GOOS=linux binaries have no /etc/resolv.conf, so DNS for
// the hub hostname goes through the resolver named in `resolve=` (default
// 1.1.1.1:53).
package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

//go:embed isrg_root_x1.pem
var isrgRootPEM []byte

const (
	catalogDst  = "/sdcard/AntPhone/catalog.json"
	tmpDir      = "/data/local/tmp"
	launcherPkg = "com.dylan.antexplorer"
)

type Config struct {
	URL      string        // base, e.g. https://hub.starlearner.app:8443/starlearner
	Token    string        // bearer token
	Interval time.Duration // poll interval
	Pin      string        // optional hex sha256 of server leaf SPKI
	Resolve  string        // DNS server, e.g. 1.1.1.1:53
}

type ManifestFile struct {
	File    string `json:"file"`
	Package string `json:"package,omitempty"`
	SHA256  string `json:"sha256"`
	Size    int64  `json:"size"`
}

type Manifest struct {
	Version     int64          `json:"version"`
	GeneratedAt string         `json:"generated_at"`
	Catalog     ManifestFile   `json:"catalog"`
	APKs        []ManifestFile `json:"apks"`
}

type State struct {
	CatalogSHA string            `json:"catalog_sha256"`
	APKs       map[string]string `json:"apks"` // package -> sha256
}

func loadConfig(p string) (*Config, error) {
	raw, err := os.ReadFile(p)
	if err != nil {
		return nil, err
	}
	c := &Config{Interval: 5 * time.Minute, Resolve: "1.1.1.1:53"}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		v = strings.TrimSpace(v)
		switch strings.TrimSpace(k) {
		case "url":
			c.URL = strings.TrimRight(v, "/")
		case "token":
			c.Token = v
		case "interval":
			d, err := time.ParseDuration(v)
			if err != nil {
				return nil, fmt.Errorf("bad interval %q: %v", v, err)
			}
			c.Interval = d
		case "pin":
			c.Pin = strings.ToLower(v)
		case "resolve":
			c.Resolve = v
		}
	}
	if c.URL == "" || c.Token == "" {
		return nil, errors.New("config needs url= and token=")
	}
	return c, nil
}

func loadState(p string) *State {
	st := &State{APKs: map[string]string{}}
	raw, err := os.ReadFile(p)
	if err == nil {
		_ = json.Unmarshal(raw, st)
	}
	if st.APKs == nil {
		st.APKs = map[string]string{}
	}
	return st
}

func saveState(p string, st *State) {
	raw, _ := json.MarshalIndent(st, "", "  ")
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, raw, 0600); err != nil {
		log.Printf("state write: %v", err)
		return
	}
	_ = os.Rename(tmp, p)
}

func buildClient(c *Config) (*http.Client, error) {
	u, err := url.Parse(c.URL)
	if err != nil {
		return nil, err
	}
	tr := &http.Transport{}
	switch u.Scheme {
	case "http":
		h := u.Hostname()
		if h != "127.0.0.1" && h != "localhost" {
			return nil, errors.New("plain http only allowed to loopback (testing)")
		}
	case "https":
		tlsc := &tls.Config{}
		if c.Pin != "" {
			want, err := hex.DecodeString(c.Pin)
			if err != nil || len(want) != 32 {
				return nil, fmt.Errorf("bad pin %q", c.Pin)
			}
			// Pin the SPKI of any cert in the presented chain; hostname
			// and CA are irrelevant when pinned.
			tlsc.InsecureSkipVerify = true
			tlsc.VerifyPeerCertificate = func(raw [][]byte, _ [][]*x509.Certificate) error {
				for _, rc := range raw {
					cert, err := x509.ParseCertificate(rc)
					if err != nil {
						continue
					}
					sum := sha256.Sum256(cert.RawSubjectPublicKeyInfo)
					if bytes.Equal(sum[:], want) {
						return nil
					}
				}
				return errors.New("certificate pin mismatch")
			}
		} else {
			pool := x509.NewCertPool()
			if !pool.AppendCertsFromPEM(isrgRootPEM) {
				return nil, errors.New("embedded root parse failed")
			}
			tlsc.RootCAs = pool
		}
		tr.TLSClientConfig = tlsc
	default:
		return nil, fmt.Errorf("unsupported scheme %q", u.Scheme)
	}

	if c.Resolve != "" {
		dialer := &net.Dialer{Timeout: 15 * time.Second}
		res := &net.Resolver{
			PreferGo: true,
			Dial: func(ctx context.Context, network, addr string) (net.Conn, error) {
				return dialer.DialContext(ctx, "udp", c.Resolve)
			},
		}
		tr.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			host, port, err := net.SplitHostPort(addr)
			if err != nil {
				return nil, err
			}
			if net.ParseIP(host) != nil {
				return dialer.DialContext(ctx, network, addr)
			}
			ips, err := res.LookupHost(ctx, host)
			if err != nil || len(ips) == 0 {
				return nil, fmt.Errorf("resolve %s via %s: %v", host, c.Resolve, err)
			}
			return dialer.DialContext(ctx, network, net.JoinHostPort(ips[0], port))
		}
	}
	return &http.Client{Transport: tr, Timeout: 30 * time.Minute}, nil
}

func get(client *http.Client, c *Config, path string) (*http.Response, error) {
	req, err := http.NewRequest("GET", c.URL+"/"+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.Token)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		resp.Body.Close()
		return nil, fmt.Errorf("GET %s: HTTP %d", path, resp.StatusCode)
	}
	return resp, nil
}

func fetchManifest(client *http.Client, c *Config) (*Manifest, error) {
	resp, err := get(client, c, "manifest.json")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var m Manifest
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&m); err != nil {
		return nil, fmt.Errorf("manifest decode: %v", err)
	}
	return &m, nil
}

// download fetches files/<name> to dst and verifies its sha256.
func download(client *http.Client, c *Config, name, dst, wantSHA string) error {
	resp, err := get(client, c, "files/"+url.PathEscape(name))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	f, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	h := sha256.New()
	_, err = io.Copy(io.MultiWriter(f, h), resp.Body)
	cerr := f.Close()
	if err != nil {
		return err
	}
	if cerr != nil {
		return cerr
	}
	got := hex.EncodeToString(h.Sum(nil))
	if !strings.EqualFold(got, wantSHA) {
		os.Remove(dst)
		return fmt.Errorf("%s sha mismatch: got %s want %s", name, got, wantSHA)
	}
	return nil
}

func run(cmd string, args ...string) (string, error) {
	out, err := exec.Command(cmd, args...).CombinedOutput()
	return string(out), err
}

func cycle(client *http.Client, c *Config, st *State, statePath string, seed bool) error {
	m, err := fetchManifest(client, c)
	if err != nil {
		return err
	}
	changed := false
	for _, a := range m.APKs {
		pkg := a.Package
		if pkg == "" {
			pkg = strings.TrimSuffix(a.File, ".apk")
		}
		if strings.EqualFold(st.APKs[pkg], a.SHA256) {
			continue
		}
		if seed {
			st.APKs[pkg] = strings.ToLower(a.SHA256)
			changed = true
			continue
		}
		log.Printf("updating %s (%s, %d bytes)", pkg, a.File, a.Size)
		fp := filepath.Join(tmpDir, "upd_"+a.File)
		if err := download(client, c, a.File, fp, a.SHA256); err != nil {
			return err
		}
		out, err := run("pm", "install", "-r", "-g", fp)
		os.Remove(fp)
		if err != nil || !strings.Contains(out, "Success") {
			return fmt.Errorf("pm install %s: %v: %s", pkg, err, strings.TrimSpace(out))
		}
		st.APKs[pkg] = strings.ToLower(a.SHA256)
		changed = true
		saveState(statePath, st)
		log.Printf("installed %s", pkg)
	}
	if m.Catalog.SHA256 != "" && !strings.EqualFold(st.CatalogSHA, m.Catalog.SHA256) {
		if seed {
			st.CatalogSHA = strings.ToLower(m.Catalog.SHA256)
			changed = true
		} else {
			fp := filepath.Join(tmpDir, "upd_catalog.json")
			if err := download(client, c, m.Catalog.File, fp, m.Catalog.SHA256); err != nil {
				return err
			}
			_, _ = run("mkdir", "-p", filepath.Dir(catalogDst))
			if out, err := run("cp", "-f", fp, catalogDst); err != nil {
				return fmt.Errorf("catalog cp: %v: %s", err, out)
			}
			os.Remove(fp)
			st.CatalogSHA = strings.ToLower(m.Catalog.SHA256)
			changed = true
			saveState(statePath, st)
			log.Printf("catalog updated (manifest v%d); refreshing launcher", m.Version)
			_, _ = run("am", "force-stop", launcherPkg)
			_, _ = run("am", "start", "-a", "android.intent.action.MAIN",
				"-c", "android.intent.category.HOME")
		}
	}
	if changed {
		saveState(statePath, st)
		log.Printf("in sync at manifest v%d", m.Version)
	}
	return nil
}

func main() {
	confPath := flag.String("conf", "/data/adb/antphone/updater.conf", "config file")
	statePath := flag.String("state", "/data/adb/antphone/updater_state.json", "state file")
	once := flag.Bool("once", false, "run a single cycle and exit")
	seed := flag.Bool("seed", false, "record current manifest as installed without installing")
	flag.Parse()
	log.SetFlags(log.LstdFlags)
	log.SetPrefix("updater ")

	c, err := loadConfig(*confPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	client, err := buildClient(c)
	if err != nil {
		log.Fatalf("client: %v", err)
	}
	st := loadState(*statePath)

	for {
		if err := cycle(client, c, st, *statePath, *seed); err != nil {
			log.Printf("cycle: %v", err)
		}
		if *once || *seed {
			return
		}
		jitter := time.Duration(rand.Int63n(int64(c.Interval) / 5))
		time.Sleep(c.Interval + jitter)
	}
}
