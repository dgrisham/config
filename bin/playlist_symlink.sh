#!/bin/zsh

[[ -z "$1" ]] && return 1

local pl_name=$1
local pl_file=$XDG_CONFIG_HOME/mpd/playlists/$pl_name.m3u
local pl_dir=$MUSIC/playlists/$pl_name

echo $pl_dir

[[ ! -f "$pl_file" ]] && return 1
rm -rf $pl_dir
mkdir $pl_dir

local i=1
while read song; do
    local song_file=$(basename $song)
    local pl_entry="$(printf '%03d' $i)-${song_file#*-}"
    ln $MUSIC/library/$song $pl_dir/$pl_entry
    echo $pl_name/$pl_entry >>$pl_dir/$pl_name.m3u
    ((++i))
done <$pl_file
