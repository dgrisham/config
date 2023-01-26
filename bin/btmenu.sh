#!/bin/zsh

export DISPLAY=:0

source $WENV_CFG/wenvs/bluetooth

cmd=$(printf 'connect\ndisconnect\nreconnect' | dmenu -p 'action: ')
[[ -z "$cmd" ]] && exit 1

device=$(echo ${(@k)bt_devices} | tr ' ' '\n' | dmenu -p 'bluetooth device: ')
[[ -z "$device" ]] && exit 1

case $cmd in
    connect)
        bluetooth_connect $device || { herbe "Failed to connect to bluetooth device '$device'" ; exit 1 ; }
        herbe "Connected to $device"
        ;;
    disconnect)
        bluetooth_disconnect $device || { herbe "Failed to disconnect from bluetooth device '$device'" ; exit 1 ; }
        herbe "Disconnected from $device"
        ;;
    reconnect)
        { bluetooth_disconnect $device && bluetooth_connect $device } || { herbe "Failed to reconnect to bluetooth device '$device'" ; exit 1 ; }
        herbe "Reconnected to $device"
        ;;
esac
