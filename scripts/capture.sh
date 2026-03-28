#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/common.sh"

# ── Pane data arrays ─────────────────────────────────────────────
declare -a PANE_X PANE_Y PANE_W PANE_H PANE_CMD
PANE_COUNT=0

collect_panes() {
  # Get the window ID that launched the popup (the parent window)
  local window
  window=$(tmux display-message -p -t '{last}' '#{window_id}')

  local i=0
  while IFS=$'\t' read -r px py pw ph pcmd; do
    PANE_X[$i]="$px"
    PANE_Y[$i]="$py"
    PANE_W[$i]="$pw"
    PANE_H[$i]="$ph"
    PANE_CMD[$i]="$pcmd"
    i=$((i + 1))
  done < <(tmux list-panes -t "$window" -F '#{pane_left}	#{pane_top}	#{pane_width}	#{pane_height}	#{pane_current_command}')
  PANE_COUNT=$i
}

# ── Split detection ──────────────────────────────────────────────

find_vertical_split() {
  local pane_indices="$1"
  local box_x="$2" box_w="$4"
  local box_right=$((box_x + box_w))
  local -a candidates=()
  local idx

  for idx in $pane_indices; do
    local right=$(( PANE_X[$idx] + PANE_W[$idx] + 1 ))
    if [[ "$right" -gt "$box_x" && "$right" -lt "$box_right" ]]; then
      candidates+=("$right")
    fi
  done

  local -a unique
  IFS=$'\n' read -r -d '' -a unique < <(printf '%s\n' "${candidates[@]}" | sort -nu; printf '\0') || true

  local split_x
  for split_x in "${unique[@]}"; do
    local valid=true
    for idx in $pane_indices; do
      local px="${PANE_X[$idx]}"
      local pr=$(( PANE_X[$idx] + PANE_W[$idx] + 1 ))
      if [[ "$px" -lt "$split_x" && "$pr" -gt "$split_x" ]]; then
        valid=false
        break
      fi
    done
    if [[ "$valid" == true ]]; then
      echo "$split_x"
      return 0
    fi
  done
  return 1
}

find_horizontal_split() {
  local pane_indices="$1"
  local box_y="$3" box_h="$5"
  local box_bottom=$((box_y + box_h))
  local -a candidates=()
  local idx

  for idx in $pane_indices; do
    local bottom=$(( PANE_Y[$idx] + PANE_H[$idx] + 1 ))
    if [[ "$bottom" -gt "$box_y" && "$bottom" -lt "$box_bottom" ]]; then
      candidates+=("$bottom")
    fi
  done

  local -a unique
  IFS=$'\n' read -r -d '' -a unique < <(printf '%s\n' "${candidates[@]}" | sort -nu; printf '\0') || true

  local split_y
  for split_y in "${unique[@]}"; do
    local valid=true
    for idx in $pane_indices; do
      local py="${PANE_Y[$idx]}"
      local pb=$(( PANE_Y[$idx] + PANE_H[$idx] + 1 ))
      if [[ "$py" -lt "$split_y" && "$pb" -gt "$split_y" ]]; then
        valid=false
        break
      fi
    done
    if [[ "$valid" == true ]]; then
      echo "$split_y"
      return 0
    fi
  done
  return 1
}

# ── Recursive tree builder ───────────────────────────────────────

