#!/usr/bin/env bash
# CoSMIC project launcher — single entry point for all three repos

set -uo pipefail

#  Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

#  Helpers
info()    { echo -e "${CYAN}${BOLD}[CoSMIC]${NC} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${NC} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${NC} $*" >&2; }
divider() { echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
header()  { divider; echo -e "${BLUE}${BOLD}  $*${NC}"; divider; }

# ── Detect docker compose command ─────────────────────────────────────────────
DC=""
if docker compose version &>/dev/null; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  echo -e "${RED}${BOLD}[✗]${NC} No compose command found. Install the plugin:" >&2
  echo -e "    sudo apt-get install docker-compose-plugin" >&2
  exit 1
fi
success "Using: $DC  ($(${DC} version 2>/dev/null | head -1))"

ask_yn() {
  local prompt="$1" default="${2:-y}" yn_label answer
  [[ "$default" == "y" ]] && yn_label="${GREEN}Y${NC}/n" || yn_label="y/${GREEN}N${NC}"
  while true; do
    read -rp "$(echo -e "${YELLOW}?${NC} $prompt [$yn_label]: ")" answer
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
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
  for i in "${!options[@]}"; do
    echo -e "  $((i+1))) ${options[$i]}" >&2
  done
  while true; do
    read -rp "$(echo -e "  Enter choice [${BOLD}$default${NC}]: ")" answer
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
      echo "$answer"; return
    fi
    echo -e "${YELLOW}${BOLD}[!]${NC} Enter a number between 1 and ${#options[@]}." >&2
  done
}

#  Config 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

REPOS=("CoSMIC" "CoSMIC_DB" "CoSMIC_UI")
REPO_URLS=(
  "https://github.com/TheOpenSI/CoSMIC.git"
  "https://github.com/TheOpenSI/CoSMIC_DB.git"
  "https://github.com/TheOpenSI/CoSMIC_UI.git"
)
DEFAULT_BRANCHES=("Development" "dev" "development")

COSMIC_DB_COMPOSE="$BASE_DIR/CoSMIC_DB/compose.yaml"
COSMIC_COMPOSE="$BASE_DIR/CoSMIC/docker-compose.yaml"
COSMIC_UI_COMPOSE="$BASE_DIR/CoSMIC_UI/docker-compose.dev.yml"

#  Main menu
#  This may look odd becuase of formatting 
echo ""
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║         CoSMIC Project Launcher                    ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
echo -e "  Base: ${CYAN}$BASE_DIR${NC}"
echo ""

MENU_CHOICE=$(ask_choice "What would you like to do?" "1" \
  "Start  — pull repos, checkout branch, bring up all stacks" \
  "Stop   — bring down all stacks" \
  "Logs   — tail logs for a specific service")

case "$MENU_CHOICE" in
  2) #  Stop 
    header "Stopping all CoSMIC stacks"
    for compose_file in "$COSMIC_UI_COMPOSE" "$COSMIC_COMPOSE" "$COSMIC_DB_COMPOSE"; do
      if [[ -f "$compose_file" ]]; then
        info "Bringing down: $(basename "$(dirname "$compose_file")")"
        $DC -f "$compose_file" down || warn "Could not stop $(basename "$compose_file")"
      fi
    done
    success "All stacks stopped."
    exit 0
    ;;

  3) #  Logs 
    header "Service Logs"
    LOG_SERVICE=$(ask_choice "Which service?" "1" \
      "cosmic  (CoSMIC main)" \
      "database (CoSMIC_DB postgres)" \
      "backend  (CoSMIC_DB FastAPI)" \
      "web      (CoSMIC_UI)")
    case "$LOG_SERVICE" in
      1) $DC -f "$COSMIC_COMPOSE"    logs -f cosmic   ;;
      2) $DC -f "$COSMIC_DB_COMPOSE" logs -f database ;;
      3) $DC -f "$COSMIC_DB_COMPOSE" logs -f backend  ;;
      4) $DC -f "$COSMIC_UI_COMPOSE" logs -f web      ;;
    esac
    exit 0
    ;;
esac

#  Step 1: Clone repos if missing 
header "Step 1 — Repositories"

for i in "${!REPOS[@]}"; do
  repo="${REPOS[$i]}"
  url="${REPO_URLS[$i]}"
  repo_path="$BASE_DIR/$repo"

  if [[ -d "$repo_path/.git" ]]; then
    success "$repo already cloned."
  else
    info "Cloning $repo from $url ..."
    git clone "$url" "$repo_path"
    success "$repo cloned."
  fi
done

#  Step 2: Branch selection 
header "Step 2 — Branch Selection"

BRANCHES=()
for i in "${!REPOS[@]}"; do
  branch=$(ask_input "Branch for ${REPOS[$i]}" "${DEFAULT_BRANCHES[$i]}")
  BRANCHES+=("$branch")
done

#  Step 3: Checkout and pull 
header "Step 3 — Checkout & Pull"

for i in "${!REPOS[@]}"; do
  repo="${REPOS[$i]}"
  branch="${BRANCHES[$i]}"
  repo_path="$BASE_DIR/$repo"

  info "[$repo] Fetching..."
  git -C "$repo_path" fetch --all --prune

  info "[$repo] Checking out '$branch'..."
  if git -C "$repo_path" checkout "$branch" 2>/dev/null; then
    git -C "$repo_path" branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
  else
    git -C "$repo_path" checkout -b "$branch" --track "origin/$branch"
  fi

  if git -C "$repo_path" pull --ff-only origin "$branch" 2>/dev/null; then
    success "$repo → $branch (pulled)"
  else
    warn "$repo → $branch (could not fast-forward; you may have local commits)"
  fi
