#!/bin/sh
# Waybar custom/usb — mounted USB / removable storage. The bar shows how many removable
# filesystems are mounted; the tooltip lists each one (device, size, label, mountpoint).
# Prints NOTHING when no removable device is attached, so Waybar hides the module
# (self-hiding, portable). `show` opens a live lsblk view in a floatterm (the on-click).
#
# Detection is via lsblk: a whole disk counts as removable if it's hotplug / rm / USB.
# Display-only — mount/unmount would need udisks2 (not installed); see the on-click view.

if [ "$1" = show ]; then
    exec watch -n 2 -t lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,TRAN,HOTPLUG,RM
fi

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

def collect(node, out):
    if node.get("fstype"):  # a filesystem (partition / whole-disk fs / crypt / lvm)
        out.append((node.get("name", "?"), node.get("size") or "",
                    node.get("label") or node.get("fstype") or node.get("name", ""),
                    node.get("mountpoint") or ""))
    for c in node.get("children") or []:
        collect(c, out)

parts = []
for disk in data.get("blockdevices", []):
    if disk.get("type") == "disk" and removable(disk):
        collect(disk, parts)

if not parts:
    sys.exit(0)  # nothing removable -> hide the module

mounted = [p for p in parts if p[3]]
lines = [f"{n}  {s}  {lbl}  →  {mp if mp else '(not mounted)'}" for n, s, lbl, mp in parts]
print(json.dumps({"text": str(len(mounted)), "tooltip": "\n".join(lines)}))
PY
