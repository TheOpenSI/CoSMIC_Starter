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
  echo ""; 
  success "cosmic-db is up and Postgres ready."

  $DC -f "$COSMIC_DIR/compose.yaml" up -d --build || { error "cosmic-core (ollama + qdrant + cosmic) failed to start"; exit 1; }
  success "cosmic-core (+ Ollama + Qdrant) is up."

  $DC -f "$AUTH_DIR/compose.yaml" up -d --build || { error "cosmic-auth failed to start"; exit 1; }
  success "cosmic-auth is up."

  $DC -f "$UI_DIR/compose.yaml" up -d --build || { error "cosmic-platform (UI) failed to start"; exit 1; }
  success "cosmic-platform (UI) is up."
}
