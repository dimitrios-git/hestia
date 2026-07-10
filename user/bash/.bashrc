# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Update LINES and COLUMNS after each command
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Identify the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Prompt
case "$TERM" in
    xterm-color|*-256color|xterm-kitty|alacritty) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# Save the exit status of the last command for the prompt colour
PROMPT_COMMAND="last_exit_status=\$?"

prompt_exit_status_color() {
    if [ "$last_exit_status" -eq 0 ]; then
        echo "01;92m"  # Green for success
    else
        echo "01;91m"  # Red for failure
    fi
}

# Username segment: prepended only for elevated / agent identities, so a normal
# login prompt stays "path branch $". Root → red, the `claude` agent → orange.
# This is ONE adaptive rc sourced by each user, colouring itself by $EUID/$USER
# — which is why `sudo su` shows red: root sources THIS file, not the caller's
# bashrc (a "go red when root" check in the caller's prompt never fires, since
# you're running root's shell once elevated). Empty for a normal login user.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    prompt_user_color='1;31'        # root: red
elif [ "$(id -un)" = claude ]; then
    prompt_user_color='38;5;208'    # claude agent: orange
else
    prompt_user_color=''            # normal user: no username segment
fi

if [ "$color_prompt" = yes ]; then
PS1="${debian_chroot:+($debian_chroot)}"
[ -n "$prompt_user_color" ] && PS1+="\[\033[${prompt_user_color}m\]\u "
PS1+="\[\033[1;34m\]\w"
PS1+="\[\033[1;33m\]\$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/')"
PS1+="\[\033[1;32m\]\$(staged_changes=\$(git diff --cached --numstat 2>/dev/null | wc -l); [[ \$staged_changes -gt 0 ]] && echo \" +\$staged_changes\")"
PS1+="\[\033[1;31m\]\$(unstaged_changes=\$(git diff --numstat 2>/dev/null | wc -l); [[ \$unstaged_changes -gt 0 ]] && echo \" !\$unstaged_changes\")"
PS1+="\[\033[1;31m\]\$(untracked_files=\$(git ls-files --others --exclude-standard 2>/dev/null | wc -l); [[ \$untracked_files -gt 0 ]] && echo \" ?\$untracked_files\")"
PS1+="\[\033[\$(prompt_exit_status_color)\] \\$\[\033[00m\] "
else
    PS1="${debian_chroot:+($debian_chroot)}${prompt_user_color:+\u }\w\$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/') \\$ "
fi
unset color_prompt force_color_prompt prompt_user_color

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip -color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    # less/man colours on the hestia palette (-D <class><colour>; '+' keeps the
    # original attribute, lowercase=normal, UPPER=bright, two letters=fg+bg):
    #   d+r  bold      -> accent red  (man section headers / commands)
    #   u+b  underline -> blue        (man args / options)
    #   Sky  search    -> black on yellow (highlighter; matches vim's search)
    #   PWr  prompt    -> bright-white on accent (the bottom status bar — so it
    #                     matches vifm/cmus and harmonises with the accent cursor
    #                     that parks next to it, instead of less's default cyan)
    #   NK   line nums -> grey (when -N is on)
    #   E+R  errors    -> bright red
    export LESS='-R --use-color -Dd+r -Du+b -DSky -DPWr -DNK -DE+R'
    export MANPAGER="less -R --use-color -Dd+r -Du+b -DSky -DPWr -DNK -DE+R"
fi

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# "alert" alias for long running commands, e.g.: sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions (kept in ~/.bash_aliases)
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Programmable completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# enable vi mode
set -o vi

# docker/buildkit build output on the hestia palette. BUILDKIT_COLORS takes
# either colour names or R,G,B triples — pin to exact hex-as-RGB so the build log
# matches everything else (default buildkit blue is unreadable on near-black):
#   run     -> blue   #0087d7  (progress / active step)
#   warning -> yellow #d78700
#   error   -> attention red #d7005f  (kept red; the accent is now violet)
#   cancel  -> grey   #767676  (muted)
export BUILDKIT_COLORS="run=0,135,215:warning=215,135,0:error=215,0,95:cancel=118,118,118"

# Local user binaries (e.g. ~/.local/bin, where bluetuith lives) on PATH.
# Guarded so it isn't re-prepended when already inherited (the greetd login
# shell sources .profile, which also adds it) — avoids duplicate PATH entries
# while keeping .bashrc self-sufficient for interactive shells.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Default editor: vim (Debian's `editor` alternative defaults to nano). Covers tools
# that honour $EDITOR/$VISUAL (git uses core.editor=vim regardless; the system-wide
# `editor` alternative is set to vim by the bootstrap's packages role).
export EDITOR=vim
export VISUAL=vim

# GPG: tell gpg-agent which terminal to prompt on (needed for signing in the shell)
export GPG_TTY=$(tty)

# gpg-unlock: cache the signing passphrase so signed commits work silently —
# including Claude Code's, which fail fast ("No pinentry") on a cold cache.
# gpg-agent prompts once via pinentry-tty, then holds the passphrase for 10 min
# of inactivity (default-cache-ttl, reset on each use) up to a 2h hard cap
# (max-cache-ttl) — NOT for the whole login session. The signing key is read
# from git config, so there's no key hash to remember. Refuses to run inside
# Claude Code, where pinentry would seize Claude's terminal.
gpg-unlock() {
    if [ -n "$CLAUDECODE" ]; then
        echo "Run gpg-unlock in a normal terminal, not through Claude Code." >&2
        return 1
    fi
    local key
    key=$(git config --get user.signingkey 2>/dev/null)
    echo gpg-unlock | gpg ${key:+--local-user "$key"} --clearsign >/dev/null \
        && echo "GPG passphrase cached (10 min idle timeout, 2h hard cap)."
}

