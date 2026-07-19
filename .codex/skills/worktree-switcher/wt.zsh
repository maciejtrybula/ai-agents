# Source this file from zsh. Running it as a standalone script will not make
# directory changes persist in the caller.

_wt_list_entries() {
  git worktree list --porcelain | awk '
    /^worktree / {
      path = substr($0, 10)
      branch = ""
      next
    }
    /^branch / {
      branch = $2
      sub(/^refs\/heads\//, "", branch)
      next
    }
    /^$/ {
      if (path != "") {
        printf "%s\034%s\n", path, branch
        path = ""
        branch = ""
      }
    }
    END {
      if (path != "") {
        printf "%s\034%s\n", path, branch
      }
    }
  '
}

wt() {
  emulate -L zsh
  setopt pipefail

  local root common_dir repo_root worktree_dir worktree_path branch_name base_branch current_branch
  local selected_path="" selected_branch="" display selected_display answer
  local dirty_output
  local -a choices force_args
  local -A choice_path choice_branch

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
Usage:
  wt <branch> [-c <base>]
  wt
  wt -d [branch]

Notes:
  - Source this file from zsh; do not execute it directly.
  - Repo-local worktrees are created under .worktrees/.
  - .worktrees/ must be ignored by git before creation.
EOF
    return 0
  fi

  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print -u2 -- "wt: not inside a git repository"
    return 1
  }

  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || {
    print -u2 -- "wt: failed to resolve the shared git directory"
    return 1
  }
  repo_root=${common_dir:h}

  worktree_dir="$repo_root/.worktrees"

  if [[ "$1" == "-d" ]]; then
    if [[ -n "$2" ]]; then
      while IFS=$'\034' read -r selected_path selected_branch; do
        [[ "$selected_branch" == "$2" ]] && break
        selected_path=""
        selected_branch=""
      done < <(_wt_list_entries)
    else
      command -v fzf >/dev/null 2>&1 || {
        print -u2 -- "wt: install fzf or pass a branch name to wt -d"
        return 1
      }

      while IFS=$'\034' read -r selected_path selected_branch; do
        [[ "$selected_path" == "$repo_root" ]] && continue
        display="${selected_branch:-detached} :: $selected_path"
        choices+=("$display")
        choice_path[$display]="$selected_path"
        choice_branch[$display]="$selected_branch"
      done < <(_wt_list_entries)

      (( ${#choices[@]} > 0 )) || {
        print -u2 -- "wt: no linked worktrees to remove"
        return 1
      }

      selected_display=$(printf '%s\n' "${choices[@]}" | fzf --height=40%) || return 1
      selected_path="${choice_path[$selected_display]}"
      selected_branch="${choice_branch[$selected_display]}"
    fi

    [[ -n "$selected_path" ]] || {
      print -u2 -- "wt: worktree not found for '${2:-selection}'"
      return 1
    }

    [[ "$selected_path" != "$repo_root" ]] || {
      print -u2 -- "wt: refusing to remove the primary worktree"
      return 1
    }

    read -r "answer?Remove $selected_path${selected_branch:+ (branch: $selected_branch)}? [y/N] "
    [[ "$answer" =~ '^[Yy]$' ]] || {
      print -- "wt: cancelled"
      return 0
    }

    dirty_output=$(git -C "$selected_path" status --porcelain 2>/dev/null)
    force_args=()
    if [[ -n "$dirty_output" ]]; then
      print -- "wt: worktree has uncommitted changes"
      git -C "$selected_path" status --short
      read -r "answer?Use --force when removing it? [y/N] "
      [[ "$answer" =~ '^[Yy]$' ]] || {
        print -- "wt: cancelled"
        return 0
      }
      force_args=(--force)
    fi

    if ! git worktree remove ${force_args[@]} -- "$selected_path"; then
      print -u2 -- "wt: failed to remove $selected_path"
      return 1
    fi

    if [[ -z "$selected_branch" ]]; then
      print -- "wt: removed $selected_path"
      return 0
    fi

    if git branch -d -- "$selected_branch" >/dev/null 2>&1; then
      print -- "wt: removed $selected_path and deleted branch $selected_branch"
      return 0
    fi

    print -- "wt: branch $selected_branch is not fully merged"
    read -r "answer?Delete branch with -D as well? [y/N] "
    if [[ "$answer" =~ '^[Yy]$' ]]; then
      if git branch -D -- "$selected_branch"; then
        print -- "wt: removed $selected_path and deleted branch $selected_branch"
        return 0
      fi
      print -u2 -- "wt: removed $selected_path but failed to delete branch $selected_branch"
      return 1
    fi

    print -- "wt: removed $selected_path; branch $selected_branch was kept"
    return 0
  fi

  if [[ -n "$1" ]]; then
    branch_name="$1"

    if [[ -n "$2" && "$2" != "-c" ]]; then
      print -u2 -- "wt: expected '-c <base>' after the branch name"
      return 1
    fi

    if [[ "$2" == "-c" ]]; then
      [[ -n "$3" ]] || {
        print -u2 -- "wt: missing base ref after -c"
        return 1
      }
      base_branch="$3"
    else
      current_branch=$(git branch --show-current)
      [[ -n "$current_branch" ]] || {
        print -u2 -- "wt: detached HEAD; pass an explicit base ref with -c"
        return 1
      }
      base_branch="$current_branch"
    fi

    git rev-parse --verify --quiet "$base_branch^{commit}" >/dev/null || {
      print -u2 -- "wt: base ref '$base_branch' does not exist"
      return 1
    }

    git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q .worktrees/ 2>/dev/null || {
      print -u2 -- "wt: add .worktrees/ to .gitignore before creating repo-local worktrees"
      return 1
    }

    mkdir -p "$worktree_dir" || {
      print -u2 -- "wt: failed to create $worktree_dir"
      return 1
    }

    worktree_path="$worktree_dir/$branch_name"

    while IFS=$'\034' read -r selected_path selected_branch; do
      if [[ "$selected_path" == "$worktree_path" ]]; then
        if cd "$worktree_path"; then
          print -- "wt: switched to existing worktree $worktree_path"
          return 0
        fi
        print -u2 -- "wt: worktree exists but could not cd into $worktree_path"
        return 1
      fi
    done < <(_wt_list_entries)

    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git worktree add "$worktree_path" "$branch_name" || return 1
    else
      git worktree add -b "$branch_name" "$worktree_path" "$base_branch" || return 1
    fi

    if cd "$worktree_path"; then
      print -- "wt: created and switched to $worktree_path"
      return 0
    fi

    print -u2 -- "wt: created $worktree_path but could not cd into it"
    return 1
  fi

  command -v fzf >/dev/null 2>&1 || {
    print -u2 -- "wt: install fzf or pass a branch name"
    return 1
  }

  while IFS=$'\034' read -r selected_path selected_branch; do
    display="${selected_branch:-detached} :: $selected_path"
    choices+=("$display")
    choice_path[$display]="$selected_path"
  done < <(_wt_list_entries)

  (( ${#choices[@]} > 0 )) || {
    print -u2 -- "wt: no worktrees available"
    return 1
  }

  selected_display=$(printf '%s\n' "${choices[@]}" | fzf --height=40%) || return 1
  selected_path="${choice_path[$selected_display]}"

  if cd "$selected_path"; then
    print -- "wt: switched to $selected_path"
    return 0
  fi

  print -u2 -- "wt: failed to cd into $selected_path"
  return 1
}
