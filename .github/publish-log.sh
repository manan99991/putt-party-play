#!/bin/bash
# Publishes a file or a folder to the ci-logs branch (artifact downloads are blocked where Claude runs).
# Usage: publish-log.sh <name> <file-or-dir>
# Robust against concurrent runs: re-bases onto the live ci-logs tip before every push attempt,
# so the commit is always a fast-forward child of remote HEAD.
set -e
name=$1; src=$2
dir=$(mktemp -d)
REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
git -C "$dir" init -q
git -C "$dir" config user.name ci; git -C "$dir" config user.email ci@handytools

stage() {
  if [ -d "$src" ]; then rm -rf "$dir/$name"; mkdir -p "$dir/$name"; cp -r "$src"/. "$dir/$name/"
  else case "$name" in
    *-apk|*-aab) cp "$src" "$dir/$name.bin";;
    *) cp "$src" "$dir/$name.log" 2>/dev/null || echo "(no log file produced)" > "$dir/$name.log";;
  esac; fi
  echo "$GITHUB_SHA $(date -u +%FT%TZ)" > "$dir/$name.sha"
  git -C "$dir" add -A
  git -C "$dir" commit -qm "$name for $GITHUB_SHA" || true
}

for attempt in 1 2 3 4 5 6 7 8; do
  if git -C "$dir" fetch -q "$REMOTE" ci-logs 2>/dev/null; then
    git -C "$dir" checkout -q -B ci-logs FETCH_HEAD
  else
    git -C "$dir" checkout -q -B ci-logs
  fi
  stage
  git -C "$dir" push -q "$REMOTE" HEAD:ci-logs && exit 0
  echo "push attempt $attempt failed; re-syncing with ci-logs tip"; sleep $((attempt*5))
done
exit 1
