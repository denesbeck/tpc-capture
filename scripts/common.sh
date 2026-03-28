set -eo pipefail

# ── Dependency checks ────────────────────────────────────────────
for cmd in tmux yq b3sum; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# ── Theme (Catppuccin Frappé palette) ────────────────────────────
C_BLUE="\033[38;2;140;170;238m"   # #8caaee
C_MAUVE="\033[38;2;202;158;230m"  # #ca9ee6
C_GREEN="\033[38;2;166;209;137m"  # #a6d189
C_RED="\033[38;2;231;130;132m"    # #e78284
C_YELLOW="\033[38;2;229;200;144m" # #e5c890
C_TEXT="\033[38;2;198;208;245m"   # #c6d0f5
C_DIM="\033[38;2;115;121;148m"    # #737994
C_BOLD="\033[1m"
C_RESET="\033[0m"

TPC_CONFIG_DIR="$HOME/.config/tpc"
TPC_INDEX_FILE="$TPC_CONFIG_DIR/index.yml"

ensure_config_dir() {
  mkdir -p -m 700 "$TPC_CONFIG_DIR"
  if [[ ! -f "$TPC_INDEX_FILE" ]]; then
    echo "layouts: []" > "$TPC_INDEX_FILE"
  fi
}

get_hash() {
  echo -n "$1" | b3sum --no-names
}

die() {
  echo ""
  echo -e "${C_RED}${C_BOLD}Error:${C_RESET}${C_TEXT} $1${C_RESET}"
  echo ""
  echo -e "${C_DIM}Press any key to close...${C_RESET}"
  read -rsn1
  exit 1
}

header() {
  clear
  echo ""
  echo -e "${C_MAUVE}${C_BOLD}TPC Capture${C_RESET} ${C_DIM}─ $1${C_RESET}"
  echo ""
}
