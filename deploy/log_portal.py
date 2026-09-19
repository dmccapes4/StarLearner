#!/usr/bin/env python3
"""Star Learner ops portal (loopback :8771): ASR journal + fogona APK queue.

Nginx terminates TLS and basic-auth (/logs/, /ops/).

Queue is staging-only (multi-job). Delivery is a one-shot triggered by
"Deliver now" (no background polling of 245).
"""
from __future__ import annotations

import html
import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

HOST = "127.0.0.1"
PORT = 8771
LINES = 250
ASR_UNIT = "starlearner-asr.service"
QUEUE_UNIT = "starlearner-fogona-queue.service"
ROOT = Path(__file__).resolve().parents[1]
QUEUE_DIR = Path(os.environ.get("STARLEARNER_QUEUE_DIR", str(ROOT / "deploy" / "queue")))
JOBS_DIR = QUEUE_DIR / "jobs"
LEGACY_JOB = QUEUE_DIR / "job.json"
GARDEN_APK = ROOT / "garden_explorer/tools/build/com.dylan.garden_explorer.apk"
LANGUAGE_APK = ROOT / "language_explorer/tools/build/com.dylan.language_explorer.apk"
QUEUE_SCRIPT = ROOT / "tools/queue_fogona_deliver.sh"
UNIT_SRC = ROOT / "deploy/starlearner-fogona-queue.service"
UNIT_DST = Path.home() / ".config/systemd/user/starlearner-fogona-queue.service"

USER_ENV = {
    **os.environ,
    "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
    "DBUS_SESSION_BUS_ADDRESS": os.environ.get(
        "DBUS_SESSION_BUS_ADDRESS",
        f"unix:path=/run/user/{os.getuid()}/bus",
    ),
}


def journal_tail(unit: str, n: int = LINES) -> str:
    try:
        out = subprocess.check_output(
            [
                "journalctl",
                "--user",
                "-u",
                unit,
                "-n",
                str(n),
                "--no-pager",
                "-o",
                "short-iso",
            ],
            stderr=subprocess.STDOUT,
            text=True,
            timeout=8,
            env=USER_ENV,
        )
    except subprocess.CalledProcessError as e:
        out = e.output or str(e)
    except Exception as e:  # noqa: BLE001
        out = f"(journal read failed: {e})"
    return out.rstrip() or "(no log lines yet)"


def migrate_legacy_job() -> None:
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    marker = JOBS_DIR / ".migrated"
    if marker.is_file() or not LEGACY_JOB.is_file():
        return
    try:
        job = json.loads(LEGACY_JOB.read_text(encoding="utf-8"))
    except Exception:
        marker.write_text("ok\n", encoding="utf-8")
        return
    jid = str(job.get("id") or "legacy")
    dest = JOBS_DIR / f"{jid}.json"
    if not dest.exists():
        dest.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
    marker.write_text("ok\n", encoding="utf-8")


def list_jobs() -> list[dict]:
    migrate_legacy_job()
    jobs: list[dict] = []
    for p in sorted(JOBS_DIR.glob("*.json")):
        try:
            jobs.append(json.loads(p.read_text(encoding="utf-8")))
        except Exception as e:  # noqa: BLE001
            jobs.append({"id": p.stem, "status": "error", "message": str(e)})
    return jobs


def status_payload() -> dict:
    jobs = list_jobs()
    pending = [j for j in jobs if j.get("status") in ("pending", "failed", "delivering")]
    return {
        "jobs": jobs,
        "pending_count": len(pending),
        "status": "pending" if pending else ("idle" if not jobs else "done"),
    }


def job_paths() -> list[Path]:
    migrate_legacy_job()
    return sorted(JOBS_DIR.glob("*.json"))


def mark_all_pending() -> None:
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for p in job_paths():
        try:
            job = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if job.get("status") in ("failed", "done", "pending", "delivering") and job.get("apk"):
            job["status"] = "pending"
            job["updated"] = now
            job.setdefault("log", []).append("marked pending via portal (no auto-deliver)")
            job["log"] = job["log"][-40:]
            p.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")


def install_oneshot_unit() -> None:
    UNIT_DST.parent.mkdir(parents=True, exist_ok=True)
    UNIT_DST.write_text(UNIT_SRC.read_text(encoding="utf-8"), encoding="utf-8")
    subprocess.call(["systemctl", "--user", "daemon-reload"], env=USER_ENV, timeout=15)
    subprocess.call(
        ["systemctl", "--user", "disable", "starlearner-fogona-queue.service"],
        env=USER_ENV,
        timeout=15,
    )
    subprocess.call(
        ["systemctl", "--user", "stop", "starlearner-fogona-queue.service"],
        env=USER_ENV,
        timeout=15,
    )


