#!/usr/bin/env zsh

# enable more zsh-specific globbing patterns
# NOTE: this may break certain commands/operations involving ^, ?, [], etc.
setopt extendedglob
# disown background processes
setopt NO_HUP
# remove commands prefixed with a space from history
setopt hist_ignore_space
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
# Per-host prompt colorspalette
if [[ $HOST == grishpad ]]; then
  _pc_user=161 _pc_at=250 _pc_host=242 _pc_colon=238 _pc_path=75
else
  _pc_user=89 _pc_at=252 _pc_host=245 _pc_colon=252 _pc_path=227
fi
PS1="\$(wenv_prompt)
%F{$_pc_user}%n%F{$_pc_at}@%F{$_pc_host}%M%F{$_pc_colon}:%F{$_pc_path}%~%f\$(git_branch_prompt)
$%b "

# History in cache directory:
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$XDG_CONFIG_HOME/zsh/history"
setopt INC_APPEND_HISTORY

# cd into directory automatically
setopt AUTO_CD

export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"

# Basic auto/tab complete. Cache the dump: full rebuild (+ security audit) only
# when it's missing or >24h old, otherwise reuse it (-C). Saves ~200ms/shell.
autoload -Uz compinit
fpath=($XDG_DATA_HOME/zsh/completions $fpath)
mkdir -p "${ZSH_COMPDUMP:h}"
() {
  # N: nullglob - if glob is empty, just expand to "" instead of erroring
  # mh-24: match by *m*odification time, in *h*ours, less then 24 (hours) ago
  #   -> match files modified in the last day
  # So these two lines add the -C flag to 'bypass security and dump-file checks'
  # if the compdump file was (re)generated in the last 24 hours
  local dump=("$ZSH_COMPDUMP"(Nmh-24))
  # adds -C flag if the $dump array is non-empty
  compinit ${dump:+-C} -d "$ZSH_COMPDUMP"
}
zmodload zsh/complist
_comp_options+=(globdots) # Include hidden files.
zstyle ':completion:*' menu select
# zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' '+l:|=* r:|=*'
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# bindkey '\t' expand-or-complete-prefix
# tab-completion in the middle of file + directory names (e.g. 'ownlo' can tab-complete to 'downloads')

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
lfcd() {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}
bindkey -s '^o' 'lfcd\n'

# ctrl-r fzf fuzzy selector, other things probably.
# cache `fzf --zsh`, regenerate when the fzf binary path changes (nix version bumps)
() {
  local cache=$XDG_CACHE_HOME/zsh/fzf.zsh
  # :A resolves the symlink to the /nix/store path, which changes on version bumps
  if [[ ! -s $cache || ${${(f)"$(<$cache)"}[1]} != "# ${commands[fzf]:A}" ]]; then
    print -r -- "# ${commands[fzf]:A}" > $cache
    fzf --zsh >> $cache
  fi
  source $cache
}

flirt-widget() {
  LBUFFER="${LBUFFER}$(flirt -x </dev/tty 2>/dev/tty)"
  # LBUFFER="${LBUFFER}$(flirt -x </dev/tty)"
  local ret=$?
  zle reset-prompt
  return $ret
}
zle -N flirt-widget
bindkey '^h' flirt-widget

# Edit line in vim with ctrl-e:
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line

# completion stuff (NOTE: requires installing this plugin)
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh 2>/dev/null
bindkey -M vicmd k history-substring-search-up
bindkey -M vicmd j history-substring-search-down

# fish-like autosuggestions plugin (this is needed on Arch, on NixOS it's provided by programs.zsh -> sourced from /etc/zshrc)
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^ ' autosuggest-accept
# these only work while typing / in 'insert' mode
bindkey '^f' vi-forward-word # move cursor forward a word, which also has the effect of incremental completion w/ the autosuggestions
bindkey '^b' vi-backward-word # this doesn't undo any typing/completion, just moves the cursor

# Load zsh-syntax-highlighting; should be last.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

ZSH_HIGHLIGHT_STYLES[alias]=fg=cyan
ZSH_HIGHLIGHT_STYLES[builtin]=fg=cyan
ZSH_HIGHLIGHT_STYLES[function]=fg=cyan
ZSH_HIGHLIGHT_STYLES[command]=fg=cyan
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red

if [ -s /var/log/backup-space.log ] && grep -q "WARNING" /var/log/backup-space.log; then
    echo "!!!!! Warning: backup drive running low on space !!!!!"
fi

# enable bash completion
autoload bashcompinit
bashcompinit

compdef _wenv __wenv

source $SRC/wenv/wenv
[[ -n $WENV ]] && wenv_source $WENV

# load completions
for completion_file in $XDG_DATA_HOME/zsh/completions/bash/*; do source $completion_file; done
complete _docker_compose docker-compose

[[ -f "$XDG_CONFIG_HOME/zsh/aliases" ]] && source "$XDG_CONFIG_HOME/zsh/aliases"
[[ -f "$XDG_CONFIG_HOME/zsh/secrets" ]] && source "$XDG_CONFIG_HOME/zsh/secrets"
