#!/usr/bin/env bash
# CoSMIC project launcher

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[CoSMIC]${NC} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${NC} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

ask_yn() {
  local prompt="$1" default="${2:-y}" label answer
  [[ "$default" == "y" ]] && label="${GREEN}Y${NC}/n" || label="y/${GREEN}N${NC}"
  while true; do
    read -rp "$(echo -e "${YELLOW}?${NC} $prompt [$label]: ")" answer
    answer="${answer:-$default}"
    case "${answer,,}" in y|yes) return 0 ;; n|no) return 1 ;; esac
    warn "Please answer y or n."
  done
}

ask_input() {
  local prompt="$1" default="$2" answer
  read -rp "$(echo -e "${YELLOW}?${NC} $prompt [${BOLD}$default${NC}]: ")" answer
  echo "${answer:-$default}"
}

ask_choice() {
  local prompt="$1" default="$2"; shift 2
  local options=("$@") i answer
  echo -e "${YELLOW}?${NC} $prompt" >&2
  for i in "${!options[@]}"; do echo -e "  $((i+1))) ${options[$i]}" >&2; done
  while true; do
    read -rp "$(echo -e "  Enter choice [${BOLD}$default${NC}]: ")" answer
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
      echo "$answer"; return
    fi
    warn "Enter a number between 1 and ${#options[@]}." >&2
  done
}

#  Docker compose detection 
if docker compose version &>/dev/null; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  error "No compose command found.  sudo apt-get install docker-compose-plugin"
  exit 1
fi

#  Paths 
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$BASE_DIR/CoSMIC_DB"
COSMIC_DIR="$BASE_DIR/CoSMIC"
UI_DIR="$BASE_DIR/CoSMIC_UI"

REPOS=("CoSMIC" "CoSMIC_DB" "CoSMIC_UI")
REPO_URLS=(
  "https://github.com/TheOpenSI/CoSMIC.git"
  "https://github.com/TheOpenSI/CoSMIC_DB.git"
  "https://github.com/TheOpenSI/CoSMIC_UI.git"
)
DEFAULT_BRANCHES=("Development" "dev" "development")

#  Banner 
echo ""
echo -e "${BLUE}${BOLD}\
 ╔════════════════════════════════════════════════════╗\n\
 ║         CoSMIC Project Launcher                    ║\n\
 ╚════════════════════════════════════════════════════╝${NC}"
echo -e "  Base: ${CYAN}$BASE_DIR${NC}"
echo ""

#  Main menu 
MENU=$(ask_choice "What would you like to do?" "1" \
  "Start  — pull repos, checkout branch, bring up all stacks" \
  "Stop   — bring down all stacks" \
  "Logs   — tail logs for a specific service")

if [[ "$MENU" == "2" ]]; then
  header "Stopping all stacks"
  for dir in "$UI_DIR" "$COSMIC_DIR" "$DB_DIR"; do
    [[ -f "$dir/compose.yaml" ]] && $DC -f "$dir/compose.yaml" down || true
  done
  success "Done."; exit 0
fi

if [[ "$MENU" == "3" ]]; then
  header "Logs"
  SVC=$(ask_choice "Which service?" "1" \
    "CoSMIC backend" "CoSMIC_DB postgres" "CoSMIC_DB fastapi" "CoSMIC_UI")
  case "$SVC" in
    1) $DC -f "$COSMIC_DIR/compose.yaml" logs -f ;;
    2) $DC -f "$DB_DIR/compose.yaml"     logs -f database ;;
    3) $DC -f "$DB_DIR/compose.yaml"     logs -f backend ;;
    4) $DC -f "$UI_DIR/compose.yaml"     logs -f ;;
  esac
  exit 0
fi

#  Step 1: Clone repos 
header "Step 1 — Repositories"
for i in "${!REPOS[@]}"; do
  repo_path="$BASE_DIR/${REPOS[$i]}"
  if [[ -d "$repo_path/.git" ]]; then
    success "${REPOS[$i]} already cloned."
  else
    info "Cloning ${REPOS[$i]}..."
    git clone "${REPO_URLS[$i]}" "$repo_path"
  fi
done

#  Step 2: Branch selection 
header "Step 2 — Branch Selection"
BRANCHES=()
for i in "${!REPOS[@]}"; do
  BRANCHES+=("$(ask_input "Branch for ${REPOS[$i]}" "${DEFAULT_BRANCHES[$i]}")")