def enqueue_target(target: str, apk: Path) -> dict:
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    if not apk.is_file():
        return {
            "ok": False,
            "error": f"missing {apk} — build on 82 first: "
            f"./tools/queue_fogona_deliver.sh {target} --build",
        }
    try:
        out = subprocess.check_output(
            ["bash", str(QUEUE_SCRIPT), target],
            cwd=str(ROOT),
            stderr=subprocess.STDOUT,
            text=True,
            timeout=120,
            env=USER_ENV,
        )
        return {"ok": True, "output": out, **status_payload()}
    except subprocess.CalledProcessError as e:
        return {"ok": False, "error": e.output or str(e), **status_payload()}


def deliver_now() -> dict:
    """Kick oneshot deliver for all pending jobs. Returns immediately."""
    st = status_payload()
    if st["pending_count"] == 0:
        return {"ok": False, "error": "no pending jobs — queue an APK first", **st}

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for p in job_paths():
        try:
            job = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if job.get("status") in ("pending", "failed", "delivering") and job.get("apk"):
            job["status"] = "pending"
            job["updated"] = now
            job.setdefault("log", []).append("Deliver now pressed on /ops/")
            job["log"] = job["log"][-40:]
            p.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")

    install_oneshot_unit()
    try:
        subprocess.check_call(
            ["systemctl", "--user", "start", "starlearner-fogona-queue.service"],
            stderr=subprocess.STDOUT,
            timeout=30,
            env=USER_ENV,
        )
        return {
            "ok": True,
            "message": "deliver started for all pending jobs — refresh /ops/",
            **status_payload(),
        }
    except subprocess.CalledProcessError as e:
        return {
            "ok": False,
            "error": getattr(e, "output", None) or str(e),
            **status_payload(),
        }
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e), **status_payload()}


