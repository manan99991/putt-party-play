#!/bin/bash
# Publishes a file or a folder to the ci-logs branch (artifact downloads are blocked where Claude runs).
# Usage: publish-log.sh <name> <file-or-dir>
set -e
name=$1; src=$2
dir=$(mktemp -d)
git -C "$dir" init -q
git -C "$dir" config user.name ci; git -C "$dir" config user.email ci@handytools
git -C "$dir" checkout -q -b ci-logs
git -C "$dir" fetch -q --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}" ci-logs 2>/dev/null && git -C "$dir" checkout -q FETCH_HEAD -- . 2>/dev/null || true
if [ -d "$src" ]; then rm -rf "$dir/$name"; mkdir -p "$dir/$name"; cp -r "$src"/. "$dir/$name/"
else case "$name" in *-apk|*-aab) cp "$src" "$dir/$name.bin";; *) cp "$src" "$dir/$name.log" 2>/dev/null || echo "(no log file produced)" > "$dir/$name.log";; esac; fi
echo "$GITHUB_SHA $(date -u +%FT%TZ)" > "$dir/$name.sha"
git -C "$dir" add -A; git -C "$dir" commit -qm "$name for $GITHUB_SHA" || true
git -C "$dir" push -q -f "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}" HEAD:ci-logs
