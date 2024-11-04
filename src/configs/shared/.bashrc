# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in xterm-color|*-256color) color_prompt=yes;;
esac

# TODO: how does this work on Arch...?
# If this is an xterm set the title to user@host:dir
case "$TERM" in xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias gnome-control-center="env XDG_CURRENT_DESKTOP=GNOME gnome-control-center"

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

#########################################################################################################
#################################### Custom Configurations (Shared) #####################################
#########################################################################################################

parse_git_branch() {
    if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ];
    then
        git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
    else
        echo ""
    fi
}

# Change NodeJS version when entering specified directories
cd() {
    builtin cd "$@"
    if [ -f .nvmrc ]; then
        nvm use
    fi
}

# export color prompt
# export PS1="\[\e[36m\][\[\e[m\]\[\e[33m\]\u\[\e[m\]\[\e[31m\]@\[\e[m\]\[\e[36m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[36m\]]\[\e[m\]\[\e[36;36m\]\\$\[\e[m\] "
# export PS1="\[\e[36m\][\[\e[m\]\[\e[33m\]\u\[\e[m\]\[\e[31m\]@\[\e[m\]\[\e[36m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[32m\]\$(parse_git_branch)\[\e[m\]\]\e[36;36m\]]\\$\e[m\] "
BLUE="\[\e[36m\]"
GREEN="\[\e[32m\]"
RED="\[\e[31m\]"
YELLOW="\[\e[33m\]"
WHITE="\[\e[m\]"
DOLLAR_SIGN="\\$"
export PS1="${BLUE}[${YELLOW}\u${RED}@${BLUE}\h${WHITE}:${BLUE}\w${GREEN}\$(parse_git_branch)${BLUE}]${DOLLAR_SIGN} ${WHITE}"

export BROWSER=/usr/bin/google-chrome-stable
export EDITOR=/usr/bin/vim

alias barrier='/usr/local/bin/barrier-2.1.2/barrier-2.1.2-startup'
alias xdotool='/usr/bin/xdotool'
alias gitgraph='/usr/bin/git log --all --decorate --graph --oneline'
alias trello="$(npm list -g | head -1)/node_modules/trello-cli/bin/trello"

# global sendkey function
grabwindow() { xdotool windowactivate $(xdotool search --name "$1"); }
keystroketowindow() { echo $3; grabwindow "$2" && xdotool key "$1"; sleep 1; }

export PYTHONDONTWRITEBYTECODE=True

# this enables syntax highlighting in Termite
export TERM=xterm-256color

export NVM_DIR=~/.nvm
source ~/.nvm/nvm.sh

export CDPATH=.:..:../..:$HOME:$HOME/src:$HOME/Projects:$HOME/Coding

# add all utils (and scripts within .config) to PATH
export PATH="$(find ~/bin/ -type d -printf ":%p"):$PATH"
export PATH="$HOME/bin:$HOME/bin/*:$PATH"
#export PATH="$(find ~/.config/ -type d -printf ":%p"):$PATH"
export PATH=$PATH:/opt/sonar/bin

#~/.config/i3/sh/xrandr-layout.sh
export WORKFLOW_BASE=/mnt/D/Coding/Projects/Personal/.workflow
export PYTHONPATH="${PYTHONPATH}:/mnt/D/Coding/Projects/Personal/.workflow"

if [ -f /usr/local/src/alacritty/extra/completions/alacritty.bash ]; then
    source /usr/local/src/alacritty/extra/completions/alacritty.bash
fi

if command -v neofetch &> /dev/null
then
    neofetch
fi

git config --global pull.rebase true

export DOCKER_USER="$(id -u):$(id -g)"

LS_COLORS+=':ow=01;33'

export PRIVATE_KEY=$(base64 < ~/.ssh/id_rsa)
export PUBLIC_KEY=$(base64 < ~/.ssh/id_rsa.pub)
