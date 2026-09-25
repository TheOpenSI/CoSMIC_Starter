#!/usr/bin/env bash
# Clone/pull the three repos, optionally switching branches.

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
      git clone "${REPO_URLS[$i]}" "$repo_path"
      continue
    fi

    if $change_branch; then
      branch="${branches[$i]}"
      git -C "$repo_path" fetch --all --prune

      if git -C "$repo_path" checkout "$branch" 2>/dev/null; then
        git -C "$repo_path" branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
      else
        git -C "$repo_path" checkout -b "$branch" --track "origin/$branch"
      fi

      if git -C "$repo_path" pull --ff-only origin "$branch" 2>/dev/null; then
        success "$repo → $branch"
      else
        warn "$repo → $branch (could not fast-forward)"
      fi
    else
      info "Pulling $repo..."
      git -C "$repo_path" pull || warn "$repo: pull failed (check for local changes)"
    fi
  done
}
