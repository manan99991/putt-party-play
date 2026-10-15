#!/bin/bash
# Publishes a build log to the ci-logs branch so it can be read via git (artifact downloads are
# blocked from where Claude runs). Usage: publish-log.sh <name> <logfile>
set -e
name=$1; log=$2
dir=$(mktemp -d)
git -C "$dir" init -q
git -C "$dir" config user.name ci; git -C "$dir" config user.email ci@handytools
git -C "$dir" checkout -q -b ci-logs
git -C "$dir" fetch -q --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}" ci-logs 2>/dev/null && git -C "$dir" checkout -q FETCH_HEAD -- . 2>/dev/null || true
cp "$log" "$dir/$name.log" 2>/dev/null || echo "(no log file produced)" > "$dir/$name.log"
echo "$GITHUB_SHA $(date -u +%FT%TZ)" > "$dir/$name.sha"
git -C "$dir" add -A; git -C "$dir" commit -qm "$name log for $GITHUB_SHA" || true
git -C "$dir" push -q -f "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}" HEAD:ci-logs
