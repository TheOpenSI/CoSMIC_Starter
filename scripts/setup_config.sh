#!/usr/bin/env bash
# Create .env files for CoSMIC / CoSMIC_UI and run CoSMIC_DB's setup script.

setup_config() {
  header "CoSMIC Config"
  cp "$COSMIC_DIR/.env.example" "$COSMIC_DIR/.env"
  success "CoSMIC .env created from .env.example."

  header "CoSMIC_UI Config"
  cp "$UI_DIR/.env_example" "$UI_DIR/.env"
  success "CoSMIC_UI .env created from .env_example."

  header "CoSMIC_DB Config"
  if [[ -f "$DB_DIR/bins/setup.sh" ]]; then
    ( cd "$DB_DIR" && bash bins/setup.sh )
  else
    error "CoSMIC_DB/bins/setup.sh not found — repo layout may have changed."
    exit 1
  fi
}
