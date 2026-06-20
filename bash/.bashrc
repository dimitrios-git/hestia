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

if [ "$color_prompt" = yes ]; then
PS1="${debian_chroot:+($debian_chroot)}\[\033[1;34m\]\w"
PS1+="\[\033[1;33m\]\$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/')"
PS1+="\[\033[1;32m\]\$(staged_changes=\$(git diff --cached --numstat 2>/dev/null | wc -l); [[ \$staged_changes -gt 0 ]] && echo \" +\$staged_changes\")"
PS1+="\[\033[1;31m\]\$(unstaged_changes=\$(git diff --numstat 2>/dev/null | wc -l); [[ \$unstaged_changes -gt 0 ]] && echo \" !\$unstaged_changes\")"
PS1+="\[\033[1;31m\]\$(untracked_files=\$(git ls-files --others --exclude-standard 2>/dev/null | wc -l); [[ \$untracked_files -gt 0 ]] && echo \" ?\$untracked_files\")"
PS1+="\[\033[\$(prompt_exit_status_color)\] \\$\[\033[00m\] "
else
    PS1="${debian_chroot:+($debian_chroot)}\w\$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/') \\$ "
fi
unset color_prompt force_color_prompt

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
    export LESS='-R --use-color -Dd+r$Du+b'
    export MANPAGER="less -R --use-color -Dd+r -Du+b"
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

# fix docker dark blue color
export BUILDKIT_COLORS="run=light-blue:error=light-red:cancel=light-cyan:warning=light-red"

# Local user binaries (e.g. ~/.local/bin, where bluetuith lives) on PATH.
# Guarded so it isn't re-prepended when already inherited (the greetd login
# shell sources .profile, which also adds it) — avoids duplicate PATH entries
# while keeping .bashrc self-sufficient for interactive shells.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

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
# shell, starting in the neutral shared tree /srv/dev). Claude Code, run there,
# operates as claude — own ssh/git/gpg identity, kernel-isolated from this
# account's secrets. See docs/claude-user-design.md.
claude-shell() {
    sudo -iu claude bash -c 'cd /srv/dev 2>/dev/null; exec bash -l'
}

# SSH: point at the Debian socket-activated ssh-agent user service (ssh-agent.socket).
# greetd doesn't source this file, so interactive shells (terminals, Ansible) set it here;
# Sway sets it for itself. Load a key with: ssh-add ~/.ssh/id_dimitrios
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Qt Looks
export QT_QPA_PLATFORMTHEME='gtk3'

# Secrets / tokens — kept out of the repo in ~/.bash_secrets
[ -f ~/.bash_secrets ] && . ~/.bash_secrets
