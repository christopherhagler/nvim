#!/usr/bin/env bash
# setup.sh — install, update, and manage the neovim config
#
# Quick install (curl | bash):
#   curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh | bash
#
# Direct usage:
#   bash setup.sh <command>
#
set -euo pipefail

REPO_URL="https://github.com/christopherhagler/nvim.git"
RAW_URL="https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh"
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
NVIM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
MIN_NVIM_VERSION="0.11.0"

# ── Colours ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

info()   { echo -e "${BLUE}[info]${RESET}  $*"; }
ok()     { echo -e "${GREEN}[ ok ]${RESET}  $*"; }
warn()   { echo -e "${YELLOW}[warn]${RESET}  $*"; }
err()    { echo -e "${RED}[err]${RESET}   $*" >&2; }
die()    { err "$*"; exit 1; }
header() {
  local text="$*"
  echo -e "\n${BOLD}${CYAN}${text}${RESET}"
  printf "${CYAN}"; printf '─%.0s' $(seq 1 "${#text}"); printf "${RESET}\n"
}

banner() {
  echo -e "${CYAN}${BOLD}"
  cat <<'EOF'
  ███╗   ██╗██╗   ██╗██╗███╗   ███╗
  ████╗  ██║██║   ██║██║████╗ ████║
  ██╔██╗ ██║██║   ██║██║██╔████╔██║
  ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
  ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
  ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
EOF
  echo -e "${RESET}${DIM}  C/C++ · Python · Web  —  lazy.nvim + native LSP${RESET}"
  echo ""
}

# ── Pipe detection ─────────────────────────────────────────────────────────────
# When run via `curl | bash`, stdin is the pipe rather than the terminal.
# We use /dev/tty explicitly for all prompts so they still work.
IS_PIPED=false
[ -t 0 ] || IS_PIPED=true

ask() {
  # ask <prompt> <varname>  — reads from /dev/tty so it works inside a pipe
  local __var="$2"
  read -rp "$1" "$__var" </dev/tty
}

