#!/usr/bin/env bash
# CoSMIC project launcher (simple version)

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[CoSMIC]${NC} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${NC} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e " $* "
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

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
REPO_DIRS=("$COSMIC_DIR" "$DB_DIR" "$UI_DIR")

docker_cleanup() {
  header "Docker Cleanup"

  if ask_yn "Stop all running containers?" "y"; then
    info "Stopping running containers..."
    docker ps -q | xargs -r docker stop
  fi

  info "Removing containers..."
  docker ps -aq | xargs -r docker rm -f

  info "Removing volumes..."
  docker volume ls -q | xargs -r docker volume rm -f

  info "Removing custom networks..."
  docker network ls --filter type=custom -q | xargs -r docker network rm

  info "Removing images..."
  docker images -aq | xargs -r docker rmi -f

  info "Running system prune..."
  docker system prune -af --volumes

  header "Docker disk usage"
  docker system df
}

echo ""
echo -e "${BLUE}${BOLD}\
 ╔═══════════════════════════════════════╗\n\
 ║         CoSMIC Project Runner         ║\n\
 ╚═══════════════════════════════════════╝${NC}"
echo -e "  Base: ${CYAN}$BASE_DIR${NC}"

#  Step 1: Docker cleanup
docker_cleanup

#  Step 2: Update repositories (whatever branch is on disk)
header "Step 2 — Update Repositories"
for i in "${!REPOS[@]}"; do
  repo="${REPOS[$i]}"
  repo_path="${REPO_DIRS[$i]}"
  if [[ -d "$repo_path/.git" ]]; then
    info "Pulling $repo..."
    git -C "$repo_path" pull || warn "$repo: pull failed (check for local changes)"
  else
    info "Cloning $repo..."
    git clone "${REPO_URLS[$i]}" "$repo_path"
  fi
done

#  Step 3: Config files
header "Step 3 — CoSMIC Config"
if [[ -f "$COSMIC_DIR/.env" ]]; then
  success "CoSMIC .env already exists."
else
  cp "$COSMIC_DIR/.env.example" "$COSMIC_DIR/.env"
  success "CoSMIC .env created from .env.example."
fi

header "Step 4 — CoSMIC_UI Config"
if [[ -f "$UI_DIR/.env" ]]; then
  success "CoSMIC_UI .env already exists."
else
  cp "$UI_DIR/.env_example" "$UI_DIR/.env"
  success "CoSMIC_UI .env created from .env_example."
fi

header "Step 5 — CoSMIC_DB Config"
if [[ -f "$DB_DIR/bins/setup.sh" ]]; then
  ( cd "$DB_DIR" && bash bins/setup.sh )
else
  error "CoSMIC_DB/bins/setup.sh not found — repo layout may have changed."
  exit 1
fi

#  Step 6: Clean up again, then build
docker_cleanup

header "Step 7 — Build & Start"
$DC -f "$DB_DIR/compose.yaml" up -d --build || { error "CoSMIC_DB failed to start"; exit 1; }

info "Waiting for postgres (up to 90s)..."
for (( i=0; i<30; i++ )); do
  docker exec cosmic-postgres pg_isready -q 2>/dev/null && break
  echo -n "."; sleep 3
done
echo ""; success "Postgres ready."

$DC -f "$COSMIC_DIR/compose.yaml" up -d --build || { error "CoSMIC (ollama + qdrant + cosmic) failed to start"; exit 1; }
success "CoSMIC (+ Ollama + Qdrant) is up."

$DC -f "$UI_DIR/compose.yaml" up -d --build || { error "CoSMIC_UI failed to start"; exit 1; }
success "CoSMIC_UI is up."

#  Step 8: Port forwarding helper
header "Step 8 — Port Forwarding"
info "Local URLs on this machine:"
echo -e "  ${GREEN}CoSMIC API${NC}      →  http://localhost:3000"
echo -e "  ${GREEN}CoSMIC UI${NC}       →  http://localhost:5173"
echo -e "  ${GREEN}FastAPI${NC}         →  http://localhost:8000"
echo -e "  ${GREEN}PgAdmin${NC}         →  http://localhost:5050"
echo ""

PORTS=$(ask_input "Ports to forward (comma-separated)" "3000,5173,8000,5050")
GUESS_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
REMOTE=$(ask_input "SSH target (user@host) for THIS machine" "$(whoami)@${GUESS_HOST:-<this-machine-ip>}")

FORWARD_FLAGS=""
IFS=',' read -ra PORT_ARR <<< "$PORTS"
for p in "${PORT_ARR[@]}"; do
  p="${p// /}"
  [[ -n "$p" ]] && FORWARD_FLAGS+=" -L ${p}:localhost:${p}"
done

echo ""
success "Run this on your LOCAL PC to reach the services above:"
echo -e "  ${BOLD}ssh${FORWARD_FLAGS} ${REMOTE}${NC}"
echo ""

#  Step 9: Logs
header "Step 9 — Logs"
if ask_yn "Tail logs now? (Ctrl+C to stop)" "n"; then
  SVC=$(ask_choice "Which service?" "1" \
    "CoSMIC backend" "CoSMIC_DB postgres" "CoSMIC_DB fastapi" "CoSMIC_UI")
  case "$SVC" in
    1) $DC -f "$COSMIC_DIR/compose.yaml" logs -f ;;
    2) $DC -f "$DB_DIR/compose.yaml"     logs -f database ;;
    3) $DC -f "$DB_DIR/compose.yaml"     logs -f backend ;;
    4) $DC -f "$UI_DIR/compose.yaml"     logs -f ;;
  esac
fi
