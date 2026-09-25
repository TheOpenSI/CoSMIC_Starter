#!/usr/bin/env bash
# CoSMIC project launcher (simple version)

set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/docker_cleanup.sh"
source "$SCRIPTS_DIR/project_stop.sh"
source "$SCRIPTS_DIR/update_repos.sh"
source "$SCRIPTS_DIR/setup_config.sh"
source "$SCRIPTS_DIR/start_stack.sh"
source "$SCRIPTS_DIR/port_forward.sh"
source "$SCRIPTS_DIR/tail_logs.sh"

echo ""
echo -e "${BLUE}${BOLD}\
 ╔═══════════════════════════════════════╗\n\
 ║         CoSMIC Project Runner         ║\n\
 ╚═══════════════════════════════════════╝${NC}"
echo -e "  Base: ${CYAN}$BASE_DIR${NC}"
echo ""

MENU=$(ask_choice "What would you like to do?" "1" \
  "Start          — update repos, configure, clean docker, build & start everything" \
  "Stop           — bring down all stacks" \
  "Docker Cleanup — stop/remove containers, volumes, networks, images" \
  "Logs           — tail logs for a specific service" \
  "Prepare        — update repos, configure files (no Docker)")

case "$MENU" in
  1)
    update_repos
    setup_config
    docker_cleanup
    start_stack
    port_forward
    ask_yn "Tail logs now? (Ctrl+C to stop)" "n" && tail_logs
    ;;
  2)
    project_stop
    ;;
  3)
    docker_cleanup
    ;;
  4)
    tail_logs
    ;;
  5)
    update_repos
    setup_config
    success "Repos updated and config files created."
    info "Run this script again and choose Start when you're ready to bring up the stacks."
    ;;
esac
