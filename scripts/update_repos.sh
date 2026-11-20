#!/usr/bin/env bash

branch_exists_locally() {
  local repo_path="$1"
  local branch="$2"

  git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch"
}


update_repos() {
  header "Update Repositories"

  local change_branch=false
  if ask_yn "Change branches?" "n"; then
    change_branch=true
  fi

  local branches=()
  if $change_branch; then
    for i in "${!REPOS[@]}"; do
      branches+=("$(ask_input "Branch for ${REPOS[$i]}" "${DEFAULT_BRANCHES[$i]}")")
    done
  fi

  local i repo repo_path branch
  for i in "${!REPOS[@]}"; do
    repo="${REPOS[$i]}"
    repo_path="${REPO_DIRS[$i]}"

    if [[ ! -d "$repo_path/.git" ]]; then
      info "Cloning $repo..."
      git clone "${REPO_URLS[$i]}" "$repo_path" || return 1
      # continue
    fi

    if $change_branch; then
      info "Checking out branch for $repo..."
      branch="${branches[$i]}"
      if branch_exists_locally "$repo_path" "$branch"; then
        # info "Switching $repo to branch $branch..."
        git -C "$repo_path" checkout "$branch" || return 1
        git -C "$repo_path" pull --ff-only origin "$branch" || return 1
      else
        # info "Branch $branch does not exist locally for $repo.  Attempting to create it from origin/$branch..."
        git -C "$repo_path" fetch --all || return 1
        git -C "$repo_path" checkout -b "$branch" "origin/$branch" || return 1
      fi
    fi
  done
}
