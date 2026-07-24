#!/bin/sh

xrandr --output HDMI-0 --off --output DP-2 --off
xrandr --output DP-2 --mode 2560x1440 --rate 99.95 --output HDMI-0 --mode 2560x1440 --rate 144.00 --right-of DP-2
