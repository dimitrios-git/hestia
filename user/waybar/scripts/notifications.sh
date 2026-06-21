#!/bin/sh
# Notification-history viewer for the waybar custom/notifications bell. `show` reads
# mako's history (`makoctl history`) and opens a readable list in a pager (the on-click
# runs it in a floatterm). Robust to mako's output: JSON is formatted nicely; anything
# else is shown as-is; an empty history / unreachable daemon gets a clear message
# rather than a parse error.

if [ "$1" = show ]; then
    python3 - <<'PY' | less -R
import json, subprocess, sys, datetime

try:
    p = subprocess.run(["makoctl", "history"], capture_output=True, text=True, timeout=5)
except Exception as e:
    print("Failed to run makoctl:", e); sys.exit()

raw = (p.stdout or "").strip()
if not raw:
    err = (p.stderr or "").strip()
    if p.returncode != 0 and err:
        print("Could not reach mako:", err)
    else:
        print("No notifications in history yet.")
        print("(mako keeps dismissed/expired notifications — wait for one to time out, "
              "or dismiss it, then check again.)")
    sys.exit()

# Prefer JSON ({"data": [[ {notif}, … ]]}); fall back to showing raw output verbatim.
items = None
try:
    d = json.loads(raw)
    items = d.get("data") if isinstance(d, dict) else d
    while isinstance(items, list) and len(items) == 1 and isinstance(items[0], list):
        items = items[0]
except Exception:
    print(raw); sys.exit()

if not items:
    print("No notifications in history yet."); sys.exit()

def field(n, k):
    v = n.get(k) if isinstance(n, dict) else None
    return v.get("data") if isinstance(v, dict) else (v if v is not None else "")

print(f"Notification history — {len(items)} item(s)\n" + "─" * 48)
for n in items:
    app = field(n, "app-name") or "?"
    summ, body, ts = field(n, "summary"), field(n, "body"), field(n, "time")
    when = ""
    try:
        if ts:
            when = datetime.datetime.fromtimestamp(int(float(ts))).strftime("%a %H:%M")
    except Exception:
        pass
    print(f"● {app}" + (f"  ({when})" if when else ""))
    if summ:
        print(f"  {summ}")
    if body:
        for line in str(body).splitlines():
            print(f"    {line}")
    print()
PY
    exit 0
fi

# (No bar output — the waybar module is a static bell; this script only serves `show`.)
exit 0