done

#  Step 3: Checkout & pull 
header "Step 3 — Checkout & Pull"
for i in "${!REPOS[@]}"; do
  repo="${REPOS[$i]}"
  branch="${BRANCHES[$i]}"
  repo_path="$BASE_DIR/$repo"

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
done

#  Step 4: Docker options 
header "Step 4 — Docker Options"
BUILD_FLAG=""; PULL_FLAG=""
ask_yn "Pull latest images (--pull always)?" "n" && PULL_FLAG="--pull always"
ask_yn "Build images from source (--build)?" "n"  && BUILD_FLAG="--build"
if ask_yn "docker system prune -af --volumes? ${RED}Removes ALL unused data.${NC}" "n"; then
  docker system prune -af --volumes
fi

#  Step 5: CoSMIC_DB config 
header "Step 5 — CoSMIC_DB Config"
mkdir -p "$DB_DIR/docker/secrets" "$DB_DIR/docker/configs" "$DB_DIR/cores"
for src in "$DB_DIR/examples/"*; do
  filename="$(basename "$src")"
  # strip .example from name, route to correct subfolder
  case "$filename" in
    postgres_*.example.txt) dest="$DB_DIR/docker/secrets/${filename//.example/}" ;;
    pgadmin_*.example.txt)  dest="$DB_DIR/docker/secrets/${filename//.example/}" ;;
    pgadmin_*.example.json) dest="$DB_DIR/docker/configs/${filename//.example/}"  ;;
    cosmic_*.example.env)   dest="$DB_DIR/cores/${filename//.example/}"           ;;
    *) continue ;;
  esac
  if [[ -f "$dest" ]]; then
    success "Already exists: $(basename "$dest")"
  else
    cp "$src" "$dest"
    success "Copied → $(basename "$dest")"
  fi
done

#  Step 6: CoSMIC .env 
header "Step 6 — CoSMIC Config"
if [[ -f "$COSMIC_DIR/.env" ]]; then
  success "CoSMIC .env already exists."
else
  OLLAMA_NAME=$(ask_input "OLLAMA_SERVICE_NAME (unique name for your Ollama container)" "ollama")
  printf 'OPENAI_API_KEY=""\nOLLAMA_SERVICE_NAME="%s"\n' "$OLLAMA_NAME" > "$COSMIC_DIR/.env"
  success "CoSMIC .env created."
fi

#  Step 7: CoSMIC_UI .env 
header "Step 7 — CoSMIC_UI Config"
if [[ -f "$UI_DIR/.env" ]]; then
  success "CoSMIC_UI .env already exists."
else
  cp "$UI_DIR/.env_example" "$UI_DIR/.env"
  success "CoSMIC_UI .env created from .env_example."
fi

#  Step 8: Start CoSMIC_DB 
header "Step 8 — CoSMIC_DB"
$DC -f "$DB_DIR/compose.yaml" up -d $BUILD_FLAG || { error "CoSMIC_DB failed to start"; exit 1; }

info "Waiting for postgres (up to 90s)..."
for (( i=0; i<30; i++ )); do
  docker exec cosmic-postgres pg_isready -q 2>/dev/null && break
  echo -n "."; sleep 3
done
echo ""; success "Postgres ready."

#  Step 7: Start CoSMIC 
header "Step 9 — CoSMIC"
$DC -f "$COSMIC_DIR/compose.yaml" up -d $BUILD_FLAG $PULL_FLAG || { error "CoSMIC failed to start"; exit 1; }
success "CoSMIC is up."

#  Step 8: Start CoSMIC_UI 
header "Step 10 — CoSMIC_UI"
$DC -f "$UI_DIR/compose.yaml" up -d $BUILD_FLAG || { error "CoSMIC_UI failed to start"; exit 1; }
success "CoSMIC_UI is up."

#  Done 
header "All services started!"
echo -e "  ${GREEN}CoSMIC API${NC}      →  http://localhost:3000"
echo -e "  ${GREEN}CoSMIC UI${NC}       →  http://localhost:5173"
echo -e "  ${GREEN}FastAPI${NC}         →  http://localhost:8000"
echo -e "  ${GREEN}PgAdmin${NC}         →  http://localhost:5050"
echo ""

ask_yn "Tail CoSMIC logs? (Ctrl+C to stop)" "y" \
  && $DC -f "$COSMIC_DIR/compose.yaml" logs -f

