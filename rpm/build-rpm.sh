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
err()  { echo -e "${RED}[err]${RESET}   $*" >&2; }
die()  { err "$*"; exit 1; }

# ── Mason packages ─────────────────────────────────────────────────────────────
# Not hardcoded: resolved at bake time from lua/config/servers.lua and
# lua/config/tools.lua, with server names translated to Mason package names by
# mason-lspconfig's own mapping table. There is no second list to drift.
# Populated by resolve_mason_packages().
#
# If a package's prebuilt binary needs a newer glibc than EL8's 2.28, Mason
# still installs it happily — unpacking a tarball says nothing about whether the
# loader can run it — so verify_mason_binaries() below checks that separately.
# Pin an older build in lua/config/tools.lua ({ name, version = "x.y.z" }) and
# rebuild.
MASON_PKGS=()

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

# Resolve the Mason package list straight from the Lua config, so the editor
# config stays the single source of truth. LSP servers are named by their
# lspconfig name (clangd, ts_ls, …) and translated here via mason-lspconfig's
# mapping table; tools are already Mason package names.
#
# mason.nvim must be loaded first (it populates the registry the mapping reads),
# but mason-lspconfig is only put on the runtimepath — loading it properly would
# run its config and kick off a second, unsupervised install pass.
resolve_mason_packages() {
  info "Resolving Mason packages from the Lua config..."
  local list="$WORK/mason-packages.txt"
  rm -f "$list"

  staged_nvim \
    "+lua require('lazy').load({plugins={'mason.nvim'}})
      vim.opt.rtp:prepend(require('lazy.core.config').plugins['mason-lspconfig.nvim'].dir)
      local to_pkg = require('mason-lspconfig.mappings').get_all().lspconfig_to_package
      local pkgs = {}
      for _, server in ipairs(require('config.servers')) do
        if not to_pkg[server] then
          io.stderr:write('no Mason package for LSP server: ' .. server .. '\n')
          vim.cmd('cq')
        end
        table.insert(pkgs, to_pkg[server])
      end
      -- tools.lua entries are either a name or { name, version = 'x.y.z' };
      -- :MasonInstall takes the pin as name@version.
      for _, tool in ipairs(require('config.tools')) do
        table.insert(pkgs, type(tool) == 'table' and (tool[1] .. '@' .. tool.version) or tool)
      end
      local f = assert(io.open('$list', 'w'))
      f:write(table.concat(pkgs, '\n') .. '\n')
      f:close()" \
    +qa || die "could not resolve Mason packages from lua/config/{servers,tools}.lua"

  [ -s "$list" ] || die "resolved an empty Mason package list"
  MASON_PKGS=()
  while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then MASON_PKGS+=("$pkg"); fi
  done < "$list"
  ok "Mason packages resolved (${#MASON_PKGS[@]}): ${MASON_PKGS[*]}"
}

# A Mason "install" is an unpack: it succeeds whether or not the loader can run
# what came out of the tarball. That is exactly how a package built against a
# newer glibc gets into the payload — the receipt is written, the smoke test
# (LSP + treesitter + DAP) never touches a formatter or linter, and the failure
# surfaces months later on the air-gapped box as "version `GLIBC_2.34' not
# found" the first time someone formats a file.
#
# ldd runs the real loader, so a missing library *or* a missing symbol version
# both show up as "not found" here, on the EL8 host that defines the floor.
verify_mason_binaries() {
  local libc
  libc=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$' || true)
  info "Verifying bundled Mason binaries run on this host (glibc ${libc:-unknown})..."
  local pkgs="$STAGE_HOME/.local/share/nvim/mason/packages"
  [ -d "$pkgs" ] || die "no Mason package directory at $pkgs"
  local bad=0 checked=0 f out
  # Executables, shared libraries, and .node files (Node native addons, which
  # are ELF shared objects but are rarely marked executable).
  while IFS= read -r f; do
    # ELF only: ldd on a shell script or a JS file reports nothing useful
    [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' ')" = "7f454c46" ] || continue
    checked=$((checked + 1))
    out=$(ldd "$f" 2>&1 || true)
    case "$out" in
      *"not found"*)
        err "cannot run on this host: ${f#"$pkgs"/}"
        printf '%s\n' "$out" | grep "not found" | sed 's/^/         /' >&2
        bad=1
        ;;
    esac
  done < <(find "$pkgs" -type f \( -perm -u+x -o -name '*.so' -o -name '*.so.*' -o -name '*.node' \))
  [ "$bad" -eq 0 ] || die "Payload contains binaries EL8 cannot run — pin an older version in lua/config/tools.lua"
  # A find that matched nothing (wrong path, changed layout) would otherwise
  # report success without having inspected a single binary.
  [ "$checked" -gt 0 ] || die "found no ELF binaries under $pkgs — the check did not actually run"
  ok "$checked bundled Mason binaries resolve against this host's glibc"
}

bake_payload() {
  info "Staging config into synthetic HOME..."
  mkdir -p "$STAGE_HOME/.config"
  rm -rf "$STAGE_HOME/.config/nvim"
  rsync -a --exclude .git --exclude rpm/work --exclude dist "$REPO_ROOT/" "$STAGE_HOME/.config/nvim/"

  info "Installing plugins from lazy-lock.json..."
  staged_nvim "+Lazy! restore" +qa
  # `Lazy! restore` exits 0 even when a clone fails, so verify explicitly —
  # a missing plugin here would otherwise only surface on the air-gapped box.
  staged_nvim \
    "+lua local missing = {}
      for _, p in pairs(require('lazy.core.config').plugins) do
        if not p._.installed then table.insert(missing, p.name) end
      end
      if #missing > 0 then
        io.stderr:write('plugins not installed: ' .. table.concat(missing, ', ') .. '\n')
        vim.cmd('cq')
      end" \
    +qa || die "lazy.nvim did not install every plugin"
  ok "Plugins restored"

  resolve_mason_packages

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
    "+MasonInstall ${MASON_PKGS[*]}" \
    +qa
  local pkg
  for pkg in "${MASON_PKGS[@]}"; do
    # strip any name@version pin — the install directory is just the name
    [ -f "$STAGE_HOME/.local/share/nvim/mason/packages/${pkg%%@*}/mason-receipt.json" ] \
      || die "Mason package failed to install: $pkg"
  done
  ok "All ${#MASON_PKGS[@]} Mason packages installed"

  verify_mason_binaries

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
  version="${version#v}" # tag v1.0.0 → rpm version 1.0.0
  # RPM versions must start with a digit (e.g. bare commit-hash fallbacks)
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
