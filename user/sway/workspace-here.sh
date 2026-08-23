#!/bin/sh
# Switches to (or, with a second "move" argument, moves the focused
# container to) workspace <digit> OF THE OUTPUT THAT'S CURRENTLY FOCUSED --
# each output gets its own reserved block of ten globally-unique workspace
# numbers (see the `workspace N:M output ...` assignments in
# user/sway/config), computed here from the focused output's left-to-right
# position rather than hardcoded, so plugging in or removing a monitor
# doesn't need an edit here -- only the assignment block in sway config
# needs to grow/shrink to match the number of physical outputs.
#
# The block/digit split is a sway `num:name` workspace name: `num` (the
# block-relative global number, e.g. 21 for output 2's workspace "1") is
# what sway uses to tell workspaces apart; `name` (just the digit) is what
# waybar's sway/workspaces module shows -- its `{name}` format strips the
# leading "num:" automatically, so every output's bar reads a clean 1-10
# regardless of which block it's actually using underneath.
#
# Usage: workspace-here.sh <digit 1-9, or 0 for the 10th> [move]

digit=${1:?usage: workspace-here.sh <digit> [move]}
offset=$digit
name=$digit
if [ "$digit" = 0 ]; then offset=10; name=10; fi

base=$(swaymsg -t get_outputs | python3 -c '
import json, sys
outs = json.load(sys.stdin)
active = sorted((o for o in outs if o.get("active")), key=lambda o: o["rect"]["x"])
idx = next((i for i, o in enumerate(active) if o.get("focused")), 0)
print((idx + 1) * 10)
')

target="$((base + offset)):$name"

if [ "${2:-}" = move ]; then
    swaymsg move container to workspace number "$target"
else
    swaymsg workspace number "$target"
fi
