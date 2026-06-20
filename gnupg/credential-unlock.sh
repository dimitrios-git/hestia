#!/bin/sh
# Login credential unlock — run once at session start (Sway exec).
#
# The gnome-keyring Secret Service is unlocked by pam_gnome_keyring at login
# (with the login password). This hook reads the SSH + GPG passphrases from it
# and loads them into the existing agents, so neither needs a per-boot manual
# unlock. SSH stays on the Debian ssh-agent; GPG on our gpg-agent. The passphrases
# live in the keyring (arbitrary, distinct from the login password — the keyring,
# not the keys, is what the login password unlocks). See
# docs/credential-autounlock-design.md.
HERE=$(dirname "$(readlink -f "$0")")

# --- SSH: load the key into the Debian ssh-agent using the keyring passphrase ---
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openssh_agent"
SSH_ASKPASS="$HERE/keyring-ssh-askpass.sh" SSH_ASKPASS_REQUIRE=force \
    ssh-add "$HOME/.ssh/id_dimitrios" </dev/null 2>/dev/null

# --- GPG: warm gpg-agent's signing cache with a loopback sign of /dev/null.
#     (gpg-preset-passphrase caches into a slot the signing path doesn't use; a
#     real loopback sign warms the normal cache and validates the passphrase.) ---
KEYGRIP=7C8A1E890C3A88591A1D28F880127B5F1A8D449D
SIGNKEY=EB90A5A2D628F2A6
gpgpass=$(secret-tool lookup autounlock gpg keygrip "$KEYGRIP" 2>/dev/null)
[ -n "$gpgpass" ] && printf '%s' "$gpgpass" | \
    gpg --batch --no-tty --pinentry-mode loopback --passphrase-fd 0 \
        -u "$SIGNKEY" -o /dev/null --sign /dev/null 2>/dev/null
