#!/bin/sh

export DISPLAY=:0

otp_img=/tmp/otp.png
scrot --overwrite --file $otp_img
otp_url=$(zbarimg --raw -q $otp_img)
[[ -z "$otp_url" ]] && { herbe "failed to extract otp qr code from screenshot" ; exit 1 ; }

entry=$(find $HOME/.password-store -name '*.gpg' -printf '%P\n' | sed 's|.gpg||' | sort | dmenu -F -p 'pass entry to add otp to: ')
[[ -z "$entry" ]] && exit 1

if echo "$otp_url" | pass otp append "$entry"; then
    herbe "Successfully added OTP URL for $entry"
else
    herbe "Failed to add OTP URL for $entry"
fi
