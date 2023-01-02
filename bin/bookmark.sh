#!/bin/sh

export DISPLAY=:0

snippets_file="$HOME/.local/share/snippets"

bookmark="$(xclip -o)"
[[ -z "$bookmark" ]] && bookmark="$(xclip -selection c -o)"
[[ -z "$bookmark" ]] && { herbe "Selection is empty" ; return 1 ; }

if grep -q "^$bookmark$" $snippets_file; then
    herbe "Already bookmarked:" "$bookmark"
else
    echo "$bookmark" >>"$snippets_file"
    herbe "Successfully added bookmark to $snippets_file:" "$bookmark"
fi
