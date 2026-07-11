#!/usr/bin/env bash
# build-rpm.sh — build a fully offline RPM of this Neovim setup for RHEL 8 / Rocky 8.
#
# Run on an INTERNET-CONNECTED RHEL 8 / Rocky 8 x86_64 host:
#   bash rpm/build-rpm.sh
# Produces:
#   dist/nvim-config-<version>-1.el8.x86_64.rpm
#
# The RPM bundles everything an air-gapped box needs: Neovim (built from source
# against EL8 glibc), Node.js, ripgrep, this config, all lazy.nvim plugins,
# compiled treesitter parsers, and every Mason LSP/formatter/linter/debugger.
# Target-side install:  dnf install ./nvim-config-*.rpm  then, per user,
# run `nvim-config-install`.
set -euo pipefail

# ── Pinned component versions (override via env) ──────────────────────────────
NVIM_TAG="${NVIM_TAG:-v0.12.2}"
NODE_VERSION="${NODE_VERSION:-22.17.0}"
RG_VERSION="${RG_VERSION:-14.1.1}"
TS_CLI_VERSION="${TS_CLI_VERSION:-0.26.9}"
PYTHON_BIN="${PYTHON_BIN:-python3.11}"   # debugpy venv python; RPM Requires must match

PREFIX="/opt/nvim-config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO_ROOT/rpm/work}"
DIST="${DIST:-$REPO_ROOT/dist}"
ROOT="$WORK/root"                        # future / of the RPM
STAGE_HOME="$WORK/home"                  # synthetic $HOME for the online bake
TOOLS="$WORK/tools"                      # build-time-only tools (tree-sitter CLI…)

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RESET='\033[0m'
info() { echo -e "${BLUE}[info]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[ ok ]${RESET}  $*"; }
die()  { echo -e "${RED}[err]${RESET}   $*" >&2; exit 1; }

# ── Mason package lists ────────────────────────────────────────────────────────
# Mirrors lua/plugins/lsp.lua (translated to mason package names) and
# lua/plugins/formatting.lua (already mason names). Count-checked below.
# If a package's prebuilt binary needs a newer glibc than EL8's 2.28, the
# offline smoke test fails — pin an older build here with name@version
# (e.g. clangd@17.0.3) and rebuild.
MASON_LSP_PKGS=(
  clangd pyright typescript-language-server html-lsp css-lsp json-lsp
  lua-language-server bash-language-server
)
MASON_TOOL_PKGS=(
  black isort prettier stylua shfmt clang-format
  ruff eslint_d shellcheck
  codelldb cpptools debugpy js-debug-adapter bash-debug-adapter
)

count_ensure_installed() {
  sed -n '/ensure_installed = {/,/},/p' "$1" | grep -oE '"[A-Za-z0-9_-]+"' | wc -l | tr -d ' '
}

check_list_drift() {
  local lsp_count tool_count
  lsp_count=$(count_ensure_installed "$REPO_ROOT/lua/plugins/lsp.lua")
  tool_count=$(count_ensure_installed "$REPO_ROOT/lua/plugins/formatting.lua")
  [ "$lsp_count" -eq "${#MASON_LSP_PKGS[@]}" ] \
    || die "LSP list drift: lua/plugins/lsp.lua has $lsp_count servers, build script has ${#MASON_LSP_PKGS[@]} — update MASON_LSP_PKGS"
  [ "$tool_count" -eq "${#MASON_TOOL_PKGS[@]}" ] \
    || die "Tool list drift: lua/plugins/formatting.lua has $tool_count tools, build script has ${#MASON_TOOL_PKGS[@]} — update MASON_TOOL_PKGS"
  ok "Mason package lists in sync with the lua config ($lsp_count servers, $tool_count tools)"
}

# ── Preflight ──────────────────────────────────────────────────────────────────
preflight() {
  [ "$(uname -m)" = "x86_64" ] || die "Must build on x86_64 (this is $(uname -m))"
  if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${VERSION_ID:-}" in
      8*) ok "Build host: ${NAME:-unknown} ${VERSION_ID}" ;;
      *)  [ "${FORCE:-0}" = "1" ] || die "Build host is ${NAME:-?} ${VERSION_ID:-?}, not EL8 — binaries would link a newer glibc. Set FORCE=1 to override." ;;
    esac
  else
    die "No /etc/os-release — run this on a RHEL 8 / Rocky 8 host"
  fi

  info "Checking build dependencies..."
  # clang-devel: libclang for bindgen when compiling the tree-sitter CLI
  local deps=(gcc gcc-c++ make cmake gettext curl unzip tar git rsync rpm-build clang-devel "$PYTHON_BIN")
  local missing=()
  for dep in "${deps[@]}"; do
    rpm -q "$dep" &>/dev/null || command -v "$dep" &>/dev/null || missing+=("$dep")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    info "Installing: ${missing[*]}"
    local sudo_cmd=""
    [ "$(id -u)" -eq 0 ] || sudo_cmd="sudo"
    $sudo_cmd dnf install -y "${missing[@]}" || die "Failed to install build deps"
  fi
  ok "Build dependencies present"

  check_list_drift
}

