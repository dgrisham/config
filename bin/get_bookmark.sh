#!/bin/sh

[[ "$1" == 'urls_only' ]] && urls_only=true || urls_only=false

url=''
if $urls_only; then
    url=$(grep -PRv '(^#|# login:)' ~/.local/share/bookmarks --exclude-dir=.git | perl -p -e 's|/home/grish/.local/share/bookmarks/(.*?)(?:/bookmarks)?:(.*?)|$1:\t$2|' | sort | column -t -s $'\t' | dmenu -F -i -l 20 | awk '{print $2}')
else
    url=$(grep -Rv '^#' ~/.local/share/bookmarks --exclude-dir=.git | perl -p -e 's|/home/grish/.local/share/bookmarks/(.*?)(?:/bookmarks)?:(.*?)|$1:\t$2|' | sort | column -t -s $'\t' | dmenu -F -i -l 20 | awk '{print $2}')
fi

[[ -z "$url" ]] && exit 1
echo "$url"
