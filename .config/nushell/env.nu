# env.nu — environment variables
# Ported from ~/.config/zsh/profile

# Platform detection
const OS_NAME = (sys host).name

# Terminal
if ($env | get -o TMUX | default "" | is-empty) {
    $env.TERM = "xterm-256color"
}
$env.DIRENV_LOG_FORMAT = ""
$env.SHELL = "/bin/sh"
$env.DISABLE_AUTO_TITLE = true

# Directories
$env.BIN = $"($env.HOME)/bin"
$env.DOTFILES = $"($env.HOME)/dotfiles"
$env.DOWNLOADS = $"($env.HOME)/downloads"
$env.SRC = $"($env.HOME)/src"
$env.MEDIA = $"($env.HOME)/media"
$env.MUSIC = $"($env.MEDIA)/music"
$env.SCRATCH = $"($env.HOME)/scratch"

# XDG
$env.XDG_DATA_HOME = $"($env.HOME)/.local/share"
$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
$env.XDG_CACHE_HOME = $"($env.HOME)/.cache"
$env.XDG_DOWNLOAD_DIR = $env.DOWNLOADS
$env.XDG_DESKTOP_DIR = "/dev/null"

# Defaults
$env.EDITOR = "kak_session"
$env.VISUAL = $env.EDITOR
$env.BROWSER = "brave"

# Go
$env.GOPATH = $"($env.HOME)/.go"

# Services (Linux)
$env.USER_SVDIR = $"($env.XDG_CONFIG_HOME)/sv"

# App configs
$env.BEETSDIR = $"($env.XDG_CONFIG_HOME)/beets"
$env.TEXMFHOME = $"($env.XDG_CONFIG_HOME)/texmf"
$env.PASSWORD_STORE_CLIP_TIME = "1000000000"
$env.MPD_HOST = "127.0.0.1"
$env.COLUMNS = "120"
$env.MPV_HOME = $"($env.HOME)/.local/state/mpv"
$env.LF_COLORS = "di=1;97:su=97:"

# Homebrew (macOS)
$env.HOMEBREW_ROOT = (if $OS_NAME == "Darwin" {
    if ("/opt/homebrew" | path exists) {
        "/opt/homebrew"
    } else if ($"($env.HOME)/.homebrew" | path exists) {
        $"($env.HOME)/.homebrew"
    } else {
        ""
    }
} else {
    ""
})

# PATH — common entries
$env.PATH = (
    $env.PATH | prepend [
        $"($env.HOME)/.cargo/bin"
        $"($env.GOPATH)/bin"
        $"($env.HOME)/.config/yarn/global/node_modules/.bin"
        $"($env.HOME)/.local/bin"
        $env.BIN
    ] | uniq
)

# PATH — macOS-specific
if $OS_NAME == "Darwin" {
    $env.PATH = ($env.PATH | prepend [
        $"($env.HOME)/Library/Python/3.9/bin"
        $"($env.HOMEBREW_ROOT)/bin"
    ] | uniq)

    let rustup_bin = (do { ^brew --prefix rustup } | complete)
    if $rustup_bin.exit_code == 0 {
        $env.PATH = ($env.PATH | prepend $"($rustup_bin.stdout | str trim)/bin")
    }
}

# FZF
$env.FZF_DEFAULT_OPTS = "
 --color=fg:#d1d1d1,bg:#0a0909,hl:#d6c22b
 --color=fg+:#ffffff,bg+:#2a2a2a,hl+:#ebd636
 --color=info:#bf658c,prompt:#d7005f,pointer:#21c8ff
 --color=marker:#40bdd6,spinner:#d7005f,header:#87afaf"
$env.FZF_DEFAULT_COMMAND = "find . -type f ! -path '*/.git/*' ! -path '*/node_modules/*'"

# SKIM
$env.SKIM_DEFAULT_OPTIONS = "--no-mouse --color=empty,query:255,fg:243,matched:226,current:255,current_match:226,spinner:127,info:33,prompt:248,cursor:255,selected:255"
$env.SKIM_DEFAULT_COMMAND = "find . -type f ! -path '*/.git/*' ! -path '*/node_modules/*'"

# Prompt
$env.PROMPT_COMMAND = {||
    let wenv_part = if ($env | get -o WENV | is-not-empty) {
        $"(ansi reset)\(($env.WENV)\)\n"
    } else {
        "\n"
    }
    let git_branch = (do { ^git branch --show-current } | complete)
    let git_part = if $git_branch.exit_code == 0 and ($git_branch.stdout | str trim | is-not-empty) {
        $" \(($git_branch.stdout | str trim)\)"
    } else {
        ""
    }
    let cwd = ($env.PWD | path relative-to $env.HOME | if ($in | is-empty) { $env.PWD } else { $"~/($in)" })

    $"($wenv_part)(ansi { fg: '#d7005f' })grish(ansi { fg: '#bcbcbc' })@(ansi { fg: '#6c6c6c' })(hostname | str trim)(ansi { fg: '#444444' }):(ansi { fg: '#5fafff' })($cwd)(ansi reset)($git_part)\n"
}
$env.PROMPT_INDICATOR = "> "
$env.PROMPT_INDICATOR_VI_INSERT = "> "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "
$env.PROMPT_COMMAND_RIGHT = ""

# Module search paths
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts')
    ($env.HOME | path join 'Library' 'Application Support' 'nushell' 'scripts')
]

# White filenames in ls
$env.LS_COLORS = "di=1;97:ln=97:fi=97:no=97:ex=97:so=97:pi=97:bd=97:cd=97:su=97:sg=97:tw=97:ow=97"