# ── Fetch / build components ───────────────────────────────────────────────────
fetch_tree_sitter_cli() {
  mkdir -p "$TOOLS"
  # python3 shim so Mason's debugpy venv is built with $PYTHON_BIN
  ln -sf "$(command -v "$PYTHON_BIN")" "$TOOLS/python3"

  if [ -x "$TOOLS/tree-sitter" ] && "$TOOLS/tree-sitter" --version >/dev/null 2>&1; then
    ok "tree-sitter CLI cached: $("$TOOLS/tree-sitter" --version)"
    return
  fi

  # The prebuilt GitHub release binaries link glibc 2.29+ and cannot run on
  # EL8 (glibc 2.28) — build the CLI from source. Rust comes from rustup, not
  # dnf: v0.26.x needs Rust >= 1.84, newer than EL8's packaged toolchain.
  # Everything stays under $WORK; nothing touches the host toolchain.
  info "Building tree-sitter CLI $TS_CLI_VERSION from source (build-time only; prebuilts need newer glibc)..."
  export RUSTUP_HOME="$WORK/rustup" CARGO_HOME="$WORK/cargo"
  if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
      | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path \
      || die "rustup install failed"
  fi
  "$CARGO_HOME/bin/cargo" install --locked tree-sitter-cli \
    --version "$TS_CLI_VERSION" --root "$WORK/cargo" \
    || die "cargo install tree-sitter-cli $TS_CLI_VERSION failed"
  cp "$WORK/cargo/bin/tree-sitter" "$TOOLS/tree-sitter"
  "$TOOLS/tree-sitter" --version >/dev/null || die "built tree-sitter CLI does not run"
  ok "tree-sitter CLI: $("$TOOLS/tree-sitter" --version)"
}

build_neovim() {
  if [ -x "$ROOT$PREFIX/nvim/bin/nvim" ]; then
    ok "Neovim already built — skipping ($("$ROOT$PREFIX/nvim/bin/nvim" --version | head -1))"
    return
  fi
  info "Building Neovim $NVIM_TAG from source (this takes a while)..."
  rm -rf "$WORK/neovim-src"
  git clone --depth 1 --branch "$NVIM_TAG" https://github.com/neovim/neovim "$WORK/neovim-src"
  make -C "$WORK/neovim-src" CMAKE_BUILD_TYPE=Release "CMAKE_INSTALL_PREFIX=$PREFIX/nvim" -j"$(nproc)"
  make -C "$WORK/neovim-src" install "DESTDIR=$ROOT"
  ok "Neovim built: $("$ROOT$PREFIX/nvim/bin/nvim" --version | head -1)"
}

fetch_runtimes() {
  if [ ! -x "$ROOT$PREFIX/node/bin/node" ]; then
    info "Fetching Node.js $NODE_VERSION..."
    mkdir -p "$ROOT$PREFIX/node"
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -xJ -C "$ROOT$PREFIX/node" --strip-components=1
    "$ROOT$PREFIX/node/bin/node" --version >/dev/null || die "bundled node does not run on this host"
    ok "Node.js: $("$ROOT$PREFIX/node/bin/node" --version)"
  fi

  if [ ! -x "$ROOT$PREFIX/bin/rg" ]; then
    info "Fetching ripgrep $RG_VERSION (static)..."
    mkdir -p "$ROOT$PREFIX/bin"
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C "$ROOT$PREFIX/bin" --strip-components=1 --wildcards '*/rg'
    "$ROOT$PREFIX/bin/rg" --version >/dev/null || die "bundled ripgrep does not run on this host"
    ok "ripgrep: $("$ROOT$PREFIX/bin/rg" --version | head -1)"
  fi

  # Relative symlinks so the tree works both under $ROOT and installed at /
  # (npm is needed at bake time for Mason's node-based packages)
  ln -sf ../nvim/bin/nvim "$ROOT$PREFIX/bin/nvim"
  ln -sf ../node/bin/node "$ROOT$PREFIX/bin/node"
  ln -sf ../node/bin/npm  "$ROOT$PREFIX/bin/npm"
  ln -sf ../node/bin/npx  "$ROOT$PREFIX/bin/npx"
}

