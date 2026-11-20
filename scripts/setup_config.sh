#!/usr/bin/env bash
# Create .env files for CoSMIC / CoSMIC_UI and run CoSMIC_DB's setup script.

setup_config() {
  header "cosmic-core Config"
  cp "$COSMIC_DIR/.env.example" "$COSMIC_DIR/.env"
  success "cosmic-core .env created from .env.example."

  header "cosmic-platform Config"
  cp "$UI_DIR/.env_example" "$UI_DIR/.env"
  success "cosmic-platform .env created from .env_example."

  header "cosmic-db Config"
  if [[ -f "$DB_DIR/bins/setup.sh" ]]; then
    ( cd "$DB_DIR" && bash bins/setup.sh )
  else
    error "cosmic-db/bins/setup.sh not found — repo layout may have changed."
    exit 1
  fi

  header "cosmic-auth Config"
  if [[ -f "$AUTH_DIR/bins/setup.sh" ]]; then
    ( cd "$AUTH_DIR" && bash bins/setup.sh )
  else
    error "cosmic-auth/bins/setup.sh not found — repo layout may have changed."
    exit 1
  fi
}
