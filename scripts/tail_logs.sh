#!/usr/bin/env bash
# Ask which service and tail its logs.

tail_logs() {
  header "Logs"
  local svc
  svc=$(ask_choice "Which service?" "1" \
    "CoSMIC backend" "CoSMIC_DB postgres" "CoSMIC_DB fastapi" "CoSMIC_UI")
  case "$svc" in
    1) $DC -f "$COSMIC_DIR/compose.yaml" logs -f ;;
    2) $DC -f "$DB_DIR/compose.yaml"     logs -f database ;;
    3) $DC -f "$DB_DIR/compose.yaml"     logs -f backend ;;
    4) $DC -f "$UI_DIR/compose.yaml"     logs -f ;;
  esac
}
