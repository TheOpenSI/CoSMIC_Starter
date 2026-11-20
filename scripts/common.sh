#!/usr/bin/env bash
# Shared helpers, paths, and docker compose detection for run.sh

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
DB_DIR="$BASE_DIR/cosmic-db"
COSMIC_DIR="$BASE_DIR/cosmic-core"
UI_DIR="$BASE_DIR/cosmic-platform"
AUTH_DIR="$BASE_DIR/cosmic-auth"

REPOS=("cosmic-core" "cosmic-db" "cosmic-platform" "cosmic-auth")
REPO_URLS=(
  "https://github.com/TheOpenSI/CoSMIC.git"
  "https://github.com/TheOpenSI/CoSMIC_DB.git"
  "https://github.com/TheOpenSI/CoSMIC_UI.git"
  "https://github.com/TheOpenSI/cosmic-auth.git"
)
REPO_DIRS=("$COSMIC_DIR" "$DB_DIR" "$UI_DIR" "$AUTH_DIR")
DEFAULT_BRANCHES=("Development" "dev" "development" "dev")
