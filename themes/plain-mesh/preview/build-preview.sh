#!/bin/bash
# Build the single-file live tuning page (self-contained: three.js inlined, so
# file:// works with no server). Output: <outdir>/flash-mesh.html — open it in
# a browser, tune, "show / copy parameters", paste the JSON to bake.
set -eu
OUT=${1:-/srv/devshare/mesh-preview}
cd "$(dirname "$0")"
[ -d ../node_modules ] || { echo "run: npm install (in themes/plain-mesh)" >&2; exit 1; }
mkdir -p "$OUT"
npx esbuild preview-entry.js --bundle --minify --format=iife --outfile="$OUT/.bundle.js"
python3 - "$OUT" <<'PY'
import sys
out = sys.argv[1]
bundle = open(f'{out}/.bundle.js').read()
html = f'''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>flash-mesh preview</title>
<style>
html,body {{ margin:0; padding:0; overflow:hidden; background:#1a1a1a; }}
canvas {{ display:block; }}
#panel {{
  position:fixed; top:16px; right:16px; z-index:10;
  background:rgba(26,26,26,.92); color:#e0e0e0;
  font:13px monospace; padding:14px 16px; border:2px solid #7c3aed;
  display:flex; flex-direction:column; gap:8px; min-width:260px;
}}
#panel .row {{ display:flex; align-items:center; gap:8px; }}
#panel .row span {{ flex:0 0 96px; }}
#panel .row em {{ flex:0 0 36px; font-style:normal; color:#8c8c8c; text-align:right; }}
#panel input[type=range] {{ flex:1; accent-color:#7c3aed; }}
#panel select {{ background:#111; color:#e0e0e0; border:1px solid #3a3a3a; }}
#clock {{ color:#8c8c8c; }}
#params {{
  background:#7c3aed; color:#fff; border:none; padding:7px 10px;
  font:bold 13px monospace; cursor:pointer;
}}
</style>
</head>
<body>
<div id="panel">
  <div id="clock">t = 0.0s</div>
  <button id="params">show / copy parameters</button>
</div>
<script>{bundle}</script>
</body>
</html>'''
open(f'{out}/flash-mesh.html', 'w').write(html)
PY
rm -f "$OUT/.bundle.js"
echo "built: $OUT/flash-mesh.html"
