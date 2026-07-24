#!/bin/zsh

pass_type=$(printf "password\notp\nusername\ngenerate" | dmenu -p 'type: ')

case $pass_type in
    password)
        passmenu --type
        ;;
    otp)
        entry=$(find $HOME/.password-store -name '*.gpg' -printf '%P\n' | sed 's|.gpg||' | sort | dmenu -F)
        [[ -z "$entry" ]] && exit 1
        otp_pass=$(pass otp show "$entry")
        [[ -z "$otp_pass" ]] && { DISPLAY=:0 herbe "otp entry not found: '$entry'" ; exit 1 ; }
        xdotool type "$otp_pass"
        ;;
    username)
        entry=$(find $HOME/.password-store -name '*.gpg' -printf '%P\n' | sed 's|.gpg||' | sort | dmenu -F)
        [[ -z "$entry" ]] && exit 1
        login=$(pass show "$entry" | grep -oP '\K^login: \K.*?$')
        [[ -z "$login" ]] && { DISPLAY=:0 herbe "username not found for entry '$entry'" ; exit 1 ; }
        xdotool type "$login"
        ;;
    generate)
        prefix=$HOME/.password-store
        password_entries=( "$prefix"/**/*.gpg )
        password_entries=( "${password_entries[@]#"$prefix"/}" )
        password_entries=( "${password_entries[@]%.gpg}" )

        entry=$(printf '%s\n' "${password_entries[@]}" | dmenu "$@")
        [[ -n $entry ]] || exit
        for pass_entry in $password_entries; do
            if [ $pass_entry = $entry ]; then
                login=$(pass show "$entry" | grep -oP '\K^login: \K.*?$')
                password_complexity=$(pass show "$entry" | grep -oP '\K^complexity: \K.*?$')
                password_length=$(expr length "$(pass show $entry | head -n1)")
                break
            fi
        done

        if [[ -z "$login" ]]; then
            login=$(printf '' | dmenu -p 'login (default: dmgrisham@gmail.com): ')
            [[ -z "$login" ]] && login='dmgrisham@gmail.com'
        fi

        if [[ -z "$password_complexity" ]]; then
            password_complexity=$(printf 'words\nsimple\ncomplex' | dmenu -p 'password type: ')
            [[ -z "$password_complexity" ]] && exit 1
        fi

        until [[ "$password_length" =~ ^[0-9]+$ ]]; do
            password_length=$(printf '' | dmenu -p 'password length (default: 10): ')
            [[ -z "$password_length" ]] && password_length=10
        done

        user_is_satisfied='no'
        until [[ $user_is_satisfied = 'yes' ]]; do
            xclip -selection clipboard </dev/null
            case $password_complexity in
                words)
                    password=$(diceware -n 3 -d '-')'1!'
                ;;
                simple)
                    password=$(tr -dc A-HJ-NP-Za-km-z0-9 </dev/urandom | head -c $password_length)
                ;;
                complex)
                    password=$(tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c $password_length)
                ;;
            esac

            user_is_satisfied=$(printf 'yes\nno' | dmenu -p "accepted generated password '$password'?") || exit 1
        done

        pass insert --multiline $entry <<EOF
$password
login: $login
complexity: $password_complexity
EOF

        set -e
        pass --clip $entry
        DISPLAY=:0 herbe "newly generated password for '$entry' copied to clipboard"
        ;;
esac
