#!/usr/bin/env bash
# Regenerate manifest.json from the staging dir. Runs inside 245's WSL:
#   wsl -e bash /mnt/c/Users/dylan/antphone/server/make_manifest.sh
set -euo pipefail

STAGING=/mnt/c/Users/dylan/antphone/staging
SERVER=/mnt/c/Users/dylan/antphone/server

python3 - "$STAGING" "$SERVER/manifest.json" <<'PY'
import hashlib, json, os, sys, time

staging, out = sys.argv[1], sys.argv[2]

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

apks = []
for name in sorted(os.listdir(staging)):
    if not name.endswith('.apk'):
        continue
    p = os.path.join(staging, name)
    apks.append({
        'file': name,
        'package': name[:-4],
        'sha256': sha256(p),
        'size': os.path.getsize(p),
    })

cat = os.path.join(staging, 'catalog.json')
manifest = {
    'version': int(time.time()),
    'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    'catalog': {
        'file': 'catalog.json',
        'sha256': sha256(cat),
        'size': os.path.getsize(cat),
    },
    'apks': apks,
}
with open(out, 'w') as f:
    json.dump(manifest, f, indent=2)
print(f"manifest v{manifest['version']}: {len(apks)} apk(s)")
PY