SHELL = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="{refresh}" />
  <title>Star Learner — {title}</title>
  <style>
    :root {{ color-scheme: light; }}
    body {{
      margin: 0;
      font-family: ui-monospace, "JetBrains Mono", "SF Mono", Menlo, Consolas, monospace;
      background: #f4efe6; color: #1a1f26;
    }}
    header {{
      position: sticky; top: 0;
      display: flex; gap: 1rem; align-items: baseline; flex-wrap: wrap;
      padding: 0.85rem 1.1rem; background: #1a1f26; color: #f4efe6;
    }}
    header h1 {{ margin: 0; font-size: 1rem; font-weight: 600; letter-spacing: 0.04em; }}
    header a {{ color: #c9b896; text-decoration: none; font-size: 0.85rem; }}
    header .meta {{ margin-left: auto; opacity: 0.7; font-size: 0.8rem; }}
    main {{ padding: 1rem 1.1rem 3rem; }}
    pre {{
      margin: 0; white-space: pre-wrap; word-break: break-word;
      font-size: 0.82rem; line-height: 1.45;
    }}
    .card {{ margin: 0 0 1.25rem; }}
    .row {{ display: flex; gap: 0.75rem; flex-wrap: wrap; align-items: center; margin: 0.75rem 0; }}
    button, .btn {{
      font: inherit; cursor: pointer; border: 1px solid #1a1f26;
      background: #1a1f26; color: #f4efe6; padding: 0.45rem 0.85rem;
      text-decoration: none;
    }}
    button.secondary {{ background: transparent; color: #1a1f26; }}
    button.deliver {{ background: #1b5e20; border-color: #1b5e20; }}
    button:disabled {{ opacity: 0.45; cursor: not-allowed; }}
    .status {{ font-size: 0.9rem; }}
    .ok {{ color: #1b5e20; }}
    .bad {{ color: #8b1a1a; }}
    .idle {{ color: #5c5346; }}
  </style>
</head>
<body>
  <header>
    <h1>Star Learner · {title}</h1>
    <a href="/">home</a>
    <a href="/ops/">ops</a>
    <a href="/logs/">asr</a>
    <span class="meta">{meta}</span>
  </header>
  <main>{body}</main>
</body>
</html>
"""


def ops_page() -> bytes:
    st = status_payload()
    status = str(st.get("status", "idle"))
    klass = {"done": "ok", "pending": "idle", "failed": "bad"}.get(status, "idle")
    garden_ready = GARDEN_APK.is_file()
    language_ready = LANGUAGE_APK.is_file()
    can_deliver = int(st.get("pending_count") or 0) > 0
    deliver_disabled = "" if can_deliver else " disabled"

    lines = []
    for j in st.get("jobs") or []:
        lines.append(
            f"{j.get('status', '?'):10}  {j.get('package', '—')}  "
            f"id={j.get('id', '—')}  attempts={j.get('attempts', 0)}"
        )
        for entry in (j.get("log") or [])[-3:]:
            lines.append(f"           · {entry}")
    jobs_txt = "\n".join(lines) if lines else "(no jobs)"

    body = f"""
<div class="card">
  <div class="status {klass}"><strong>queue:</strong> {html.escape(status)}
    · pending={html.escape(str(st.get('pending_count', 0)))}
    · jobs={html.escape(str(len(st.get('jobs') or [])))}
  </div>
  <div class="row">
    <form method="post" action="/ops/queue/garden">
      <button class="secondary" type="submit">Queue garden</button>
    </form>
    <form method="post" action="/ops/queue/language">
      <button class="secondary" type="submit">Queue language</button>
    </form>
    <form method="post" action="/ops/deliver">
      <button class="deliver" type="submit"{deliver_disabled}>Deliver now → 245 USB</button>
    </form>
    <form method="post" action="/ops/queue/retry">
      <button class="secondary" type="submit">Mark all pending</button>
    </form>
    <a class="btn secondary" href="/ops/status.json">status.json</a>
  </div>
  <p class="status {'ok' if garden_ready else 'bad'}">
    garden APK: {"ready " + html.escape(GARDEN_APK.name) if garden_ready else "missing"}
  </p>
  <p class="status {'ok' if language_ready else 'bad'}">
    language APK: {"ready " + html.escape(LANGUAGE_APK.name) if language_ready else "missing"}
  </p>
  <p class="status idle">
    No polling. Queue stages APKs; <strong>Deliver now</strong> SSHs to Pop <strong>245</strong>
    (<code>:2222</code>) and <code>adb install</code>s on whatever handset is on that USB
    (serial in each job — <strong>cove</strong>=<code>ZL8326G8ND</code>, <strong>reef</strong>=<code>ZL8326FWKM</code>;
    model name on both is Motorola <code>fogona</code>).
  </p>
  <pre>{html.escape(jobs_txt)}</pre>
</div>
<div class="card">
  <strong>last deliver journal</strong>
  <pre>{html.escape(journal_tail(QUEUE_UNIT, 80))}</pre>
</div>
<div class="card">
  <strong>status.json</strong>
  <pre>{html.escape(json.dumps(st, indent=2))}</pre>
</div>
"""
    return SHELL.format(
        title="ops",
        refresh="15",
        meta="auto-refresh 15s · no 245 poll",
        body=body,
    ).encode("utf-8")


def asr_page() -> bytes:
    text = journal_tail(ASR_UNIT)
    body = f"<pre>{html.escape(text)}</pre>"
    return SHELL.format(
        title="ASR",
        refresh="8",
        meta=f"{ASR_UNIT} · last {LINES}",
        body=body,
    ).encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        pass

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, loc: str = "/ops/") -> None:
        self.send_response(303)
        self.send_header("Location", loc)
        self.end_headers()

    def _wants_json(self) -> bool:
        accept = self.headers.get("Accept", "")
        return "application/json" in accept or bool(self.headers.get("X-Requested-With"))

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path in ("/", "/logs"):
            self._send(200, asr_page(), "text/html; charset=utf-8")
            return
        if path == "/logs/raw" or path == "/raw":
            self._send(200, (journal_tail(ASR_UNIT) + "\n").encode(), "text/plain; charset=utf-8")
            return
        if path == "/ops":
            self._send(200, ops_page(), "text/html; charset=utf-8")
            return
        if path == "/ops/status.json" or path == "/ops/status":
            body = (json.dumps(status_payload(), indent=2) + "\n").encode()
            self._send(200, body, "application/json")
            return
        if path == "/health":
            self._send(200, b'{"ok":true}\n', "application/json")
            return
        self.send_error(404)

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)

        if path == "/ops/queue/garden":
            result = enqueue_target("garden", GARDEN_APK)
        elif path == "/ops/queue/language":
            result = enqueue_target("language", LANGUAGE_APK)
        elif path == "/ops/deliver":
            result = deliver_now()
        elif path == "/ops/queue/retry":
            mark_all_pending()
            result = {"ok": True, **status_payload()}
        else:
            self.send_error(404)
            return

        if self._wants_json():
            self._send(
                200 if result.get("ok", True) else 400,
                (json.dumps(result, indent=2) + "\n").encode(),
                "application/json",
            )
            return
        self._redirect()


def main() -> None:
    try:
        install_oneshot_unit()
    except Exception as e:  # noqa: BLE001
        print(f"[starlearner-ops] warn: could not disarm poller: {e}", flush=True)
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[starlearner-ops] http://{HOST}:{PORT}/ (logs + ops, multi-job deliver)", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