build_tree() {
  local pane_indices="$1"
  local box_x="$2" box_y="$3" box_w="$4" box_h="$5"
  local indent="$6"
  local parent_size="$7"
  local i

  local count=0
  for _ in $pane_indices; do count=$((count + 1)); done

  # Leaf node
  if [[ "$count" -eq 1 ]]; then
    local idx
    for idx in $pane_indices; do :; done
    echo "${indent}- name: pane-${idx}"
    echo "${indent}  size: ${parent_size}"
    echo "${indent}  command: \"${PANE_CMD[$idx]}\""
    return
  fi

  # Try vertical split
  local split_x
  if split_x=$(find_vertical_split "$pane_indices" "$box_x" "$box_y" "$box_w" "$box_h"); then
    local left="" right=""
    for idx in $pane_indices; do
      if [[ "${PANE_X[$idx]}" -lt "$split_x" ]]; then
        left+="$idx "
      else
        right+="$idx "
      fi
    done

    local left_w=$((split_x - box_x))
    local right_w=$((box_w - left_w))
    local left_pct=$(( left_w * 100 / box_w ))
    local right_pct=$((100 - left_pct))

    echo "${indent}- split: vertical"
    echo "${indent}  size: ${parent_size}"
    echo "${indent}  panes:"
    build_tree "$left" "$box_x" "$box_y" "$left_w" "$box_h" "${indent}    " "$left_pct"
    build_tree "$right" "$split_x" "$box_y" "$right_w" "$box_h" "${indent}    " "$right_pct"
    return
  fi

  # Try horizontal split
  local split_y
  if split_y=$(find_horizontal_split "$pane_indices" "$box_x" "$box_y" "$box_w" "$box_h"); then
    local top="" bottom=""
    for idx in $pane_indices; do
      if [[ "${PANE_Y[$idx]}" -lt "$split_y" ]]; then
        top+="$idx "
      else
        bottom+="$idx "
      fi
    done

    local top_h=$((split_y - box_y))
    local bottom_h=$((box_h - top_h))
    local top_pct=$(( top_h * 100 / box_h ))
    local bottom_pct=$((100 - top_pct))

    echo "${indent}- split: horizontal"
    echo "${indent}  size: ${parent_size}"
    echo "${indent}  panes:"
    build_tree "$top" "$box_x" "$box_y" "$box_w" "$top_h" "${indent}    " "$top_pct"
    build_tree "$bottom" "$box_x" "$split_y" "$box_w" "$bottom_h" "${indent}    " "$bottom_pct"
    return
  fi

  echo "Error: Could not determine split for panes: $pane_indices" >&2
  return 1
}

# ── Generate full YAML ───────────────────────────────────────────

generate_yaml() {
  local min_x=999999 min_y=999999 max_right=0 max_bottom=0
  local all_indices=""
  local i

  for ((i = 0; i < PANE_COUNT; i++)); do
    all_indices+="$i "
    [[ "${PANE_X[$i]}" -lt "$min_x" ]] && min_x="${PANE_X[$i]}"
    [[ "${PANE_Y[$i]}" -lt "$min_y" ]] && min_y="${PANE_Y[$i]}"
    local r=$(( PANE_X[$i] + PANE_W[$i] + 1 ))
    local b=$(( PANE_Y[$i] + PANE_H[$i] + 1 ))
    [[ "$r" -gt "$max_right" ]] && max_right="$r"
    [[ "$b" -gt "$max_bottom" ]] && max_bottom="$b"
  done

  local box_w=$((max_right - min_x))
  local box_h=$((max_bottom - min_y))

  local yaml="layout:"$'\n'

  local split_x split_y
  if split_x=$(find_vertical_split "$all_indices" "$min_x" "$min_y" "$box_w" "$box_h"); then
    local left="" right=""
    for ((i = 0; i < PANE_COUNT; i++)); do
      if [[ "${PANE_X[$i]}" -lt "$split_x" ]]; then left+="$i "; else right+="$i "; fi
    done

    local left_w=$((split_x - min_x))
    local right_w=$((box_w - left_w))
    local left_pct=$(( left_w * 100 / box_w ))
    local right_pct=$((100 - left_pct))

    yaml+="  split: vertical"$'\n'
    yaml+="  panes:"$'\n'
    yaml+="$(build_tree "$left" "$min_x" "$min_y" "$left_w" "$box_h" "    " "$left_pct")"$'\n'
    yaml+="$(build_tree "$right" "$split_x" "$min_y" "$right_w" "$box_h" "    " "$right_pct")"$'\n'
  elif split_y=$(find_horizontal_split "$all_indices" "$min_x" "$min_y" "$box_w" "$box_h"); then
    local top="" bottom=""
    for ((i = 0; i < PANE_COUNT; i++)); do
      if [[ "${PANE_Y[$i]}" -lt "$split_y" ]]; then top+="$i "; else bottom+="$i "; fi
    done

    local top_h=$((split_y - min_y))
    local bottom_h=$((box_h - top_h))
    local top_pct=$(( top_h * 100 / box_h ))
    local bottom_pct=$((100 - top_pct))

    yaml+="  split: horizontal"$'\n'
    yaml+="  panes:"$'\n'
    yaml+="$(build_tree "$top" "$min_x" "$min_y" "$box_w" "$top_h" "    " "$top_pct")"$'\n'
    yaml+="$(build_tree "$bottom" "$min_x" "$split_y" "$box_w" "$bottom_h" "    " "$bottom_pct")"$'\n'
  else
    die "Could not determine root split."
  fi

  echo "$yaml"
}

