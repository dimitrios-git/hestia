#!/usr/bin/env bash
# hestia — one-shot bootstrap. Reach for this right after cloning:
#
#   git clone git@github.com:dimitrios-git/hestia.git ~/Development/hestia
#   cd ~/Development/hestia/bootstrap && ./setup.sh
#
# It (1) installs Ansible if missing, (2) asks a few questions — auto-detecting
# sensible defaults — and writes your answers to the untracked host_vars file,
# then (3) runs the playbook. Re-runnable: it pre-fills from your last answers.
# Flags: --no-backup (don't back up replaced configs), --yes (reuse saved answers,
# skip the questionnaire — resume a failed run), -h/--help. Any other args pass
# through to ansible-playbook; `--check` makes it a true DRY-RUN (simulate, change
# nothing). It authenticates sudo up front (with retries) rather than ansible's
# single-shot become prompt. Run `./setup.sh --help` for details.
#
# This is the configurable-installer front-end (docs/repo-structure-design.md §6).
# Interactive / external follow-ups stay manual — your SSH/GPG identity, the Samba
# password, the claude bot identity, pinentry + dark mode, the credential keyring:
# see ../docs/install-runbook.md.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)      # bootstrap/
HOSTVARS="$HERE/host_vars/localhost.yml"        # gitignored; this host's answers

# --- args: separate setup.sh's own flags from ansible-playbook passthrough ----
usage() {
    cat <<'EOF'
hestia setup.sh — one-shot bootstrap: install Ansible, gather this host's answers,
run the playbook. Re-runnable (it pre-fills from your last answers).

Usage:  ./setup.sh [options] [ansible-playbook args...]

Options:
  --no-backup   Do NOT back up existing config files before replacing them.
                Default: each replaced file is first copied in place to <file>.bak.
  -y, --yes     Skip the questionnaire and reuse the saved answers in host_vars
                as-is — handy to resume after a failed run. (Errors if you have
                not run setup.sh on this machine yet — there are no saved answers.)
  -h, --help    Show this help and exit.

Any other arguments pass through to ansible-playbook, e.g.:
  ./setup.sh --check --diff     Dry-run: simulate everything, change nothing.
  ./setup.sh --tags dotfiles    Run only the dotfiles role.

setup.sh prompts for the sudo password up front with its own retry loop (3 tries),
then hands it to ansible via --become-password-file (a 0600 tmpfs file in
$XDG_RUNTIME_DIR or /dev/shm, removed right after the run). So one mistyped password
just re-prompts instead of aborting the playbook the way ansible's single-shot
--ask-become-pass does. NOPASSWD sudo skips the prompt.

On the FIRST run on a machine, setup.sh warns that it replaces existing dotfiles.
Interactive/external follow-ups (SSH/GPG identity, Samba password, …) stay manual —
see ../docs/install-runbook.md.
EOF
}

no_backup=false
reuse=false                              # --yes: skip Q&A, reuse saved host_vars
pass=()                                  # args forwarded to ansible-playbook
for _a in "$@"; do
    case "$_a" in
        -h|--help)        usage; exit 0 ;;
        --no-backup)      no_backup=true ;;
        -y|--yes|--reuse) reuse=true ;;
        *)                pass+=("$_a") ;;
    esac
done

# `--check` (forwarded to ansible) makes this a true DRY-RUN: answers go to a temp
# file, the real host_vars is untouched, ansible only previews. ./setup.sh --check --diff
dry_run=false
for _a in "${pass[@]}"; do [ "$_a" = --check ] && dry_run=true; done

# No answers file yet = first run on this machine = the destructive case.
first_run=false
[ -f "$HOSTVARS" ] || first_run=true

# --yes reuses saved answers — meaningless on a first run (there are none yet).
if $reuse && $first_run; then
    echo "Error: --yes/-y reuses the saved answers in $HOSTVARS, but none exist yet." >&2
    echo "       Run ./setup.sh once (answer the questions) before using --yes." >&2
    exit 1
fi

# --- helpers ------------------------------------------------------------------
# cur KEY -> the current value of a flat `key: value` (or `key: "value"`) line.
# Always returns 0 (empty if the file/key is absent) so `set -e` doesn't abort the
# first run on a fresh machine where host_vars doesn't exist yet.
cur() {
    [ -f "$HOSTVARS" ] || return 0
    sed -n "s/^$1: *\"\\?\\([^\"]*\\)\"\\?\$/\\1/p" "$HOSTVARS" | head -1
}