# ── Helpers ────────────────────────────────────────────────────────────────────
version_gte() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
nvim_version() { nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

check_required_deps() {
  local failed=0

  if ! command -v nvim &>/dev/null; then
    err "nvim not found — install Neovim >= $MIN_NVIM_VERSION"
    failed=1
  elif ! version_gte "$(nvim_version)" "$MIN_NVIM_VERSION"; then
    err "Neovim $(nvim_version) is too old — need >= $MIN_NVIM_VERSION"
    failed=1
  fi

  if ! command -v git &>/dev/null; then
    err "git not found"
    failed=1
  fi

  return $failed
}

check_optional_deps() {
  local items=(
    "rg:ripgrep (Telescope live grep)"
    "make:make (telescope-fzf-native build)"
    "node:Node.js (TS/JS LSP, prettier)"
    "python3:Python 3 (pyright, debugpy)"
    "clang:clang (C/C++ compiler)"
    "gdb:gdb (C/C++ debugging via cpptools; needed on Linux/RHEL, not on macOS)"
  )
  local any_missing=0
  for item in "${items[@]}"; do
    local cmd="${item%%:*}" label="${item##*:}"
    if ! command -v "$cmd" &>/dev/null; then
      warn "  missing: $label"
      any_missing=1
    fi
  done
  return $any_missing
}

backup_config() {
  if [ -d "$NVIM_CONFIG_DIR" ]; then
    local dest="${HOME}/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)"
    info "Backing up $NVIM_CONFIG_DIR → $dest"
    cp -r "$NVIM_CONFIG_DIR" "$dest"
    ok "Backup saved to $dest"
  fi
}

run_nvim_headless() {
  # Run a headless command; on failure, surface the output instead of hiding it.
  local out
  if ! out=$(nvim --headless -c "$1" -c "qa!" 2>&1); then
    [ -n "$out" ] && echo "$out" >&2
    return 1
  fi
  return 0
}

# ── Commands ───────────────────────────────────────────────────────────────────
cmd_install() {
  banner
  header "Installing Neovim Config"

  info "Checking required dependencies..."
  check_required_deps || die "Install missing dependencies and re-run."
  ok "Required dependencies satisfied"

  info "Checking optional dependencies..."
  if ! check_optional_deps; then
    warn "Some optional tools are missing — certain features may not work until they are installed."
  else
    ok "All optional dependencies found"
  fi

  # Handle existing config
  if [ -d "$NVIM_CONFIG_DIR" ]; then
    if $IS_PIPED; then
      die "Config already exists at $NVIM_CONFIG_DIR.\nRun the script directly to back up and replace:\n  bash setup.sh install"
    fi
    warn "Existing config detected at $NVIM_CONFIG_DIR"
    ask "  Back up and replace it? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    backup_config
    rm -rf "$NVIM_CONFIG_DIR"
  fi

  info "Cloning repository..."
  git clone --depth=1 "$REPO_URL" "$NVIM_CONFIG_DIR" \
    || die "Clone failed. Check your network connection."
  ok "Repository cloned"

  info "Bootstrapping lazy.nvim and installing plugins..."
  if run_nvim_headless "Lazy! sync"; then
    ok "Plugins installed"
  else
    warn "Plugin install reported errors — open Neovim and run :Lazy to inspect"
  fi

  echo ""
  ok "Installation complete!"
  echo -e "\n  ${BOLD}Next steps:${RESET}"
  echo "  1. Open Neovim:       nvim"
  echo "  2. Install LSP tools: :Mason"
  echo "  3. Verify setup:      :checkhealth"
  echo ""
  echo -e "  ${DIM}Re-run this script anytime:  bash setup.sh <command>${RESET}"
  echo ""
}

cmd_update() {
  header "Updating Neovim Config"

  [ -d "$NVIM_CONFIG_DIR" ] || die "No config found at $NVIM_CONFIG_DIR. Run 'install' first."

  if ! git -C "$NVIM_CONFIG_DIR" diff --quiet 2>/dev/null; then
    warn "You have local changes in $NVIM_CONFIG_DIR"
    ask "  Stash them and continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    git -C "$NVIM_CONFIG_DIR" stash push -m "setup.sh auto-stash $(date +%Y%m%d_%H%M%S)"
    ok "Changes stashed"
  fi

  info "Pulling latest config..."
  git -C "$NVIM_CONFIG_DIR" pull --ff-only \
    || die "Pull failed. You may need to resolve conflicts manually."
  ok "Config updated"

  info "Syncing plugins..."
  if run_nvim_headless "Lazy! sync"; then
    ok "Plugins synced"
  else
    warn "Plugin sync reported errors — open Neovim and run :Lazy to inspect"
  fi

  info "Updating Mason packages..."
  if run_nvim_headless "MasonUpdate"; then
    ok "Mason packages updated"
  else
    warn "Mason update reported errors — open Neovim and run :Mason to inspect"
  fi

  ok "Update complete!"
}

cmd_remove() {
  header "Removing Neovim Config"

  [ -d "$NVIM_CONFIG_DIR" ] || die "No config found at $NVIM_CONFIG_DIR."

  warn "This will remove: $NVIM_CONFIG_DIR"
  ask "  Also remove plugin data (~/.local/share/nvim)? [y/N] " remove_data
  ask "  Are you sure? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

  backup_config
  rm -rf "$NVIM_CONFIG_DIR"
  ok "Config removed"

  if [[ "$remove_data" =~ ^[Yy]$ ]]; then
    rm -rf "$NVIM_DATA_DIR" "$NVIM_STATE_DIR"
    ok "Plugin and state data removed"
  fi

  ok "Done. A backup was saved in case you change your mind."
}

cmd_health() {
  header "Health Check"

  if command -v nvim &>/dev/null; then
    local ver; ver=$(nvim_version)
    if version_gte "$ver" "$MIN_NVIM_VERSION"; then
      ok "Neovim $ver"
    else
      err "Neovim $ver — upgrade to >= $MIN_NVIM_VERSION"
    fi
  else
    err "Neovim not found"
  fi

  if [ -d "$NVIM_CONFIG_DIR" ]; then
    ok "Config: $NVIM_CONFIG_DIR"
    local count
    count=$(find "${NVIM_DATA_DIR}/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    ok "Plugins installed: ${count}"
  else
    warn "No config at $NVIM_CONFIG_DIR — run 'install'"
  fi

  echo ""
  info "External tools (must be on your PATH):"
  local tools=(
    "git:git" "rg:ripgrep" "make:make"
    "node:Node.js" "python3:Python 3"
    "clang:clang" "gdb:gdb"
  )
  for entry in "${tools[@]}"; do
    local cmd="${entry%%:*}" label="${entry##*:}"
    if command -v "$cmd" &>/dev/null; then
      local ver; ver=$("$cmd" --version 2>/dev/null | head -1 | grep -oE '[0-9][0-9.]+' | head -1)
      ok "  ${label}${ver:+ (${ver})}"
    else
      warn "  ${label} — not found"
    fi
  done
  echo ""
  info "clangd, formatters, linters, and debug adapters are managed by Mason —"
  info "verify those with :Mason or :checkhealth (checked below)."

  if [ -d "$NVIM_CONFIG_DIR" ]; then
    echo ""
    info "Launching :checkhealth (press q to exit)..."
    nvim +checkhealth
  fi
}

cmd_backup() {
  header "Backup Config"
  [ -d "$NVIM_CONFIG_DIR" ] || die "No config found at $NVIM_CONFIG_DIR."
  backup_config
}

cmd_restore() {
  header "Restore from Backup"

  local backups=()
  while IFS= read -r -d '' dir; do
    backups+=("$dir")
  done < <(find "${HOME}/.config" -maxdepth 1 -name "nvim.bak.*" -type d -print0 2>/dev/null | sort -rz)

  [ ${#backups[@]} -gt 0 ] || die "No backups found in ${HOME}/.config/"

  echo "Available backups (newest first):"
  for i in "${!backups[@]}"; do
    echo "  [$(( i + 1 ))] ${backups[$i]}"
  done
  echo ""
  ask "Select [1-${#backups[@]}]: " choice

  [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#backups[@]} )) \
    || die "Invalid selection."

  local selected="${backups[$(( choice - 1 ))]}"

  if [ -d "$NVIM_CONFIG_DIR" ]; then
    warn "This will replace the current config."
    ask "  Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    rm -rf "$NVIM_CONFIG_DIR"
  fi

  cp -r "$selected" "$NVIM_CONFIG_DIR"
  ok "Restored from $selected"
}

cmd_status() {
  header "Status"

  if [ ! -d "$NVIM_CONFIG_DIR" ]; then
    warn "Not installed — run: bash setup.sh install"
    return
  fi

  local branch commit age
  branch=$(git -C "$NVIM_CONFIG_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  commit=$(git -C "$NVIM_CONFIG_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  age=$(git -C "$NVIM_CONFIG_DIR" log -1 --format="%cr" 2>/dev/null || echo "unknown")

  ok "Config:   $NVIM_CONFIG_DIR"
  ok "Branch:   $branch @ $commit ($age)"
  ok "Neovim:   $(nvim_version 2>/dev/null || echo 'not found')"

  local count
  count=$(find "${NVIM_DATA_DIR}/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  ok "Plugins:  ${count} installed"

  git -C "$NVIM_CONFIG_DIR" fetch --quiet 2>/dev/null || true
  local behind
  behind=$(git -C "$NVIM_CONFIG_DIR" rev-list HEAD..@\{u\} --count 2>/dev/null || echo 0)
  if [ "$behind" -gt 0 ]; then
    warn "  $behind commit(s) behind remote — run: bash setup.sh update"
  else
    ok "Up to date with remote"
  fi
}

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
  banner
  echo -e "${BOLD}Quick install:${RESET}"
  echo "  curl -fsSL $RAW_URL | bash"
  echo ""
  echo -e "${BOLD}Usage:${RESET}"
  echo "  bash setup.sh <command>"
  echo ""
  echo -e "${BOLD}Commands:${RESET}"
  printf "  ${GREEN}%-10s${RESET} %s\n" "install" "Clone and install the config and all plugins"
  printf "  ${GREEN}%-10s${RESET} %s\n" "update"  "Pull latest config and sync plugins + Mason packages"
  printf "  ${GREEN}%-10s${RESET} %s\n" "remove"  "Remove the config (with optional plugin data wipe)"
  printf "  ${GREEN}%-10s${RESET} %s\n" "status"  "Show install info and check for upstream updates"
  printf "  ${GREEN}%-10s${RESET} %s\n" "health"  "Check tool availability and run :checkhealth"
  printf "  ${GREEN}%-10s${RESET} %s\n" "backup"  "Snapshot current config to a timestamped backup"
  printf "  ${GREEN}%-10s${RESET} %s\n" "restore" "Restore a previous backup"
  echo ""
  echo -e "${BOLD}Repo:${RESET} $REPO_URL"
}

# ── Entry point ────────────────────────────────────────────────────────────────
# When piped (curl | bash) with no arguments, run install automatically.
if $IS_PIPED && [ -z "${1:-}" ]; then
  cmd_install
  exit 0
fi

case "${1:-}" in
  install) cmd_install ;;
  update)  cmd_update  ;;
  remove)  cmd_remove  ;;
  status)  cmd_status  ;;
  health)  cmd_health  ;;
  backup)  cmd_backup  ;;
  restore) cmd_restore ;;
  -h|--help|help|"") usage ;;
  *) err "Unknown command: $1"; echo ""; usage; exit 1 ;;
esac
