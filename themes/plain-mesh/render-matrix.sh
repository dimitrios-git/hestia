#!/bin/bash
# Render + encode the full plain-mesh matrix (resolutions x variants).
# Usage: ./render-matrix.sh <outdir>   (frames go to a temp dir, deleted per step)
set -eu

OUT=${1:?usage: ./render-matrix.sh <outdir>}
RES="1920x1080 1920x1200 2560x1440 2560x1600 3840x2160 1200x1920"
FPS=24
LOOP=120   # keep in sync with mesh.html's frequency snapping (LOOP_T)
CRF=14     # quality over size (thin lines: banding is the enemy)

cd "$(dirname "$0")"
[ -d node_modules ] || { echo "run: npm install (see README.md)" >&2; exit 1; }
mkdir -p "$OUT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for res in $RES; do
  w=${res%x*}; h=${res#*x}
  for v in dark light; do
    if [ "$v" = dark ]; then bg='#1a1a1a'; line='#cfc8ba'; else bg='#f5f5f5'; line='#3a352c'; fi
    echo "=== plain-mesh $v $res ==="
    rm -rf "$TMP/frames"
    node render.js "$TMP/frames" "$bg" "$line" "$w" "$h" "$FPS" "$LOOP" 0 | tail -1
    ffmpeg -y -framerate "$FPS" -i "$TMP/frames/f%05d.png" -c:v libx264 -crf "$CRF" \
      -preset slow -pix_fmt yuv420p -movflags +faststart \
      "$OUT/plain-mesh-$v-$res.mp4" 2>&1 | tail -1
    cp "$TMP/frames/f00000.png" "$OUT/plain-mesh-$v-$res.png"
  done
done
(cd "$OUT" && sha256sum plain-mesh-*) | sort -k2
