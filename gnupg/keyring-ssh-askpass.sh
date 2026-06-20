#!/bin/sh
# SSH_ASKPASS helper for the login credential-unlock hook: print the
# id_dimitrios key passphrase from the gnome-keyring Secret Service (unlocked by
# PAM at login). Used by gnupg/credential-unlock.sh so `ssh-add` can load the key
# non-interactively. See docs/credential-autounlock-design.md.
exec secret-tool lookup autounlock ssh keyfile id_dimitrios
