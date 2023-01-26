#!/bin/sh

export DISPLAY=:0

device=$(pactl list cards short | grep -oP 'bluez_card\.[\w]+')
[[ -z "$device" ]] && { herbe "Failed to find active bluez card" ; exit 1 ; }

profile=$(pactl --format=json list cards | jq -r '.[] | select(.name=="'$device'") | .profiles | keys[]' | dmenu -p 'profile: ')
[[ -z "$profile" ]] && exit 1

pactl set-card-profile $device $profile || { herbe "Failed to set profile to $profile for $device" ; exit 1 ; }
