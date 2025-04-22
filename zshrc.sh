# Save history so we get auto suggestions
HISTSIZE=1048576
SAVEHIST=$HISTSIZE
HISTFILE=$HOME/.zsh_history
# History date format
HISTTIMEFORMAT="%d/%m/%y %T "

function has() {
  which "$@" > /dev/null 2>&1
}

if has vim ; then
  alias vi=vim
fi

if has nvim ; then
  alias vim=vim
else
  alias vim="vim -X -u $HOME/.vimrc"
fi


if has nvim ; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi

if has eza ; then
  alias ll="eza -l --all --all --git --git-repos"
  alias ls="eza"
fi

# Some environment defaults
export LANG=en_US.UTF-8
export RSYNC_RSH=ssh
export PAGER=less
export LESS="-nXR"
DF=$HOME/.dotfiles

export STARSHIP_CONFIG=$DF/starship.toml
export STARSHIP_CACHE=$DF/.cache/starship


# Create repos directory if it doesn't exist
mkdir -p $DF/.cache/repos

# Download Znap, if it's not there yet.
[[ -r $DF/.cache/repos/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git $DF/.cache/repos/znap
source $DF/.cache/repos/znap/znap.zsh  # Start Znap


# ^S and ^Q cause problems and I don't use them. Disable stty stop.
stty stop ""
stty start ""

## zsh options settings
setopt no_beep                   # Beeping is annoying. Die.
setopt no_prompt_cr              # Don't print a carraige return before the prompt 
setopt interactivecomments       # Enable comments in interactive mode (useful)
setopt extended_glob             # More powerful glob features
setopt append_history            # Append to history on exit, don't overwrite it.
setopt extended_history          # Save timestamps with history
setopt hist_no_store             # Don't store history commands
setopt hist_save_no_dups         # Don't save duplicate history entries
setopt hist_ignore_all_dups      # Ignore old command duplicates (in current session)
setopt inc_append_history        # save history entries as soon as they are entered
setopt no_share_history
setopt auto_pushd		# Automatically pushd when I cd
setopt nocdable_vars
setopt hist_reduce_blanks	# remove superfluous blanks from history items
unsetopt correct_all 		# autocorrect commands
setopt auto_list		# automatically list choices on ambiguous completion
setopt auto_menu		# automatically use menu completion
setopt always_to_end		# move cursor to end if word had one match


# Set up $PATH
function notinpath {
  for tmp in $path; do
    [ $tmp = $1 ] && return 1
  done

  return 0
}

function addpaths {
  for i in $*; do
    i=${~i}
    if [ -d "$i" ]; then
      notinpath $i && path+=$i
    fi
  done
}

function delpaths {
  for i in $*; do
    i=${~i}
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "$i" | tr '\n' ':')"
  done
}

eval "$(zoxide init zsh)"

# export NVM_AUTO_USE=true  

# Load local files

[ -f $DF/.env.secrets.sh ] && source $DF/.env.secrets.sh
[ -f $DF/aliases.local.sh ] && source $DF/aliases.local.sh

export BASH_SILENCE_DEPRECATION_WARNING=1

if [ -d "$HOME/go/bin" ]; then
  # Golang
  addpaths $HOME/go/bin
fi

if [ -d "$HOME/development/flutter/bin" ]; then
  # Flutter
  addpaths $HOME/development/flutter/bin
fi

if [ -d "/usr/local/opt/ruby/bin" ]; then
  # Ruby
  addpaths "/usr/local/opt/ruby/bin"
  export GEM_HOME=$HOME/.gem
  addpaths $GEM_HOME/bin
  addpaths /Users/valeriy/.gem/ruby/3.3.0/bin
fi

if [ -d "$HOME/.dotnet" ]; then
  # .NET
  addpaths "$HOME/.dotnet"
fi

if [ -d "$HOME/.yarn/bin" ]; then
  # Yarn
  addpaths $HOME/.yarn/bin
  addpaths $HOME/.config/yarn/global/node_modules/.bin
fi

# System
addpaths /usr/local/sbin
addpaths /usr/local/bin

autoload -U colors
colors

export JAVA_HOME=`/usr/libexec/java_home`

export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
NVM_LOADED=false
function nvm() {
  if ! $NVM_LOADED; then
    # Bright green
    echo "\e[1;32mLoading NVM\e[0m"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    NVM_LOADED=true
    # If has params, run nvm
    if [ $# -gt 0 ]; then
      nvm "$@"
    fi
  else
    command nvm "$@"
  fi
}

eval "$(starship init zsh)"

source <(fzf --zsh)
znap source marlonrichert/zsh-autocomplete
znap source zsh-users/zsh-autosuggestions
znap source zsh-users/zsh-completions
znap source zsh-users/zsh-syntax-highlighting
znap source zsh-users/zsh-history-substring-search

# Keybindings
bindkey '^[[3~' delete-char
bindkey '^[3;5~' delete-char

# bindkey '^[[A' fzf-history-widget
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
# Cmd+R
bindkey '^R' fzf-history-widget
bindkey '^W' vi-backward-kill-word

# Enable autocompletions
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
  compinit -i
else
  compinit -C -i
fi
zmodload -i zsh/complist

if has kubectl ; then
  source <(kubectl completion zsh)
fi

# If gh is installed, add it's completion
if has gh ; then
  source <(gh completion -s zsh)
fi

# Improve autocompletion style
# zstyle ':completion:*' default-context history-incremental-search-backward
zstyle ':completion:*' menu select # select completions with arrow keys
zstyle ':completion:*' group-name '' # group results by category
zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion

if [ -f "$HOME/.local/share/../bin/env" ]; then
  . "$HOME/.local/share/../bin/env"
fi

if [ -f "$HOME/.svix/bin/env" ]; then
  . "$HOME/.svix/bin/env"
fi

alias scaffold="bash $DF/scaffold.sh"