# ask VAR "Prompt" "default"  -> sets global $VAR (Enter accepts the default)
ask() {
    local __var=$1 prompt=$2 def=$3 ans
    read -r -p "$prompt [$def]: " ans
    printf -v "$__var" '%s' "${ans:-$def}"
}

# askyn VAR "Prompt" true|false  -> sets $VAR to the string true|false
askyn() {
    local __var=$1 prompt=$2 def=$3 hint ans
    [ "$def" = true ] && hint="Y/n" || hint="y/N"
    read -r -p "$prompt ($hint): " ans
    ans=${ans:-$def}
    case "$ans" in [yY]*|true) printf -v "$__var" true ;; *) printf -v "$__var" false ;; esac
}

# write_answers FILE -> write the gathered answers as YAML to FILE
write_answers() {
    cat > "$1" <<EOF
---
# Generated by setup.sh — this host's answers. Gitignored; re-run setup.sh to update.
enable_samba: $enable_samba
enable_tailscale: $enable_tailscale
enable_claude_user: $enable_claude_user
claude_sign_commits: $claude_sign_commits
enable_credentials: $enable_credentials
enable_libreoffice: $enable_libreoffice
enable_kdenlive: $enable_kdenlive
enable_thunderbird: $enable_thunderbird
enable_file_managers: $enable_file_managers
enable_image_viewers: $enable_image_viewers
enable_wallpapers: $enable_wallpapers
enable_firefox: $enable_firefox
enable_firefoxpwa: $enable_firefoxpwa
enable_trading: $enable_trading
enable_yaru_icons: $enable_yaru_icons
enable_nvidia: $enable_nvidia
enable_razer: $enable_razer
samba_lan_subnet: "$samba_lan_subnet"
cmus_music_dir: "$cmus_music_dir"
theme_variant: "$theme_variant"
git_user_name: "$git_user_name"
git_user_email: "$git_user_email"
git_signingkey: "$git_signingkey"
gpg_keygrip: "$gpg_keygrip"
ssh_key_file: "$ssh_key_file"
EOF
}

# get_become_pw -> capture + validate the sudo password ourselves (with retries),
# stored in BECOME_PW for run_playbook to hand to ansible.
#
# Why we capture it instead of relying on a cached `sudo -v` timestamp: ansible's
# become runs sudo on a DIFFERENT tty than this shell, and sudo's tty_tickets (the
# Debian default) keys the timestamp to the tty — so the cached credential doesn't
# apply and ansible still fails with "sudo: a password is required". We must give
# ansible the password. Why not ansible's --ask-become-pass: it's SINGLE-SHOT (one
# typo aborts the whole play). Capturing it here lets us retry like sudo does (3
# tries), validating each attempt with `sudo -S -v` so ansible only gets a good one.
BECOME_PW=""
get_become_pw() {
    # Truly passwordless (NOPASSWD)? Then ansible needs no become password. `sudo -k`
    # first drops any cached timestamp, so a warm cache can't masquerade as NOPASSWD
    # (that false positive left ansible with no password -> "a password is required").
    sudo -k 2>/dev/null || true
    if sudo -n true 2>/dev/null; then BECOME_PW=""; return 0; fi
    echo "==> Authenticating sudo (needed for package installs / system roles)…"
    local pw tries=0
    while :; do
        read -rsp "  [sudo] password for $USER: " pw; echo
        if printf '%s\n' "$pw" | sudo -S -v 2>/dev/null; then BECOME_PW=$pw; return 0; fi
        tries=$((tries + 1))
        [ "$tries" -ge 3 ] && { echo "Aborted — sudo authentication failed. Nothing written or changed." >&2; exit 1; }
        echo "  Sorry, try again."
    done
}

# run_playbook ARGS… -> run the playbook, handing ansible the captured become
# password via `--become-password-file <file>`.
#
# The file lives in tmpfs ($XDG_RUNTIME_DIR or /dev/shm — RAM-backed, so the password
# never touches a physical disk), is mode 0600, and is removed immediately after the
# run (plus a belt-and-braces EXIT trap). NOT process substitution `<(…)`: ansible
# re-opens the path BY NAME, and /dev/fd/N resolves to an unopenable "pipe:[inode]"
# pseudo-path ("password file … was not found"). A real tmpfs file is what works.
_become_pwfile=""
trap '[ -n "$_become_pwfile" ] && rm -f "$_become_pwfile"' EXIT
run_playbook() {
    if [ -z "$BECOME_PW" ]; then
        ansible-playbook "$HERE/site.yml" "$@"
        return
    fi
    _become_pwfile=$(mktemp "${XDG_RUNTIME_DIR:-/dev/shm}/hestia-become.XXXXXX" 2>/dev/null || mktemp)
    chmod 600 "$_become_pwfile"
    printf '%s\n' "$BECOME_PW" > "$_become_pwfile"
    ansible-playbook "$HERE/site.yml" "$@" --become-password-file "$_become_pwfile"
    rm -f "$_become_pwfile"; _become_pwfile=""
}

