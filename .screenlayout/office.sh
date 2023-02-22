#!/bin/zsh

screens=("${(@f)$(xrandr | grep -oP '^(DP-[0-9]-[0-9])(?= connected)')}")

xrandr --newmode "2560x1440_50.00"  256.25  2560 2736 3008 3456  1440 1443 1448 1484 -hsync +vsync
xrandr --addmode "${screens[1]}" 2560x1440_50.00
xrandr --addmode "${screens[2]}" 2560x1440_50.00
xrandr --output eDP-1 --primary --mode 2256x1504   --pos 0x1440 --rotate normal \
       --output $screens[1] --mode 2560x1440_50.00 --pos 2565x0 --rotate normal \
       --output $screens[2] --mode 2560x1440_50.00 --pos 0x0    --rotate normal \
       --output DP-1 --off                                                      \
       --output DP-2 --off                                                      \
       --output DP-3 --off                                                      \
       --output DP-4 --off
