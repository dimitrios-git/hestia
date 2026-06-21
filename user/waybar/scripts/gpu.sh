#!/bin/sh
# Waybar custom/gpu — ONE widget for all GPUs. The bar shows the **busiest** card's
# utilisation (the MAX across cards, not an average — on a discrete+iGPU box, maxing the
# dGPU should read 100%, not 50%); the tooltip lists every card (name · util · temp ·
# VRAM). Prints NOTHING when no GPU is present, so Waybar hides the module. GPUs are
# enumerated in a stable order (DRM card number). Per vendor: NVIDIA via nvidia-smi, AMD
# via amdgpu sysfs, Intel via sysfs (best-effort — no util counter, so name+temp only).

# first hwmon temp (°C, rounded) under a DRM device dir, or empty
drm_temp() {
    for t in "$1"/hwmon/hwmon*/temp1_input; do
        [ -r "$t" ] || continue
        awk '{printf "%d", $1/1000; exit}' "$t"; return
    done
}

# PCI marketing name via lspci (best-effort), else the $2 fallback
drm_name() {
    _pci=$(basename "$(readlink -f "$1")" 2>/dev/null)
    _name=""
    if command -v lspci >/dev/null 2>&1 && [ -n "$_pci" ]; then
        _name=$(lspci -s "${_pci#0000:}" 2>/dev/null | sed 's/.*: //; s/ (rev .*)//' | head -1)
    fi
    [ -n "$_name" ] && printf '%s' "$_name" || printf '%s' "$2"
}

# Enumerate GPUs in stable order. One line each: "devicepath|pci_addr|vendor".
enumerate() {
    for c in /sys/class/drm/card[0-9]*; do
        dev="$c/device"
        [ -r "$dev/vendor" ] || continue
        case "$(cat "$dev/vendor" 2>/dev/null)" in 0x10de|0x1002|0x8086) ;; *) continue ;; esac
        printf '%s|%s|%s\n' "$dev" "$(basename "$(readlink -f "$dev")" 2>/dev/null)" "$(cat "$dev/vendor")"
    done
}

# record_for DEV PCI VENDOR -> "util|temp|vram_used|vram_total|name" (util="n/a" when
# unavailable, e.g. Intel i915; vram fields empty when not exposed).
record_for() {
    _dev=$1; _pci=$2; _ven=$3
    case "$_ven" in
        0x10de)
            command -v nvidia-smi >/dev/null 2>&1 || return 1
            nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total,name \
                --format=csv,noheader,nounits 2>/dev/null | awk -F', *' -v s="${_pci#*:}" '
                BEGIN { gsub(/\./, "\\.", s) }
                { if (tolower($1) ~ s"$") { printf "%s|%s|%s|%s|%s", $2, $3, $4, $5, $6; exit } }'
            ;;
        *)
            _u=$(cat "$_dev/gpu_busy_percent" 2>/dev/null); [ -n "$_u" ] || _u="n/a"
            _t=$(drm_temp "$_dev"); _vu=""; _vt=""
            if [ -r "$_dev/mem_info_vram_used" ] && [ -r "$_dev/mem_info_vram_total" ]; then
                _vu=$(awk '{printf "%d", $1/1048576; exit}' "$_dev/mem_info_vram_used")
                _vt=$(awk '{printf "%d", $1/1048576; exit}' "$_dev/mem_info_vram_total")
            fi
            case "$_ven" in 0x1002) _fb="AMD GPU" ;; 0x8086) _fb="Intel GPU" ;; *) _fb="GPU" ;; esac
            printf '%s|%s|%s|%s|%s' "$_u" "$_t" "$_vu" "$_vt" "$(drm_name "$_dev" "$_fb")"
            ;;
    esac
}

list=$(enumerate)
[ "$(printf '%s' "$list" | grep -c .)" -eq 0 ] && exit 0  # no GPU -> hide

maxutil=0
tip=""
oldifs=$IFS; IFS='
'
for ln in $list; do
    IFS='|'; set -- $ln; IFS='
'
    rec=$(record_for "$1" "$2" "$3") || continue
    IFS='|'; set -- $rec; IFS='
'
    u=$1; t=$2; vu=$3; vt=$4; nm=$5
    [ "$u" != "n/a" ] && [ -n "$u" ] && [ "$u" -gt "$maxutil" ] 2>/dev/null && maxutil=$u
    if [ "$u" = "n/a" ]; then line="$nm"; else line="$nm  ${u}%"; fi
    [ -n "$t" ] && line="$line · ${t}°C"
    [ -n "$vu" ] && [ -n "$vt" ] && line="$line · ${vu}/${vt} MiB"
    tip="$tip$line\\n"
done
IFS=$oldifs
tip=${tip%\\n}  # drop trailing newline

printf '{"text":"%2d%%","tooltip":"%s"}\n' "$maxutil" "$tip"
