#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# User-configurable options with defaults
get_opt() {
  local val
  val=$(tmux show-option -gqv "$1")
  echo "${val:-$2}"
}

capture_key=$(get_opt @tpc_capture_key "S")
capture_popup_width=$(get_opt @tpc_capture_popup_width "60%")
capture_popup_height=$(get_opt @tpc_capture_popup_height "50%")

# prefix + S  →  Capture current pane layout
tmux bind-key "$capture_key" display-popup \
  -d '#{pane_current_path}' \
  -w "$capture_popup_width" \
  -h "$capture_popup_height" \
  -E \
  "bash '$CURRENT_DIR/scripts/capture.sh'"
