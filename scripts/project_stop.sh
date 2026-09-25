#!/usr/bin/env bash
# Bring down all CoSMIC stacks via docker compose.

project_stop() {
  header "Stopping all stacks"
  for dir in "$UI_DIR" "$COSMIC_DIR" "$DB_DIR"; do
    [[ -f "$dir/compose.yaml" ]] && $DC -f "$dir/compose.yaml" down
  done
  success "Done."
}
