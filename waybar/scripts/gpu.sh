#!/bin/sh
# Waybar custom/gpu — NVIDIA GPU usage. Emits JSON: utilisation % in the bar,
# card name / temperature / VRAM in the hover tooltip.
#
# NVIDIA-only (uses nvidia-smi). On a machine without it the script prints
# nothing, so Waybar hides the module (icon included) — the config stays
# portable across hosts. The guard below also skips the pointless per-interval
# nvidia-smi spawn when the tool is absent.
command -v nvidia-smi >/dev/null 2>&1 || exit 0
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name \
    --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', *' '
    { printf "{\"text\":\"%s%%\",\"tooltip\":\"%s\\n%s%% · %s°C · %s / %s MiB\"}\n", \
             $1, $5, $1, $2, $3, $4 }'
