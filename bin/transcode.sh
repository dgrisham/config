#!/bin/zsh

mkdir -p aac
for file in *.flac; do
    ffmpeg -i "$file" -vn -c:a aac -b:a 320k "aac/${file%.flac}.m4a"
done