# finish_notice -> closing message, tailored to dry-run vs a real apply.
finish_notice() {
    if $dry_run; then
        echo "==> Dry-run complete — nothing was changed. Re-run without --check to apply."
    else
        cat <<'EOF'

==> Done. Remaining manual / external steps (see ../docs/install-runbook.md):
    pinentry + dark mode; your SSH/GPG identity; the Samba password (smbpasswd);
    the claude bot identity; and storing the credential-keyring passphrases.
EOF
    fi
}

# --- 1. Ansible ---------------------------------------------------------------
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "==> Installing Ansible (needs sudo)…"
    sudo apt-get update && sudo apt-get install -y ansible
fi

# --- reuse fast-path (--yes): skip the questionnaire, run the saved host_vars ---
# Ansible auto-loads host_vars/localhost.yml, so we just run the playbook as-is.
# Honours --no-backup and any passthrough args (e.g. --check, --tags).
if $reuse; then
    echo "==> Reusing $HOSTVARS as-is (--yes: questionnaire skipped)."
    extra=()
    if $no_backup; then extra+=(-e dotfiles_backup=false); fi
    get_become_pw
    run_playbook "${extra[@]}" "${pass[@]}"
    finish_notice
    exit 0
fi

# --- 2. Gather answers (existing value -> detected -> hardcoded fallback) ------
echo "==> Configure this host (press Enter to accept each [default]):"

# LAN subnet: the link-scope route on the DEFAULT-route interface — so we pick the
# real NIC, not docker0/bridges/veth/tailscale (whose routes often sort first).
# Fall back to the first non-virtual link route, then a generic default.
det_if=$(ip -o -4 route show default 2>/dev/null | awk '{print $5; exit}')
det_lan=$(ip -o -4 route show scope link 2>/dev/null \
            | awk -v ifc="$det_if" '$1 ~ /\// && index($0, " dev " ifc " ") {print $1; exit}')
[ -n "$det_lan" ] || det_lan=$(ip -o -4 route show scope link 2>/dev/null \
            | awk '$1 ~ /\// && $0 !~ /docker|veth|br-|virbr|tailscale|169\.254/ {print $1; exit}')
