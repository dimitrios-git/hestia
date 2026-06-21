#!/bin/sh
# Waybar custom/cpu — overall usage% in the bar; CPU temperature(s) + per-core usage
# in the hover tooltip. Usage is a /proc/stat delta against the previous sample cached
# in tmpfs (no sleep; first tick reads 0%). Temps come from the k10temp / coretemp /
# zenpower hwmon via sysfs (no lm-sensors). Self-contained, like gpu.sh.

state="${XDG_RUNTIME_DIR:-/tmp}/waybar-cpu.prev"
cur=$(grep '^cpu' /proc/stat)
prev=""
[ -r "$state" ] && prev=$(cat "$state")
printf '%s\n' "$cur" > "$state"

# Usage from the delta. set -- splits the awk output: $1 = overall, rest = per-core.
usage=0
cores=""
if [ -n "$prev" ]; then
    set -- $(printf 'P\n%s\nC\n%s\n' "$prev" "$cur" | awk '
        $1=="P" {s=1; next}
        $1=="C" {s=2; next}
        {
            l=$1; idle=$5+$6; tot=0; for (i=2; i<=NF; i++) tot+=$i
            if (s==1) { pi[l]=idle; pt[l]=tot }
            else      { ci[l]=idle; ct[l]=tot; if (l!="cpu") ord[++n]=l }
        }
        function pct(l,   dt,di) { dt=ct[l]-pt[l]; di=ci[l]-pi[l]; return (dt>0) ? int((dt-di)*100/dt + 0.5) : 0 }
        END {
            printf "%d", pct("cpu")
            for (k=1; k<=n; k++) printf " %d", pct(ord[k])
        }')
    usage=$1; shift
    cores="$*"
fi

# CPU temperatures from the first matching hwmon (labelled: Tctl/Tccd on AMD, Core N on
# Intel; falls back to the raw tempN name).
temps=""
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in k10temp|coretemp|zenpower|k8temp) ;; *) continue ;; esac
    for inp in "$h"/temp*_input; do
        [ -r "$inp" ] || continue
        base=${inp%_input}
        lbl=$(cat "${base}_label" 2>/dev/null); [ -n "$lbl" ] || lbl=$(basename "$base")
        t=$(awk '{printf "%d", $1/1000; exit}' "$inp")
        temps="$temps${temps:+ · }$lbl ${t}°C"
    done
    [ -n "$temps" ] && break
done

tip="${temps:-CPU}"
if [ -n "$cores" ]; then
    # Lay the per-core %s out in a monospace grid (8 per row, right-aligned) so the
    # tooltip doesn't become one long line that wraps.
    row=""; grid=""; i=0
    for c in $cores; do
        row="$row$(printf '%4d' "$c")"
        i=$((i + 1))
        if [ $((i % 8)) -eq 0 ]; then
            [ -n "$grid" ] && grid="$grid\\n"
            grid="$grid$row"; row=""
        fi
    done
    if [ -n "$row" ]; then [ -n "$grid" ] && grid="$grid\\n"; grid="$grid$row"; fi
    tip="$tip\\nper-core %:\\n<tt>$grid</tt>"
fi
printf '{"text":"%2d%%","tooltip":"%s"}\n' "$usage" "$tip"
