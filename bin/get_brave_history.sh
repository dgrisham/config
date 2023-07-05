#!/bin/sh

url=$(sqlite3 -separator $'\t' 'file:'"$HOME/.config/BraveSoftware/Brave-Browser/Default/History"'?immutable=1' "$(cat <<EOF
    select SUBSTR(title,1,150),url from urls order by last_visit_time desc limit 10000;
EOF
)" | column --output-separator $'\t' -t -s $'\t' | dmenu -F -i -l 25 | awk -F'\t' '{print $(NF)}')
[[ -z "$url" ]] && exit 1
echo "$url"
