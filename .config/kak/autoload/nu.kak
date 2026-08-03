# === Nushell filetype support for Kakoune ===

provide-module nu %§

# --- Highlighters (region-based) ---
add-highlighter shared/nu regions

# Code region (default)
add-highlighter shared/nu/code default-region group

# Interpolated double-quoted strings: $"..."
add-highlighter shared/nu/interp_double_string region '\$"' '(?<!\\)(?:\\\\)*"' group
add-highlighter shared/nu/interp_double_string/fill fill string
add-highlighter shared/nu/interp_double_string/interpolation regex '\(([^)]*)\)' 1:value

# Interpolated single-quoted strings: $'...'
add-highlighter shared/nu/interp_single_string region "\\$'" "'" group
add-highlighter shared/nu/interp_single_string/fill fill string
add-highlighter shared/nu/interp_single_string/interpolation regex '\(([^)]*)\)' 1:value

# Regular double-quoted strings
add-highlighter shared/nu/double_string region '"' '(?<!\\)(?:\\\\)*"' fill string

# Regular single-quoted strings (no escapes)
add-highlighter shared/nu/single_string region "'" "'" fill string

# Raw strings: r#'...'#
add-highlighter shared/nu/raw_string region "r#'" "'#" fill string

# Comments
add-highlighter shared/nu/comment region '#' '$' fill comment

evaluate-commands %sh{
    keywords="alias break collect const continue def else export extern for
              hide if let loop match module mut overlay return source source-env
              try use where while catch export-env run"

    builtins="abbr all ansi any append ast attr cal cd char chunk-by chunks
              clear columns combinations commandline compact complete config cp
              date debug decode default describe detect difference do drop du
              each echo encode enumerate error every exec exit explain explore
              fill filter find first flatten format from generate get glob grid
              group-by hash headers help hide-env histogram history http idx
              ignore input insert inspect interleave intersect into is-admin
              is-empty is-not-empty is-terminal items job join keybindings kill
              last length let-env lines load-env ls math merge metadata mkdir
              mktemp move mv nu-check nu-highlight open panic par-each parse
              path peek permutations plugin port prepend print ps query random
              reduce reject rename reverse rm roll rotate run-external
              run-internal save schema scope select semver seq shuffle skip
              sleep slice sort sort-by split start stor str sys table take tee
              term timeit to touch transpose tutor ulimit umask uname union
              uniq uniq-by unlet update upsert url values version view watch
              which whoami window with-env wrap zip"

    types="int float bool string list record table closure binary glob
           cell-path duration filesize range datetime nothing any number"

    literal_values="true false null nothing"

    join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }

    printf %s\\n "declare-option str-list nu_static_words $(join "${keywords}" ' ') $(join "${builtins}" ' ') $(join "${types}" ' ') $(join "${literal_values}" ' ')"

    printf %s "
        add-highlighter shared/nu/code/keyword regex (?<![-\w])\b($(join "${keywords}" '|'))\b(?![-\w]) 0:keyword
        add-highlighter shared/nu/code/builtin regex (?<![-\w])\b($(join "${builtins}" '|'))\b(?![-\w]) 0:builtin
        add-highlighter shared/nu/code/type    regex (?<![-\w])\b($(join "${types}" '|'))\b(?![-\w]) 0:type
        add-highlighter shared/nu/code/literal regex (?<![-\w])\b($(join "${literal_values}" '|'))\b(?![-\w]) 0:value
    "
}

# Numbers: integers, floats, hex, binary, octal
add-highlighter shared/nu/code/number regex '\b-?(?:0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|[0-9][0-9_]*(?:\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9_]+)?)\b' 0:value

# Durations and file sizes
add-highlighter shared/nu/code/unit_value regex '\b[0-9][0-9_]*(?:\.[0-9_]+)?\s*(ns|us|ms|sec|min|hr|day|wk|b|kb|mb|gb|tb|pb|kib|mib|gib|tib|pib)\b' 0:value

# Operators
add-highlighter shared/nu/code/operator regex '(\+\+|[!=<>]=?|&&|\|\||[+\-*/]|=>|->|\.\.)' 0:operator
add-highlighter shared/nu/code/pipe regex '(\|)' 0:operator
add-highlighter shared/nu/code/word_operator regex '\b(not|in|and|or|mod|bit-and|bit-or|bit-xor|bit-shl|bit-shr|starts-with|ends-with)\b' 0:operator

# Variables
add-highlighter shared/nu/code/variable regex '\$[\w.]+' 0:variable

# Flags
add-highlighter shared/nu/code/flag regex '\s(-[\w]|--[\w][\w-]*)' 1:attribute

# Range operator
add-highlighter shared/nu/code/range regex '\b[0-9]+\.\.[<=]?[0-9]+\b' 0:value

# Command definition names
add-highlighter shared/nu/code/def_name regex '\b(def)\s+([\w-]+)' 2:function

# Braces/brackets
add-highlighter shared/nu/code/braces regex '[{}\[\]()]' 0:operator

§

# --- Filetype detection ---
hook global BufCreate .*\.nu$ %{
    set-option buffer filetype nu
}

# --- Filetype initialization ---
hook global WinSetOption filetype=nu %{
    require-module nu

    set-option window static_words %opt{nu_static_words}
    set-option window comment_line '#'
    set-option window tabstop 2
    set-option window indentwidth 2

    hook window ModeChange pop:insert:.* -group nu-trim-indent %{ try %{ execute-keys -draft xs^\h+$<ret>d } }
    hook window InsertChar \n -group nu-indent nu-indent-on-new-line

    set-option window lintcmd 'nu-check'
    hook window -group nu-lint BufWritePost .* lint

    hook -once -always window WinSetOption filetype=.* %{
        remove-hooks window nu-.+
        unset-option window lintcmd
    }
}

hook -group nu-highlight global WinSetOption filetype=nu %{
    require-module nu
    add-highlighter window/nu ref nu
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/nu }
}

# --- Indentation ---
define-command -hidden nu-indent-on-new-line %~
    evaluate-commands -draft -itersel %=
        try %{ execute-keys -draft <semicolon>K<a-&> }
        try %{ execute-keys -draft kx s \h+$ <ret>d }
        try %< execute-keys -draft [c[({[\[]],[)}\]] <ret> <a-k> \A[({[\[][^\n]*\n[^\n]*\n?\z <ret> j<a-gt> >
        try %[ execute-keys -draft x <a-k> ^\h*[}\])] <ret> gh / [}\])] <ret> m <a-S> 1<a-&> ]
    =
~
