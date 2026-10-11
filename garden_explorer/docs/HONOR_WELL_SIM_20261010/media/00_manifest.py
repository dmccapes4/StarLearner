#!/usr/bin/env python
"""Manifest of shows → YouTube playlists (free source). Pilot n=3 networks, primetime hour.

MSNBC rebranded to MS NOW (channel @MSNOW) in late 2025; its 9 pm hour is Maddow (Mon) + The Briefing with Jen Psaki (Tue–Fri).
CNN's 9 pm (The Source) has no public playlist on @CNN at probe time; Anderson Cooper 360 (8 pm) is used and the hour difference is recorded.
Fox 9 pm = Hannity.  Playlist IDs probed 2026-10-11 with yt-dlp --flat-playlist on each channel's /playlists tab.
"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = {
  "version": "2026-10-11.pilot",
  "shows": [
    {"show": "msnow_9pm", "network": "MS NOW", "camp": "legacy-left", "hour_et": 21,
     "playlists": [
       {"name": "The Rachel Maddow Show | MS NOW", "id": "PLDIVi-vBsOEyZACNm9wS4MVg1W3Hyid8k"},
       {"name": "The Briefing with Jen Psaki | MS NOW", "id": "PLDIVi-vBsOEw14eWhE7KD3ZlVx7MSvyAY"}],
     "full_broadcast_audio": [{"name": "The Rachel Maddow Show | Full Broadcast | Audio Only", "id": "PLDIVi-vBsOEwiJx3QL3gc3NYCxgiOUeHF"}]},
    {"show": "cnn_8pm", "network": "CNN", "camp": "legacy-centre", "hour_et": 20,
     "playlists": [{"name": "Anderson Cooper 360", "id": "PLJyw9Dspk8rE"}],
     "note": "9 pm (The Source) playlist not found on @CNN; AC360 used, one hour earlier"},
    {"show": "fox_9pm", "network": "FOX", "camp": "legacy-right", "hour_et": 21,
     "playlists": [{"name": "Hannity", "id": "PLlTLHnxSVuIwl-ueK75LQkMhe2DuCGdtK"}]}
  ],
  "later": [
    {"show": "shapiro", "camp": "daily-wire", "source": "YouTube @BenShapiro full episodes"},
    {"show": "walsh", "camp": "daily-wire", "source": "YouTube @MattWalsh full episodes"},
    {"show": "candace", "camp": "independent", "source": "YouTube @RealCandaceO full episodes; Fort Huachuca ep ewBzjVe3LNQ"},
    {"show": "msnow_other", "playlists": {"last_word": "PLDIVi-vBsOEyZy0adHN2CFRpuTcI43Tdq", "all_in": "PLDIVi-vBsOExbSqEOcs8y89xhOYLatXhW", "beat": "PLDIVi-vBsOEye8g1M29oPnQuv-6n-Yq_n"}},
    {"show": "fox_other", "playlists": {"watters": "PLlTLHnxSVuIzGYF38sMTx76lJknuJw5lg", "gutfeld": "PLlTLHnxSVuIyNvsEvhJudvcCNiuYDvE1n", "ingraham": "PLlTLHnxSVuIwmOvGQydmAe8UcdfTvMvQr"}}
  ],
  "segment_seconds": 45,
  "audience_proxy": "sum of YouTube view_count over the night's clips (free proxy; Nielsen hour where published later)"
}
if __name__ == "__main__":
    out = os.path.join(HERE, "manifest.json")
    json.dump(MANIFEST, open(out, "w"), indent=1)
    print("wrote", out, "shows:", [s["show"] for s in MANIFEST["shows"]])