done

#  Step 4: Docker options 
header "Step 4 — Docker Options"

DO_PRUNE=false
DO_BUILD=false
DO_PULL=false
BUILD_FLAG=""
PULL_FLAG=""

if ask_yn "Pull latest images before starting?" "n"; then
  DO_PULL=true
  PULL_FLAG="--pull always"
fi

if ask_yn "Build images from source (--build)?" "n"; then
  DO_BUILD=true
  BUILD_FLAG="--build"
fi

if ask_yn "Run 'docker system prune -af'? ${RED}Removes ALL unused containers, images & volumes.${NC}" "n"; then
  DO_PRUNE=true
fi

#  Step 5: Pre-flight 
header "Step 5 — Pre-flight"

if $DO_PRUNE; then
  warn "Running docker system prune -af --volumes ..."
  docker system prune -af --volumes
  success "Prune complete."
fi

# CoSMIC's docker-compose.yaml requires shared_mount as an external volume
if ! docker volume inspect shared_mount &>/dev/null; then
  info "Creating external Docker volume 'shared_mount' (required by CoSMIC)..."
  docker volume create shared_mount
  success "Volume 'shared_mount' created."
else
  success "External volume 'shared_mount' already exists."
fi

#  Step 6: CoSMIC_DB config setup
header "Step 6 — CoSMIC_DB Config Setup"

DB_DIR="$BASE_DIR/CoSMIC_DB"
EXAMPLES_DIR="$DB_DIR/examples"

mkdir -p "$DB_DIR/docker/secrets" "$DB_DIR/docker/configs" "$DB_DIR/cores"

# Map: source example file → destination (relative to CoSMIC_DB)
declare -A EXAMPLE_MAP=(
  ["postgres_usr.example.txt"]="docker/secrets/postgres_usr.txt"
  ["postgres_db.example.txt"]="docker/secrets/postgres_db.txt"
  ["postgres_pwd.example.txt"]="docker/secrets/postgres_pwd.txt"
  ["pgadmin_pwd.example.txt"]="docker/secrets/pgadmin_pwd.txt"
  ["pgadmin_svr.example.json"]="docker/configs/pgadmin_svr.json"
  ["cosmic_cfg.example.env"]="cores/cosmic_cfg.env"
)

for example in "${!EXAMPLE_MAP[@]}"; do
  src="$EXAMPLES_DIR/$example"
  dest="$DB_DIR/${EXAMPLE_MAP[$example]}"
  if [[ -f "$dest" ]]; then
    success "Already exists: ${EXAMPLE_MAP[$example]}"
  else
    cp "$src" "$dest"
    success "Copied: $example → ${EXAMPLE_MAP[$example]}"
  fi
done

warn "Default demo credentials in use. Edit files in CoSMIC_DB/docker/secrets/ to change them."

#  Step 7: Start CoSMIC_DB
header "Step 7 — CoSMIC_DB (Database layer)"

info "Starting database service first..."
$DC -f "$COSMIC_DB_COMPOSE" up -d $BUILD_FLAG database

info "Waiting for postgres to be ready (up to 90s)..."
TIMEOUT=90; ELAPSED=0
until docker exec cosmic-postgres pg_isready -q 2>/dev/null; do
  sleep 3; ELAPSED=$((ELAPSED + 3))
  echo -n "."
  if (( ELAPSED >= TIMEOUT )); then
    echo ""
    warn "Postgres did not become ready within ${TIMEOUT}s — continuing anyway."
    break
  fi
done
echo ""
success "Postgres is ready."

info "Starting remaining CoSMIC_DB services (backend + pgadmin)..."
$DC -f "$COSMIC_DB_COMPOSE" up -d $BUILD_FLAG
success "CoSMIC_DB stack is up."

#  Step 8: Start CoSMIC
header "Step 8 — CoSMIC (Main stack)"

info "Starting CoSMIC stack (ollama, cosmic, open-webui, pipelines, pycapsule)..."
$DC -f "$COSMIC_COMPOSE" up -d $BUILD_FLAG $PULL_FLAG
success "CoSMIC stack is up."

#  Step 9: Start CoSMIC_UI
header "Step 9 — CoSMIC_UI (Frontend)"

info "Starting CoSMIC_UI dev server..."
$DC -f "$COSMIC_UI_COMPOSE" up -d $BUILD_FLAG
success "CoSMIC_UI is up."

#  Done 
header "All services started!"

echo ""
echo -e "  ${GREEN}${BOLD}CoSMIC API${NC}        →  http://localhost:3000"
echo -e "  ${GREEN}${BOLD}CoSMIC UI (dev)${NC}   →  http://localhost:5173"
echo -e "  ${GREEN}${BOLD}Database${NC}          →  http://localhost:8000"
echo ""

if ask_yn "Tail CoSMIC logs now? (Ctrl+C to stop)" "y"; then
  info "Tailing cosmic container logs..."
  $DC -f "$COSMIC_COMPOSE" logs -f cosmic
fi

