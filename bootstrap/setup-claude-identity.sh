#!/bin/bash
# Set up the claude agent user's identity: a passwordless SSH key (push auth) and
# a passwordless GPG key (commit signing), plus git config so claude commits as
# itself. Run AS the claude user:  sudo -u claude bash bootstrap/setup-claude-identity.sh
#
# Passwordless keys are deliberate — claude is a headless service account, so
# there's no agent-unlock/pinentry to deal with (the keys live in claude's
# 700 home, and claude is an unprivileged, no-login user). Idempotent: re-running
# won't duplicate keys. See docs/claude-user-design.md.
set -e

NAME="Claude (dimitrios's agent)"
EMAIL="claude@charalampidis.pro"

# --- SSH key (push authentication) ---
mkdir -p ~/.ssh && chmod 700 ~/.ssh
[ -f ~/.ssh/id_claude ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_claude -C "$EMAIL"

# --- GPG signing key (passwordless) ---
if ! gpg --list-secret-keys "$EMAIL" >/dev/null 2>&1; then
    gpg --batch --pinentry-mode loopback --passphrase "" \
        --quick-generate-key "$NAME <$EMAIL>" ed25519 sign 0
fi
KEYID=$(gpg --list-secret-keys --keyid-format=long --with-colons "$EMAIL" \
        | awk -F: '/^sec:/{print $5; exit}')

# --- git config: sign every commit as the bot; plain gpg (no wrapper needed) ---
git config --global user.name       "$NAME"
git config --global user.email      "$EMAIL"
git config --global user.signingkey "$KEYID"
git config --global commit.gpgsign  true
git config --global gpg.program     gpg
git config --global init.defaultBranch main

echo "=== claude identity configured (GPG key $KEYID) ==="
echo
echo "--- SSH PUBLIC KEY → add to the GitHub bot as an *Authentication* key ---"
cat ~/.ssh/id_claude.pub
echo
echo "--- GPG PUBLIC KEY → add to the GitHub bot as a *GPG* key ---"
gpg --armor --export "$KEYID"
