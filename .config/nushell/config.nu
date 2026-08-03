# config.nu — shell configuration
# Ported from ~/.config/zsh/{.zshrc,aliases}

# Shell settings
$env.config = {
    show_banner: false
    datetime_format: { normal: "%Y-%m-%d %H:%M" table: "%Y-%m-%d %H:%M" }
    table: {
        mode: rounded
        padding: { left: 1 right: 1 }
    }
    edit_mode: vi
    history: {
        max_size: 10000
        file_format: "sqlite"
    }
    completions: {
        case_sensitive: false
        partial: true
        algorithm: "prefix"
        external: { enable: true }
    }
    cursor_shape: {
        vi_insert: line
        vi_normal: block
    }
    hooks: {
        pre_prompt: [{ ||
            if (which direnv | is-not-empty) {
                let result = (^direnv export json | complete)
                if $result.exit_code == 0 and ($result.stdout | is-not-empty) {
                    $result.stdout | from json | load-env
                }
            }
        }]
    }
    keybindings: [
        {
            name: edit_command_line
            modifier: control
            keycode: char_e
            mode: [emacs vi_insert vi_normal]
            event: { send: OpenEditor }
        }
        {
            name: clear_line
            modifier: control
            keycode: char_u
            mode: [emacs vi_insert vi_normal]
            event: [{ edit: CutFromLineStart }]
        }
        {
            name: accept_hint_word
            modifier: control
            keycode: char_f
            mode: [emacs vi_insert]
            event: { send: HistoryHintWordComplete }
        }
        {
            name: accept_hint_full
            modifier: control
            keycode: space
            mode: [emacs vi_insert]
            event: { send: HistoryHintComplete }
        }
    ]
}

use ~/src/nu_scripts/themes/nu-themes/mono-white.nu
$env.config.color_config = (mono-white)
$env.config.color_config.hints = { fg: "#666666" }

# ===========================
# Aliases
# ===========================

# list

# convenience
alias tm = tmux attach
alias lg = lazygit
alias apv = mpv --vid=no

# fd
def --wrapped fd [...args] {
    let fd_bin = if ("/opt/homebrew/bin/fd" | path exists) {
        "/opt/homebrew/bin/fd"
    } else {
        "fd"
    }
    ^$fd_bin --hidden ...$args
}

# ===========================
# Functions / Custom Commands
# ===========================

# colored echo
def becho [...args: string] {
    print $"(ansi cyan)($args | str join ' ')(ansi reset)"
}
def gecho [...args: string] {
    print $"(ansi green)($args | str join ' ')(ansi reset)"
}
def recho [...args: string] {
    print $"(ansi red)($args | str join ' ')(ansi reset)"
}

# set terminal title
def stt [title: string] {
    print -n $"\e]2;($title)\e\\"
}

# repeat a command every N seconds
def repeat-cmd [
    --time (-t): int = 1  # seconds between runs
    ...cmd: string        # command to run
] {
    while true {
        sleep ($time * 1_000_000_000 | into int | into duration)
        clear
        nu -c ($cmd | str join " ")
    }
}
# tar shortcuts
def tarx [file: path] { ^tar -xvf $file }
def tarc [dir: path] { ^tar -cvf $"($dir).tar" $dir }
def zipd [dir: path] { ^zip -rv $"($dir).zip" $dir }

# jq but don't break on non-json lines
def jqr [] {
    each {|line| try { $line | from json } catch { $line }}
}

# jwt decode
def jwt-decode [token: string] {
    let payload = ($token | split row "." | get 1)
    $"($payload)==" | decode base64 | decode utf-8 | from json
}

# curl with status code
def scurl [...args: string] {
    ^curl --silent -w "\nstatus: %{http_code}\n" ...$args
}

# lf - switch directories
def --env lfcd [...args: string] {
    let tmp = (mktemp)
    ^lf $"-last-dir-path=($tmp)" ...$args
    let dir = (open $tmp | str trim)
    rm -f $tmp
    if ($dir | path exists) and ($dir != $env.PWD) {
        cd $dir
    }
}

