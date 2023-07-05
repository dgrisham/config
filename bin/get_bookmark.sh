#!/bin/sh

url=$(grep -Rv '^#' ~/.local/share/bookmarks | perl -p -e 's|/home/grish/.local/share/bookmarks/(.*?)(?:/bookmarks)?:(.*?)|$1:\t$2|' | sort | column -t -s $'\t' | dmenu -F -i -l 20 | awk '{print $2}')
[[ -z "$url" ]] && exit 1
echo "$url"
