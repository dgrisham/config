#!/bin/sh

pass_type=$(printf "password\notp\nusername" | dmenu -p 'type: ')

case $pass_type in
    password)
        passmenu --type
        ;;
    otp)
        entry=$(find $HOME/.password-store -name '*.gpg' -printf '%P\n' | sed 's|.gpg||' | sort | dmenu -F)
        [[ -z "$entry" ]] && exit 1
        otp_pass=$(pass otp show "$entry")
        [[ -z "$otp_pass" ]] && { DISPLAY=:0 notify-send "otp entry not found" "$entry" ; exit 1 ; }
        xdotool type "$otp_pass"
        ;;
    username)
        entry=$(find $HOME/.password-store -name '*.gpg' -printf '%P\n' | sed 's|.gpg||' | sort | dmenu -F)
        [[ -z "$entry" ]] && exit 1
        username=$(pass show "$entry" | grep -oP '\K^login: \K.*?$')
        [[ -z "$username" ]] && { DISPLAY=:0 notify-send "username not found" "$entry" ; exit 1 ; }
        xdotool type "$username"
        ;;
esac