# ── Input helper with Esc support ────────────────────────────────

# Read a line of input, returning 1 if Esc is pressed.
read_or_esc() {
  local prompt="$1"
  local varname="$2"
  local input="" char

  printf '%b' "$prompt"

  while IFS= read -rsn1 char; do
    # Esc — drain any remaining bytes from escape sequence
    if [[ "$char" == $'\x1b' ]]; then
      read -rsn5 -t 0.01 _ 2>/dev/null || true
      echo ""
      return 1
    fi
    # Enter
    if [[ "$char" == "" ]]; then
      echo ""
      printf -v "$varname" '%s' "$input"
      return 0
    fi
    # Backspace
    if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
      if [[ -n "$input" ]]; then
        input="${input%?}"
        printf '\b \b'
      fi
      continue
    fi
    input+="$char"
    printf '%s' "$char"
  done
}

# ── Main ─────────────────────────────────────────────────────────

header "Save pane layout"

collect_panes

if [[ "$PANE_COUNT" -lt 2 ]]; then
  die "Need at least 2 panes to capture a layout."
fi

echo -e "${C_DIM}Detected ${PANE_COUNT} panes.${C_RESET}"
echo ""

yaml=$(generate_yaml) || die "Failed to generate layout."

# Prompt for name and description
echo -e "${C_BLUE}${C_BOLD}Details${C_RESET} ${C_DIM}(Esc to cancel)${C_RESET}"
echo ""

layout_name=""
layout_desc=""

read_or_esc "$(echo -e "${C_MAUVE}  Layout name: ${C_RESET}")" layout_name || exit 0
read_or_esc "$(echo -e "${C_MAUVE}  Description: ${C_RESET}")" layout_desc || exit 0

layout_name="${layout_name:-$(basename "$PWD")}"
layout_desc="${layout_desc:-}"

# Inject name and description
yaml=$(echo "$yaml" | NAME="$layout_name" DESC="$layout_desc" yq '.layout.name = env(NAME) | .layout.description = env(DESC)')

# Save
ensure_config_dir
hash=$(get_hash "$PWD")
config_file="$TPC_CONFIG_DIR/${hash}.yml"

if [[ -f "$config_file" ]]; then
  echo ""
  echo -e "${C_YELLOW}  Layout already exists.${C_RESET}"
  read_or_esc "$(echo -e "${C_YELLOW}  Overwrite? [y/N] ${C_RESET}")" confirm || exit 0
  if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

echo "$yaml" > "$config_file"

# Update index
HASH="$hash" yq -i 'del(.layouts[] | select(.hash == env(HASH)))' "$TPC_INDEX_FILE"
NAME="$layout_name" DESC="$layout_desc" HASH="$hash" \
  yq -i '.layouts += [{"name": env(NAME), "description": env(DESC), "hash": env(HASH)}]' "$TPC_INDEX_FILE"

echo ""
echo -e "${C_GREEN}${C_BOLD}Layout saved.${C_RESET}"
echo -e "${C_DIM}  Use 'tpc load' to restore it.${C_RESET}"
echo -e "${C_DIM}  Use 'tpc edit' to refine commands.${C_RESET}"
echo ""
echo -e "${C_DIM}Press any key to close...${C_RESET}"
read -rsn1
