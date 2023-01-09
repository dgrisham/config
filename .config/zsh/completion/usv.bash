# bash complete for runit/sv user services
_usv() {
    # local cur prev words cword commands
    local word="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"


    # _init_completion || return

    local commands='up down enable disable status once pause cont hup alarm interrupt 1 2 term kill exit start stop restart shutdown force-stop force-reload force-restart force-shutdown'

    case $prev in
        -w)
            return
            ;;
        -* | __usv)
            COMPREPLY=( $(compgen -W "${commands}" -- ${word}) )
            return
            ;;
        'enable')
            find $XDG_CONFIG_HOME/sv -type d -maxdepth 1 -printf '%P\n'
            ;;
        *)
            find $XDG_CONFIG_HOME/sv/enabled -type l -maxdepth 1 -printf '%P\n'
            return
            ;;
    esac
}
complete -F _usv __usv