# mv and cd into last arg
def --env mc [...args: string] {
    let dest = ($args | last)
    ^mv ...$args
    cd $dest
}

# rmlink - remove symlink
def rmlink [link: path] {
    if ($link | path type) == "symlink" {
        rm -v $link
    } else {
        print -e $"'($link)' is not a symlink"
    }
}

# edit_today: open <today>.md in editor
def et [suffix?: string] {
    let fname = if ($suffix | is-not-empty) {
        $"(date now | format date '%Y-%m-%d')-($suffix).md"
    } else {
        $"(date now | format date '%Y-%m-%d').md"
    }
    run-external $env.EDITOR $fname
}

# ===========================
# Git Aliases
# ===========================

alias gc = git commit -m
alias gcm = git commit -m
alias gca = git commit -a
alias gcam = git commit -am
alias gs = git status
alias gco = git checkout

def gl [] {
    ^git log --pretty=format:'%C(auto)%h %ad %C(green)%s%Creset %C(auto)%d [%an]' --graph --date=format:'%Y-%m-%d %H:%M' --all
}

def gbr [] {
    ^git for-each-ref --sort=-committerdate refs/heads/ --format="%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))"
}

# open merge-conflicted files in editor
def gde [] {
    let files = (git diff --name-only --diff-filter=U | lines | uniq)
    if ($files | is-not-empty) {
        run-external $env.EDITOR ...$files
    }
}

# ===========================
# Google Cloud SDK (if available)
# ===========================

# gcloud completions — source if the file exists
# Note: gcloud shell integration for nushell may need manual setup

# kubectl completions — nushell has a kubectl module available via `nu_scripts`
# Compact ls -l (like zsh ls -lh)

# Compact long listing with sort options
def ll [
    ...args: glob       # paths
    --all (-a)          # show hidden
    --time (-t)         # sort by modified time (newest last)
    --reverse (-r)      # reverse sort
] {
    let result = if ($args | is-empty) {
        if $all { ls -la } else { ls -l }
    } else {
        if $all { ls -la ...$args } else { ls -l ...$args }
    }
    let cols = ($result | each {|row|
        let bytes = ($row.size | into int)
        let formatted = if $bytes >= 1000000000 {
            let n = ($bytes | into float) / 1000000000.0
            $"($n | math round --precision 1 | fill --alignment right --width 5) GB"
        } else if $bytes >= 1000000 {
            let n = ($bytes | into float) / 1000000.0
            $"($n | math round --precision 1 | fill --alignment right --width 5) MB"
        } else if $bytes >= 1000 {
            let n = ($bytes | into float) / 1000.0
            $"($n | math round --precision 1 | fill --alignment right --width 5) kB"
        } else {
            $"($bytes | fill --alignment right --width 5)  B"
        }
        $row | update size $formatted
    } | update name {|row| $row.name | path basename} | select name type mode user group size modified created)
    let sorted = if $time and $reverse {
        $cols | sort-by modified --reverse
    } else if $time {
        $cols | sort-by modified
    } else if $reverse {
        $cols | reverse
    } else {
        $cols
    }
    $sorted | update name {|row|
        if ($row.type == "dir") { $"(ansi { fg: '#ffffff' attr: b })($row.name)(ansi reset)" } else { $"(ansi { fg: '#ffffff' })($row.name)(ansi reset)" }
    } | reject type
}

alias la = ll -a
alias lt = ll -tr
alias lta = ll -at
alias ltr = ll -t
alias lrt = ll -t

# List available themes
# use ~/.config/nushell/themes.nu *

# wenv — working environment manager
source ~/src/wenv/nu/wenv.nu

# Carapace Completions

let carapace_completer = {|spans| carapace $spans.0 nushell ...$spans | from json }
$env.config.completions.external.enable = true
$env.config.completions.external.completer = $carapace_completer
