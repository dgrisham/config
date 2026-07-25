#!/usr/bin/zsh

# enable more zsh-specific globbing patterns
# NOTE: this may break certain commands/operations involving ^, ?, [], etc.
setopt extendedglob
# disown background processes
setopt NO_HUP
# remove commands prefixed with a space from history
setopt hist_ignore_space
# setopt hist_ignore_all_dups
setopt hist_ignore_all_dups

wenv_prompt() {
    [[ -n "$WENV" ]] && echo "($WENV)"
}

git_branch_prompt() {
    local branch=$(git branch --show-current 2>/dev/null)
    [[ -n "$branch" ]] && echo " ($branch)"
}

# Enable colors and change prompt:
autoload -U colors && colors
setopt prompt_subst

PS1="\$(wenv_prompt)
%F{161}grish%F{250}@%F{242}gunmetal%F{238}:%F{75}%~%f\$(git_branch_prompt)
$%b "

# PS1="\$(wenv_prompt)
# %F{161}%n%F{250}@%F{242}%M%F{238}:%F{75}%~%f\$(git_branch_prompt)
# $%b "

# History in cache directory:
HISTSIZE=10000
SAVEHIST=10000

histdir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$histdir"
HISTFILE="$histdir/history"
setopt INC_APPEND_HISTORY

# cd into directory automatically
setopt AUTO_CD

# Basic auto/tab complete:
autoload -Uz compinit
fpath=($XDG_DATA_HOME/zsh/completions $fpath)
compinit
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' sort false
# tab-completion in the middle of file + directory names (e.g. 'ownlo' can tab-complete to 'downloads')
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
_comp_options+=(globdots) # Include hidden files.

# bindkey '\t' expand-or-complete-prefix

# vi mode
bindkey -v
export KEYTIMEOUT=1

# history search
bindkey "^R" history-incremental-search-backward

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# Use lf to switch directories and bind it to ctrl-o
lfcd () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}
bindkey -s '^o' 'lfcd\n'

flirt-widget() {
  # LBUFFER="${LBUFFER}$(flirt -x </dev/tty 2>/dev/tty)"
  LBUFFER="${LBUFFER}$(flirt -x)"
  local ret=$?
  zle reset-prompt
  return $ret
}
zle -N flirt-widget
bindkey '^h' flirt-widget

# Edit line in $EDITOR with ctrl-e:
autoload edit-command-line; zle -N edit-command-line
bindkey "^E" edit-command-line
# make it work when in 'normal' vim mode (e.g. after hitting Esc)
bindkey -M vicmd "^E" edit-command-line

# completion stuff (NOTE: requires installing this plugin)
source $HOMEBREW_ROOT/share/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey -M vicmd k history-substring-search-up
bindkey -M vicmd j history-substring-search-down

# fish-like autosuggestions plugin
source $HOMEBREW_ROOT/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept
# these only work while typing / in 'insert' mode
bindkey '^f' vi-forward-word # move cursor forward a word, which also has the effect of incremental completion w/ the autosuggestions
bindkey '^b' vi-backward-word # this doesn't undo any typing/completion, just moves the cursor

# Load zsh-syntax-highlighting; should be last.
source $HOMEBREW_ROOT/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

ZSH_HIGHLIGHT_STYLES[alias]=fg=cyan
ZSH_HIGHLIGHT_STYLES[builtin]=fg=cyan
ZSH_HIGHLIGHT_STYLES[function]=fg=cyan
ZSH_HIGHLIGHT_STYLES[command]=fg=cyan
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red

# enable bash completion
autoload bashcompinit
bashcompinit

source $SRC/wenv/wenv
[[ -n "$WENV" ]] && wenv_source "$WENV"

# load completions
for completion_file in $XDG_CONFIG_HOME/zsh/completions/*; do source $completion_file; done
complete _docker_compose docker-compose

[[ -f "$XDG_CONFIG_HOME/zsh/aliases" ]] && source "$XDG_CONFIG_HOME/zsh/aliases"

source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

source <(kubectl completion zsh)

[[ -n $CHANGE_TO_DIR ]] && cd $CHANGE_TO_DIR
[[ -n $CUSTOM_RUN    ]] && eval "$CUSTOM_RUN"
