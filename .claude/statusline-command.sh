#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"

current_dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')"

if [[ -z "$current_dir" ]]; then
  exit 0
fi

basename_dir="$(basename "$current_dir")"
git_branch="$(git -C "$current_dir" symbolic-ref --short HEAD 2>/dev/null || true)"
git_dirty=""

if [[ -n "$git_branch" ]] && git -C "$current_dir" status --porcelain 2>/dev/null | grep -q .; then
  git_dirty=" *"
fi

if [[ -n "$git_branch" ]]; then
  printf 'cloud %s [%s]%s' "$basename_dir" "$git_branch" "$git_dirty"
else
  printf 'cloud %s' "$basename_dir"
fi