# ── Bake plugins, parsers, and Mason tools into a synthetic HOME ───────────────
staged_nvim() {
  env -i HOME="$STAGE_HOME" USER="${USER:-builder}" TERM=dumb \
    PATH="$ROOT$PREFIX/bin:$TOOLS:/usr/bin:/bin" \
    "$ROOT$PREFIX/nvim/bin/nvim" --headless "$@"
}

bake_payload() {
  info "Staging config into synthetic HOME..."
  mkdir -p "$STAGE_HOME/.config"
  rm -rf "$STAGE_HOME/.config/nvim"
  rsync -a --exclude .git --exclude rpm/work --exclude dist "$REPO_ROOT/" "$STAGE_HOME/.config/nvim/"

  info "Installing plugins from lazy-lock.json..."
  staged_nvim "+Lazy! restore" +qa
  ok "Plugins restored"

  info "Warming up blink.cmp (prebuilt fuzzy matcher download)..."
  staged_nvim \
    "+lua require('lazy').load({plugins={'blink.cmp'}})" \
    "+lua local found = vim.wait(180000, function()
        return #vim.fn.glob(vim.fn.stdpath('data') .. '/lazy/blink.cmp/target/release/*', true, true) > 0
      end, 1000); if not found then io.stderr:write('blink fuzzy lib did not download\n'); vim.cmd('cq') end" \
    +qa
  ok "blink.cmp fuzzy matcher present"

  info "Compiling treesitter parsers..."
  local parsers
  parsers=$(staged_nvim \
    "+lua io.stdout:write(table.concat(require('config.parsers'), ','))" +qa 2>/dev/null | tr -d '\r\n')
  [ -n "$parsers" ] || die "Could not read parser list from lua/config/parsers.lua"
  info "  parsers: $parsers"
  staged_nvim \
    "+lua local list = vim.split('$parsers', ','); local t = require('nvim-treesitter').install(list); t:wait(1800000)" \
    "+lua local have = require('nvim-treesitter').get_installed(); local want = vim.split('$parsers', ',')
      for _, l in ipairs(want) do
        if not vim.tbl_contains(have, l) then io.stderr:write('missing parser: ' .. l .. '\n'); vim.cmd('cq') end
      end" \
    +qa
  ok "Treesitter parsers compiled"

  info "Installing Mason packages (LSP servers, tools, debug adapters)..."
  staged_nvim \
    "+lua require('lazy').load({plugins={'mason.nvim'}})" \
    "+MasonInstall ${MASON_LSP_PKGS[*]} ${MASON_TOOL_PKGS[*]}" \
    +qa
  local pkg
  for pkg in "${MASON_LSP_PKGS[@]}" "${MASON_TOOL_PKGS[@]}"; do
    [ -f "$STAGE_HOME/.local/share/nvim/mason/packages/$pkg/mason-receipt.json" ] \
      || die "Mason package failed to install: $pkg"
  done
  ok "All ${#MASON_LSP_PKGS[@]} servers + ${#MASON_TOOL_PKGS[@]} tools installed"

  info "Pruning caches..."
  rm -rf "$STAGE_HOME/.cache" "$STAGE_HOME/.local/state" \
         "$STAGE_HOME/.local/share/nvim/mason/staging"

  info "Moving payload into RPM root..."
  rm -rf "${ROOT:?}${PREFIX:?}/home"
  mkdir -p "$ROOT$PREFIX/home/config" "$ROOT$PREFIX/home/data"
  mv "$STAGE_HOME/.config/nvim" "$ROOT$PREFIX/home/config/nvim"
  mv "$STAGE_HOME/.local/share/nvim" "$ROOT$PREFIX/home/data/nvim"
  ok "Payload staged under $ROOT$PREFIX"
}

install_support_files() {
  install -D -m 0755 "$REPO_ROOT/rpm/nvim-config-install" "$ROOT/usr/bin/nvim-config-install"
  install -D -m 0644 "$REPO_ROOT/rpm/profile.d/nvim-config.sh" "$ROOT/etc/profile.d/nvim-config.sh"
}

