#!/bin/sh
# imv-vifm-return.sh [quit] — run by imv (config-vifm) when imv was launched from
# vifm's image-browse key. Kept as a script so imv binds stay trivial
# (`exec …/imv-vifm-return.sh [quit]`): imv splits binds on ';' and parses each
# part as an imv command, and inline shell quoting in a bind gets mangled — a
# bare script path has nothing to misparse. imv exposes its state as env vars to
# exec'd commands; we use $imv_current_file (image shown) and $imv_pid.
#
#   (no arg)  live sync — move vifm's cursor onto the current image (each j/k)
#   quit      also restore vifm's dual-pane preview, then close imv
#
# :goto SELECTS without opening (a plain `--remote <file>` would re-open it).
# vifm --remote no-ops if no vifm server is running.

if [ "$1" = quit ]; then
    vifm --remote -c 'vsplit' -c 'view!' -c "goto '$imv_current_file'"
    # ask imv to quit, then guarantee the window closes (sync already ran)
    imv-msg "$imv_pid" quit 2>/dev/null
    kill "$imv_pid" 2>/dev/null
else
    vifm --remote -c "goto '$imv_current_file'"
fi
