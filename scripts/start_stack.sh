#!/usr/bin/env bash
# Build and start all three stacks in dependency order (DB -> CoSMIC -> UI).

start_stack() {
  header "Build & Start"
  $DC -f "$DB_DIR/compose.yaml" up -d --build || { error "CoSMIC_DB failed to start"; exit 1; }

  info "Waiting for postgres (up to 90s)..."
  local i
  for (( i=0; i<30; i++ )); do
    docker exec cosmic-postgres pg_isready -q 2>/dev/null && break
    echo -n "."; sleep 3
  done
  echo ""; success "Postgres ready."

  $DC -f "$COSMIC_DIR/compose.yaml" up -d --build || { error "CoSMIC (ollama + qdrant + cosmic) failed to start"; exit 1; }
  success "CoSMIC (+ Ollama + Qdrant) is up."

  $DC -f "$UI_DIR/compose.yaml" up -d --build || { error "CoSMIC_UI failed to start"; exit 1; }
  success "CoSMIC_UI is up."
}