# ── Offline smoke test (no containers: empty network namespace via unshare) ────
smoke_test() {
  local testhome="$WORK/testhome"
  info "Offline smoke test: activating into a throwaway HOME..."
  rm -rf "$testhome"; mkdir -p "$testhome"
  HOME="$testhome" NVIM_CONFIG_PREFIX="$ROOT$PREFIX" bash "$REPO_ROOT/rpm/nvim-config-install"

  cat > "$WORK/smoke.lua" <<'LUA'
local buf = vim.api.nvim_get_current_buf()
local attached = vim.wait(90000, function()
  return #vim.lsp.get_clients({ bufnr = buf }) > 0
end, 1000)
if not attached then
  io.stderr:write("SMOKE FAIL: no LSP client for ft=" .. vim.bo[buf].filetype .. "\n")
  vim.cmd("cq")
end
if not vim.treesitter.highlighter.active[buf] then
  io.stderr:write("SMOKE FAIL: treesitter inactive for ft=" .. vim.bo[buf].filetype .. "\n")
  vim.cmd("cq")
end
io.stdout:write("SMOKE OK: ft=" .. vim.bo[buf].filetype
  .. " lsp=" .. vim.lsp.get_clients({ bufnr = buf })[1].name .. "\n")
vim.cmd("qa!")
LUA

  printf '#include <stdio.h>\nint main(void) { printf("hi\\n"); return 0; }\n' > "$testhome/smoke.c"
  printf 'x: int = 1\nprint(x)\n'                                              > "$testhome/smoke.py"
  printf '#!/usr/bin/env bash\necho "hello"\n'                                 > "$testhome/smoke.sh"

  if ! unshare -rn true 2>/dev/null; then
    [ "${SKIP_OFFLINE_NS:-0}" = "1" ] \
      || die "unshare -rn unavailable (user namespaces disabled?). Set SKIP_OFFLINE_NS=1 to run the smoke test WITH network (weaker guarantee)."
    info "Running smoke test without network isolation (SKIP_OFFLINE_NS=1)"
    local runner=(env)
  else
    info "Running smoke test inside an empty network namespace..."
    local runner=(unshare -rn env)
  fi

  local f
  for f in smoke.c smoke.py smoke.sh; do
    "${runner[@]}" -i HOME="$testhome" USER="${USER:-builder}" TERM=dumb NVIM_OFFLINE=1 \
      PATH="$ROOT$PREFIX/bin:/usr/bin:/bin" \
      "$ROOT$PREFIX/nvim/bin/nvim" --headless "+e $testhome/$f" "+luafile $WORK/smoke.lua" \
      || die "Offline smoke test failed on $f"
  done

  # DAP configs register for every language incl. bash
  "${runner[@]}" -i HOME="$testhome" USER="${USER:-builder}" TERM=dumb NVIM_OFFLINE=1 \
    PATH="$ROOT$PREFIX/bin:/usr/bin:/bin" \
    "$ROOT$PREFIX/nvim/bin/nvim" --headless \
    "+lua require('lazy').load({plugins={'nvim-dap'}})
      local dap = require('dap')
      for _, ft in ipairs({'c','cpp','python','sh'}) do
        if not dap.configurations[ft] or #dap.configurations[ft] == 0 then
          io.stderr:write('SMOKE FAIL: no DAP config for ' .. ft .. '\n'); vim.cmd('cq')
        end
      end
      io.stdout:write('SMOKE OK: dap configs present\n')" \
    +qa || die "Offline smoke test failed on DAP configs"

  ok "Offline smoke test passed (LSP + treesitter + DAP, zero network)"
}

# ── Package ────────────────────────────────────────────────────────────────────
build_rpm() {
  local version
  version=$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null | tr '-' '.' || true)
  [ -n "$version" ] || version=$(date +%Y.%m.%d)
  # RPM versions must start with a digit
  case "$version" in [0-9]*) ;; *) version="0.$version" ;; esac

  info "Building RPM (version $version)..."
  mkdir -p "$WORK/rpmbuild" "$DIST"
  rpmbuild -bb \
    --define "_topdir $WORK/rpmbuild" \
    --define "payload_root $ROOT" \
    --define "pkg_version $version" \
    --define "python_dep $PYTHON_BIN" \
    "$REPO_ROOT/rpm/nvim-config.spec"

  local out
  out=$(find "$WORK/rpmbuild/RPMS" -name '*.rpm' | head -1)
  [ -n "$out" ] || die "rpmbuild produced no RPM"
  cp "$out" "$DIST/"
  ok "RPM ready: $DIST/$(basename "$out")"
  echo ""
  echo "Transfer it to the air-gapped system, then:"
  echo "  sudo dnf install ./$(basename "$out")"
  echo "  nvim-config-install        # once per user"
  echo "  exec bash -l               # pick up PATH from /etc/profile.d"
}

preflight
fetch_tree_sitter_cli
build_neovim
fetch_runtimes
bake_payload
install_support_files
smoke_test
build_rpm
