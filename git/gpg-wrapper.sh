#!/bin/sh
# Wrapper for git's gpg.program (set by absolute path in git/.gitconfig).
#
# Inside Claude Code the controlling terminal belongs to Claude's TUI. gpg-agent
# launches pinentry on the terminal named by GPG_TTY (here /dev/pts/0, Claude's
# own terminal) — NOT on the calling process's stdin — so ANY terminal pinentry
# (tty or curses) seizes the interface: you can't type the passphrase or control
# the prompt. pinentry-tty does not fix this; the tty takeover is the problem.
#
# So when CLAUDECODE is set, pass --pinentry-mode error: a warm passphrase cache
# still signs silently, but a COLD cache fails fast with a clear error instead of
# spawning pinentry and wedging the terminal. Claude then asks you to unlock GPG
# in a normal terminal and retries. In a normal terminal (CLAUDECODE unset) gpg
# runs untouched and uses pinentry-tty per ~/.gnupg/gpg-agent.conf.
if [ -n "$CLAUDECODE" ]; then
    exec gpg --pinentry-mode error "$@"
fi
exec gpg "$@"
