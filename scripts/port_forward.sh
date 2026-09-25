#!/usr/bin/env bash
# Print local URLs and a ready-to-run ssh -L command for forwarding ports to a local PC.

port_forward() {
  header "Port Forwarding"
  info "Local URLs on this machine:"
  echo -e "  ${GREEN}CoSMIC API${NC}      →  http://localhost:3000"
  echo -e "  ${GREEN}CoSMIC UI${NC}       →  http://localhost:5173"
  echo -e "  ${GREEN}FastAPI${NC}         →  http://localhost:8000"
  echo -e "  ${GREEN}PgAdmin${NC}         →  http://localhost:5050"
  echo ""

  local ports guess_host remote forward_flags port_arr p
  ports=$(ask_input "Ports to forward (comma-separated)" "3000,5173,8000,5050")
  guess_host="$(hostname -I 2>/dev/null | awk '{print $1}')"
  remote=$(ask_input "SSH target (user@host) for THIS machine" "$(whoami)@${guess_host:-<this-machine-ip>}")

  forward_flags=""
  IFS=',' read -ra port_arr <<< "$ports"
  for p in "${port_arr[@]}"; do
    p="${p// /}"
    [[ -n "$p" ]] && forward_flags+=" -L ${p}:localhost:${p}"
  done

  echo ""
  success "Run this on your LOCAL PC to reach the services above:"
  echo -e "  ${BOLD}ssh${forward_flags} ${remote}${NC}"
  echo ""
}
