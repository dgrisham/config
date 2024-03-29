#!/bin/sh

export DISPLAY=:0
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"

selection="$(xclip -o -selection primary)"
[[ -z "$selection" ]] && selection="$(xclip -selection c -o)"
[[ -z "$selection" ]] && { herbe "Selection is empty" ; exit 1 ; }

bookmark="$(echo "$selection" | dmenu -e -u -p 'bookmark: ')"
[[ -z "$bookmark" ]] && exit 1

max_length=75
bookmark_display="${bookmark:0:$max_length}"
((${#bookmark} > max_length)) && bookmark_display="${bookmark_display}..."
directory=$(find $data_dir/bookmarks -mindepth 1 -type d -not -path '*.git*' -printf '%P\n' | dmenu -l 10 -p "bookmark '${bookmark_display}' in: ")
[[ -z "$directory" ]] && exit 1
bookmarks_dir=${data_dir}/bookmarks/${directory}

tags="$(printf '' | dmenu -u -p 'optional tags: ')"
[ $? -eq 0 ] || exit 1

mkdir -p "$bookmarks_dir"

bookmark_file="${bookmarks_dir}/bookmarks"
touch "$bookmark_file"

if grep -q "^$bookmark"'$\|'"$bookmark " "$bookmark_file"; then
    herbe "Already bookmarked in '$directory'"
else
    echo "$bookmark${tags:+ # $tags}" >>"$bookmark_file"
    herbe "Successfully added bookmark to '$directory': $bookmark_display"
    cd $data_dir/bookmarks
    git add $directory && git commit -m "adding $bookmark" && git push origin master
fi
