#!/bin/zsh

screens=("${(@f)$(xrandr | grep -oP '^(DP-[0-9]-[0-9])(?= connected)')}")

xrandr --output eDP-1 --primary --mode 2256x1504   --pos 0x1440 --rotate normal \
       --output $screens[1] --off \
       --output $screens[2] --off \
       --output DP-1 --off        \
       --output DP-2 --off        \
       --output DP-3 --off        \
       --output DP-4 --off