def_lan=$(cur samba_lan_subnet);     def_lan=${def_lan:-${det_lan:-192.168.1.0/24}}
def_music=$(cur cmus_music_dir);     def_music=${def_music:-$HOME/Music}
def_samba=$(cur enable_samba);       def_samba=${def_samba:-true}
def_tailscale=$(cur enable_tailscale); def_tailscale=${def_tailscale:-true}
def_claude=$(cur enable_claude_user); def_claude=${def_claude:-true}
def_claudesign=$(cur claude_sign_commits); def_claudesign=${def_claudesign:-true}
def_creds=$(cur enable_credentials);  def_creds=${def_creds:-true}
def_office=$(cur enable_libreoffice); def_office=${def_office:-false}
def_kdenlive=$(cur enable_kdenlive); def_kdenlive=${def_kdenlive:-false}
def_thunderbird=$(cur enable_thunderbird); def_thunderbird=${def_thunderbird:-false}
def_filemgrs=$(cur enable_file_managers); def_filemgrs=${def_filemgrs:-false}
def_imgviewers=$(cur enable_image_viewers); def_imgviewers=${def_imgviewers:-false}
def_wallpapers=$(cur enable_wallpapers); def_wallpapers=${def_wallpapers:-true}
def_firefox=$(cur enable_firefox); def_firefox=${def_firefox:-true}
def_ffpwa=$(cur enable_firefoxpwa); def_ffpwa=${def_ffpwa:-true}
def_trading=$(cur enable_trading); def_trading=${def_trading:-false}
def_yaruicons=$(cur enable_yaru_icons); def_yaruicons=${def_yaruicons:-false}
# NVIDIA: detect a card via lspci (pciutils), else the PCI vendor id 0x10de in sysfs.
det_nvidia=false
if lspci 2>/dev/null | grep -qi 'nvidia'; then det_nvidia=true
elif grep -qi 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null; then det_nvidia=true; fi
def_nvidia=$(cur enable_nvidia); def_nvidia=${def_nvidia:-$det_nvidia}
# Razer: detect gear via the USB vendor id 1532 in sysfs (usbutils may be absent).
det_razer=false
if grep -qi '^1532$' /sys/bus/usb/devices/*/idVendor 2>/dev/null; then det_razer=true; fi
def_razer=$(cur enable_razer); def_razer=${def_razer:-$det_razer}
def_theme=$(cur theme_variant); def_theme=${def_theme:-dark}

# Identity defaults: existing host_vars -> existing git config -> gpg/ssh detect.
def_gname=$(cur git_user_name);   [ -n "$def_gname" ]  || def_gname=$(git config --global user.name 2>/dev/null || true)
[ -n "$def_gname" ]  || def_gname=$(getent passwd "$USER" 2>/dev/null | cut -d: -f5 | cut -d, -f1 || true)
def_gmail=$(cur git_user_email);  [ -n "$def_gmail" ]  || def_gmail=$(git config --global user.email 2>/dev/null || true)
def_skey=$(cur git_signingkey);   [ -n "$def_skey" ]   || def_skey=$(git config --global user.signingkey 2>/dev/null || true)
[ -n "$def_skey" ] || def_skey=$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk -F/ '/^sec/{split($2,a," ");print a[1];exit}' || true)
def_grip=$(cur gpg_keygrip)
[ -n "$def_grip" ] || [ -z "$def_skey" ] || def_grip=$(gpg --list-secret-keys --with-keygrip "$def_skey" 2>/dev/null | awk '/Keygrip/{print $3;exit}' || true)
def_sshkey=$(cur ssh_key_file)
if [ -z "$def_sshkey" ]; then
    for _k in "$HOME"/.ssh/id_*; do
        case "$_k" in *.pub) continue ;; esac
        [ -f "$_k" ] && { def_sshkey=$(basename "$_k"); break; }
    done
fi
[ -n "$def_sshkey" ] || def_sshkey=id_ed25519

askyn enable_samba       "Set up the Samba share?"                  "$def_samba"
if [ "$enable_samba" = true ]; then
    ask samba_lan_subnet "  Home LAN subnet allowed to reach it"    "$def_lan"
else
    samba_lan_subnet=$def_lan
fi
askyn enable_tailscale   "Install Tailscale? (mesh VPN; the share's remote reach)" "$def_tailscale"
askyn enable_claude_user "Create the dedicated 'claude' agent user?" "$def_claude"
if [ "$enable_claude_user" = true ]; then
    askyn claude_sign_commits "  Generate a passwordless GPG key so claude signs its commits?" "$def_claudesign"
else
    claude_sign_commits=$def_claudesign
fi
askyn enable_credentials "Enable login auto-unlock of SSH + GPG?"    "$def_creds"
askyn enable_libreoffice "Install LibreOffice? (heavy — vifm opens office docs)" "$def_office"
askyn enable_kdenlive    "Install Kdenlive? (heavy — Qt6/KF6 video editor)" "$def_kdenlive"
askyn enable_thunderbird "Install Thunderbird? (email client, hestia-themed)" "$def_thunderbird"
askyn enable_file_managers "Install the file-manager evaluation set? (ranger/yazi/krusader/dolphin/thunar/nemo/nautilus)" "$def_filemgrs"
askyn enable_image_viewers "Install ristretto? (GUI image viewer, alongside imv)" "$def_imgviewers"
askyn enable_wallpapers  "Install the wallpaper stack? (plain-mesh default background + wpaperd/awww/mpvpaper — prebuilt, amd64)" "$def_wallpapers"
askyn enable_firefox     "Install Firefox ESR? (the desktop browser)" "$def_firefox"
askyn enable_firefoxpwa  "Install firefoxpwa? (PWA support — vendor apt repo)" "$def_ffpwa"
askyn enable_trading     "Install trading apps? (TradingView Desktop — vendor .deb)" "$def_trading"
askyn enable_yaru_icons  "Theme app & folder icons to match hestia? (downloads a prebuilt icon theme)" "$def_yaruicons"
askyn enable_nvidia      "Install the NVIDIA proprietary driver? (non-free; needs reboot)" "$def_nvidia"
askyn enable_razer       "Install Razer peripheral support? (openrazer + polychromatic; needs reboot)" "$def_razer"
ask   cmus_music_dir     "Music library directory (cmus)"           "$def_music"
# Not a boolean — validate the two allowed values (a typo would break the manifest's
# variant-picked symlink sources).
while :; do
    ask theme_variant    "Desktop theme variant (dark|light)"       "$def_theme"
    case "$theme_variant" in dark|light) break ;; *) echo "  Please answer 'dark' or 'light'." ;; esac
done

echo
echo "  Identity (commit author, signing, and the login key-unlock hook):"
ask git_user_name  "  Git user name" "${def_gname:-Your Name}"
ask git_user_email "  Git email"     "${def_gmail:-you@example.com}"
ask git_signingkey "  GPG signing key id (blank = no commit signing)" "$def_skey"
if [ -n "$git_signingkey" ]; then
    ask gpg_keygrip "  GPG keygrip of that key (gpg --with-keygrip)" "$def_grip"
else
    gpg_keygrip=""
fi
ask ssh_key_file   "  SSH private key in ~/.ssh the login hook loads" "$def_sshkey"

# --- 3. Confirm before writing/applying (catch a bad auto-detect here) ---------
$dry_run && _verb="preview (DRY-RUN — nothing written or changed)" || _verb="write + apply"
cat <<EOF

  Answers to $_verb:
    enable_samba       = $enable_samba$( [ "$enable_samba" = true ] && echo "   (LAN: $samba_lan_subnet)" )
    enable_tailscale   = $enable_tailscale
    enable_claude_user = $enable_claude_user$( [ "$enable_claude_user" = true ] && echo "   (claude signs commits: $claude_sign_commits)" )
    enable_credentials = $enable_credentials
    enable_libreoffice = $enable_libreoffice
    enable_kdenlive    = $enable_kdenlive
    enable_thunderbird = $enable_thunderbird
    enable_file_managers = $enable_file_managers
    enable_image_viewers = $enable_image_viewers
    enable_wallpapers  = $enable_wallpapers
    enable_firefox     = $enable_firefox
    enable_firefoxpwa  = $enable_firefoxpwa
    enable_trading     = $enable_trading
    enable_nvidia      = $enable_nvidia
    enable_razer       = $enable_razer
    cmus_music_dir     = $cmus_music_dir
    theme_variant      = $theme_variant
    git identity       = $git_user_name <$git_user_email>$( [ -n "$git_signingkey" ] && echo "   signing $git_signingkey" )
    ssh login key      = ~/.ssh/$ssh_key_file
EOF

# First-run notice: this REPLACES existing config files. Minimal + informational,
# shown for a real apply AND a dry-run (a dry-run simulates the same action).
if $first_run; then
    echo
    echo "  ⚠️  First run: hestia REPLACES your existing config files with its own."
    if $no_backup; then
        echo "      Backups are OFF (--no-backup) — the files being replaced are NOT saved."
    else
        echo "      Each pre-existing file is first copied in place to <file>.bak (reversible)."
    fi
fi

# Gate: a real first-run apply needs an explicit `yes`; a re-run apply a plain
# Proceed; a dry-run needs no gate (it changes nothing — just runs the preview).
if ! $dry_run; then
    if $first_run; then
        read -r -p "  Type 'yes' to proceed: " _ack
        [ "$_ack" = yes ] || { echo "Aborted — nothing written or changed."; exit 0; }
    else
        askyn _proceed "Proceed?" true
        [ "$_proceed" = true ] || { echo "Aborted — nothing written or changed."; exit 0; }
    fi
fi

# --- 4. Write answers + run ----------------------------------------------------
# Only extra arg we add is --no-backup -> `-e dotfiles_backup=false`. No
# --ask-become-pass: preauth_sudo (below) handles privilege escalation with retries.
extra=()
if $no_backup; then extra+=(-e dotfiles_backup=false); fi

# Capture sudo creds FIRST — so a failed login aborts before we write host_vars or a
# temp file (keeping the abort message honest), not after.
get_become_pw

if $dry_run; then
    # DRY-RUN: don't touch the real host_vars; preview the answers via -e (highest
    # precedence, so it overrides the on-disk host_vars for this check only).
    _tmp=$(mktemp); write_answers "$_tmp"
    echo "==> DRY-RUN (--check): not writing $HOSTVARS; previewing your answers via -e."
    run_playbook "${extra[@]}" -e "@$_tmp" "${pass[@]}"
    rm -f "$_tmp"
    finish_notice
    exit 0
fi

mkdir -p "$HERE/host_vars"
write_answers "$HOSTVARS"
echo "==> Wrote $HOSTVARS"
echo "==> Running the bootstrap…"
run_playbook "${extra[@]}" "${pass[@]}"
finish_notice