# claude-shell: drop into the dedicated `claude` agent user's context (login
# shell, starting in the neutral shared tree /srv/devshare). Claude Code, run there,
# operates as claude — own ssh/git/gpg identity, kernel-isolated from this
# account's secrets. See docs/claude-user-design.md.
claude-shell() {
    sudo -iu claude bash -c 'cd /srv/devshare 2>/dev/null; exec bash -l'
}

# ── hestia apt wrapper: keep the machine reproducible ────────────────────────
# Installing a package by hand is fine for a quick try, but it won't survive a
# rebuild. So after `apt install`, any package that ISN'T in the hestia manifest
# gets a one-line reminder to track it. BOTH `apt …` and `sudo apt …` go through
# the guard: the latter via a thin sudo wrapper, because a bash function isn't
# visible to the real sudo and habitual `sudo apt install` would otherwise skip
# the reminder. The wrapper also auto-elevates the root-only sub-commands, so you
# can drop `sudo` entirely. The repo is located from the ~/.bashrc symlink target;
# override with $HESTIA_DIR if your checkout lives elsewhere.
if command -v apt >/dev/null 2>&1; then
    HESTIA_DIR="${HESTIA_DIR:-$( _b=$(readlink -f ~/.bashrc 2>/dev/null); printf '%s' "${_b%/user/bash/.bashrc}" )}"

    # Run apt — elevating only the sub-commands that need root — then remind about
    # any just-installed package that isn't tracked.
    _hestia_apt() {
        local sub="${1:-}" rc pfx=''
        case "$sub" in
            install|reinstall|remove|purge|autoremove|autopurge|update|upgrade|full-upgrade|dist-upgrade|clean|autoclean|edit-sources)
                [ "$(id -u)" -ne 0 ] && pfx='sudo' ;;
        esac
        command $pfx apt "$@"; rc=$?
        if [ "$rc" -eq 0 ] && { [ "$sub" = install ] || [ "$sub" = reinstall ]; }; then
            _hestia_apt_untracked "${@:2}"
        fi
        return "$rc"
    }

    apt() { _hestia_apt "$@"; }

    # Intercept `sudo apt …` (the real sudo can't see the apt function above);
    # every other sudo invocation passes straight through untouched.
    sudo() {
        if [ "${1:-}" = apt ]; then shift; _hestia_apt "$@"; else command sudo "$@"; fi
    }

    # Reminder for any just-installed package not listed under apt_packages in the
    # manifest. The match is scoped to that block, so a name in a comment elsewhere
    # won't count as "tracked"; if the manifest can't be found we warn anyway.
    _hestia_apt_untracked() {
        local manifest="$HESTIA_DIR/bootstrap/group_vars/all.yml" pkg untracked=()
        for pkg in "$@"; do
            case "$pkg" in -*) continue ;; esac          # skip option flags
            if [ -r "$manifest" ] \
               && awk '/^apt_packages:/{f=1;next} f&&/^[^[:space:]]/{f=0} f' "$manifest" \
                  | grep -oE '\[[^]]*\]' | grep -qw -- "$pkg"; then
                continue                                  # already tracked → no warning
            fi
            untracked+=("$pkg")
        done
        [ ${#untracked[@]} -eq 0 ] && return 0
        printf '\n\033[1;33m⚠ hestia\033[0m  not tracked by hestia: \033[1m%s\033[0m\n' "${untracked[*]}"
        printf "  Installed by hand — it won't survive a rebuild. To make it reproducible:\n"
        printf '    1. add it to \033[1mbootstrap/group_vars/all.yml\033[0m → \033[1mapt_packages\033[0m (pick a group)\n'
        printf '    2. re-run:  \033[1m./setup.sh --tags packages\033[0m\n'
        [ -d "$HESTIA_DIR" ] && printf '  (repo: %s)\n' "$HESTIA_DIR"
        printf '\n'
    }
fi

# SSH: point at the Debian socket-activated ssh-agent user service (ssh-agent.socket).
# greetd doesn't source this file, so interactive shells (terminals, Ansible) set it here;
# Sway sets it for itself. Load a key with: ssh-add ~/.ssh/<your key>  (e.g. id_ed25519)
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"

# kitty advertises TERM=xterm-kitty, which most servers' terminfo db lacks → garbled
# keys (backspace inserts a space, etc.) over plain ssh. Advertise a universally-present
# TERM for ssh so keys work AND the server's normal login MOTD still shows (unlike
# `kitty +kitten ssh`, which bootstraps via a remote command and skips the MOTD).
# Run `kitty +kitten ssh <host>` explicitly when you want full kitty integration remotely.
[ "$TERM" = xterm-kitty ] && alias ssh='TERM=xterm-256color ssh'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Qt Looks
export QT_QPA_PLATFORMTHEME='gtk3'

# Secrets / tokens — kept out of the repo in ~/.bash_secrets
[ -f ~/.bash_secrets ] && . ~/.bash_secrets
