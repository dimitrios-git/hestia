#!/bin/sh
# Waybar custom/usb — mounted USB / removable storage. The module is shown only while a
# removable device is attached (hidden otherwise); its text is the count of mounted
# removable filesystems (empty when attached but none mounted, so you know to click to
# mount). The tooltip lists each one (device, size, label, mountpoint).
#
# Click (`menu`) → a wofi picker to mount / unmount a partition via udisksctl (no root —
# polkit lets the active session mount removable media). Needs udisks2 (apt manifest).

if [ "$1" = menu ]; then
    python3 - <<'PY'
import json, subprocess, sys, shutil

def removable(d):
    return bool(d.get("hotplug") or d.get("rm") or d.get("tran") == "usb")

def notify(msg):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "USB storage", msg])

try:
    out = subprocess.run(
        ["lsblk", "-J", "-o", "NAME,PATH,SIZE,TYPE,RM,HOTPLUG,TRAN,FSTYPE,LABEL,MOUNTPOINT"],
        capture_output=True, text=True, timeout=5).stdout
    data = json.loads(out)
except Exception:
    sys.exit(0)

parts = []
def walk(n):
    if n.get("fstype") and n.get("path"):
        parts.append({"path": n["path"], "name": n.get("name", ""), "size": n.get("size") or "",
                      "label": n.get("label") or "", "mp": n.get("mountpoint") or ""})
    for c in n.get("children") or []:
        walk(c)
for disk in data.get("blockdevices", []):
    if disk.get("type") == "disk" and removable(disk):
        walk(disk)

if not parts:
    notify("No removable storage attached."); sys.exit(0)
if not shutil.which("udisksctl"):
    notify("udisksctl not found — install udisks2 to mount/unmount."); sys.exit(0)

entries = []
for d in parts:
    name = d["label"] or d["name"]
    act = f"unmount   ({d['mp']})" if d["mp"] else "mount"
    entries.append((d, f"{name}   {d['size']}   ·   {act}"))

menu = "\n".join(disp for _, disp in entries)
try:
    sel = subprocess.run(["wofi", "--dmenu", "-i", "-p", "USB mount / unmount"],
                         input=menu, capture_output=True, text=True).stdout.strip()
except Exception:
    sys.exit(0)
chosen = next((d for d, disp in entries if disp == sel), None)
if not chosen:
    sys.exit(0)

action = "unmount" if chosen["mp"] else "mount"
r = subprocess.run(["udisksctl", action, "-b", chosen["path"]], capture_output=True, text=True)
notify((r.stdout or r.stderr).strip() or f"{action} {chosen['path']}")
PY
    exit 0
fi

# Bar output: hide when no removable device; else icon (config) + mounted count.
python3 - <<'PY'
import json, subprocess, sys

try:
    out = subprocess.run(
        ["lsblk", "-J", "-o", "NAME,SIZE,TYPE,RM,HOTPLUG,TRAN,FSTYPE,LABEL,MOUNTPOINT"],
        capture_output=True, text=True, timeout=5).stdout
    data = json.loads(out)
except Exception:
    sys.exit(0)

def removable(d):
    return bool(d.get("hotplug") or d.get("rm") or d.get("tran") == "usb")

def collect(n, out):
    if n.get("fstype"):
        out.append((n.get("name", "?"), n.get("size") or "",
                    n.get("label") or n.get("fstype") or n.get("name", ""),
                    n.get("mountpoint") or ""))
    for c in n.get("children") or []:
        collect(c, out)

parts = []
for disk in data.get("blockdevices", []):
    if disk.get("type") == "disk" and removable(disk):
        collect(disk, parts)

if not parts:
    sys.exit(0)  # nothing attached -> hide the module

mounted = [p for p in parts if p[3]]
lines = [f"{n}  {s}  {lbl}  →  {mp if mp else '(not mounted)'}" for n, s, lbl, mp in parts]
text = str(len(mounted)) if mounted else ""
print(json.dumps({"text": text, "tooltip": "\n".join(lines) + "\n(click to mount / unmount)"}))
PY
