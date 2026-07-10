#!/bin/sh
# Session-time integration for nemo, the default GUI file manager — run once at
# login from the sway config (`exec …/scripts/nemo-setup.sh`). Everything is
# guarded on nemo's presence: a spin with enable_file_managers=false has no nemo
# (hence no org.cinnamon.* / org.nemo.* schemas), so this is a clean no-op instead
# of a gsettings "No such schema" error. dconf + mimeapps.list persist, so a
# relogin re-asserts. This lives in a script rather than an inline `exec sh -c …`
# because the GVariant value below (single quotes inside an array) does not survive
# sway's config-line quoting on top of its `sh -c` wrapper.
command -v nemo >/dev/null 2>&1 || exit 0

# "Open in Terminal" launches org.cinnamon.desktop.default-applications.terminal,
# whose schema default gnome-terminal isn't installed here — so the menu item
# silently no-ops. Point it at kitty (exec-arg -e for the run-a-command case).
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty
gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg -e

# Make nemo the default folder handler — a folder opened from any app lands here.
xdg-mime default nemo.desktop inode/directory

# Silence the "Create a new launcher here" action: it Depends on
# cinnamon-desktop-editor (a Cinnamon package hestia doesn't ship), so nemo logs
# `Action '90_new-launcher.nemo_action' is missing dependency: cinnamon-desktop-editor`
# at every startup and shows a dead menu entry. Disabling it via nemo's own key
# removes both — no cinnamon install.
gsettings set org.nemo.plugins disabled-actions "['90_new-launcher.nemo_action']"
