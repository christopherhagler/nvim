# Neovim Configuration

A Lua-first Neovim setup targeting C/C++, Python, Bash, and web development. Uses `lazy.nvim` for plugin management, native LSP for language intelligence, `nvim-dap` for debugging, and `neotest` for tests. Building and running are built in — `<leader>bb` compiles the project into the quickfix list, `<leader>br` runs the current file.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Air-gapped install (RPM)](#air-gapped-install-rpm)
- [File Structure](#file-structure)
- [Key Mappings](#key-mappings)
- [Building and running](#building-and-running)
- [CMake projects](#cmake-projects)
- [C/C++ project setup](#cc-project-setup)
- [Python virtualenvs](#python-virtualenvs)
- [The project root](#the-project-root)
- [Project-local configuration](#project-local-configuration)
- [Formatting](#formatting)
- [Plugins](#plugins)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh | bash
```

This downloads and runs `setup.sh`, which checks your dependencies, backs up any existing config, clones the repo, and installs all plugins automatically.

## Prerequisites

- **Neovim** >= 0.12.0 — native `vim.lsp` config needs 0.11+, and CodeLens (`vim.lsp.codelens.enable`) needs the 0.12 rewrite
- **Git**
- **ripgrep** — live grep in Telescope, and the search engine behind grug-far
- **make** — required to build the telescope-fzf-native extension
- **A C compiler** — clang (macOS) or gcc (RHEL/Rocky); used for treesitter parsers and clangd projects
- **tree-sitter CLI** >= 0.26 — required by nvim-treesitter (main branch) to install parsers; install via package manager or `cargo install tree-sitter-cli`, not npm
- **unzip** — Mason package extraction (often missing on minimal RHEL/Rocky installs)
- **Node.js** — for TypeScript/JavaScript LSP, prettier, and the JS debug adapter
- **Python 3** — for pyright and debugpy
- **bash >= 4** — for bash script debugging via bashdb (macOS ships 3.2: `brew install bash`)
- **Linux only:** a clipboard tool (`xclip`, `xsel`, or `wl-clipboard`) for system-clipboard integration, and `gdb` for C/C++ debugging

Optional, per workflow:

- **cmake >= 3.14** — for CMake projects; `:CompileCommands` and `<leader>bb` both drive it, and target/preset selection reads its file API (see [CMake projects](#cmake-projects))
- **bear** — records compile flags from a `make` build so clangd can read them (`:CompileCommands`). Only needed for Makefile projects; CMake exports the same data itself. EPEL ships it on EL8 (`dnf install bear`), Homebrew on macOS.
- **pytest / jest / vitest / gtest** — installed per project, not globally; `<leader>Tr` runs whichever the project uses

### Platform notes (macOS / RHEL 8 / Rocky 8)

- **Neovim on RHEL 8 / Rocky 8**: official release binaries require glibc 2.31+, but EL8 ships 2.28 — build from source or use a compatible build.
- **C/C++ debugging** picks the right adapter per platform automatically: codelldb (LLDB) on macOS, gdb via cpptools on Linux. Both stay available in the `<F5>` picker.
- **blink.cmp** downloads a prebuilt Rust fuzzy matcher; if it's incompatible with the system (e.g. old glibc), it falls back to the Lua matcher with a warning — completion keeps working.
- **Language standard for single-file builds** is probed, not assumed. EL8 ships gcc 8.5, which predates `-std=c++20` entirely; `<leader>bb` asks the compiler what it accepts (newest first, `c++20 → c++17 → c++14`) and caches the answer. macOS clang gets c++20, Rocky 8 gets c++17, neither needs configuring. Single-file **C++** builds additionally need `gcc-c++` installed, which the base `gcc` package does not pull in.
- **`bear`** changed its CLI between versions 2 and 3 (version 3 requires a `--` separator before the build command, version 2 rejects it). `:CompileCommands` checks the installed version and uses the matching form.
- **cmake >= 3.14** is required by `<leader>bb` and `:CompileCommands`: 3.13 for the `-S . -B build` form, and 3.14 for the file API that target and preset selection read. RHEL/Rocky 8.2+ ship 3.20 or newer, which also covers `CMakePresets.json` (3.19+); only an unpatched 8.0 install (cmake 3.11) is too old.
- **`<leader>K`** needs `man-pages` and `man-db`, which minimal RHEL/Rocky installs omit. Without them it reports "no man page" and nothing else changes.
- **Deliberately excluded** because their upstream binaries need a newer glibc than EL8 provides: `asm_lsp` and `neocmakelsp`. Anything that would work on the Mac but not the RHEL boxes does not go in `lua/config/servers.lua`.
- **stylua is pinned to 2.0.2** in `lua/config/tools.lua`. Its Linux release is a glibc build, and from 2.3.0 on it is linked against `GLIBC_2.34`; 2.0.2 is the newest release that still runs on EL8's 2.28. Every other bundled binary was checked against the same floor — clangd (2.18), lua-language-server (2.17), codelldb and liblldb (2.18), cpptools (2.16), and the bundled Node 22 (2.28 exactly) all clear it, and ruff, shellcheck, shfmt and stylua's musl variant are static. `rpm/build-rpm.sh` re-checks the whole payload with `ldd` at bake time so a future release that raises its floor fails the build instead of the user.
- `setup.sh` (install/health) checks all of the above per platform. For `cmake` and the `tree-sitter` CLI it checks the **version**, not just presence — both are tools that install cleanly and then fail at a specific feature (cmake 3.11 configures a project fine and then reports no targets), which is a far quieter failure than a missing binary.

Everything else added for building, testing and editing is either pure Lua/Vimscript
(no binaries at all) or runs on the two runtimes the RPM already bundles — Node
22.17 for the npm-based tools (eslint, emmet, markdownlint, prettier) and
python3.11 for the pip-based ones (yamllint, cmake-format, debugpy).

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh | bash
```

### setup.sh commands

After installing, save `setup.sh` locally to use the full CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh -o setup.sh
chmod +x setup.sh
```

| Command | Description |
| :--- | :--- |
| `./setup.sh install` | Clone and install the config and all plugins |
| `./setup.sh update` | Pull latest config and sync plugins + Mason packages |
| `./setup.sh remove` | Remove the config (with optional plugin data wipe) |
| `./setup.sh status` | Show install info and check for upstream updates |
| `./setup.sh health` | Check tool availability (and version, where it matters) and run `:checkhealth` |
| `./setup.sh backup` | Snapshot current config to a timestamped backup |
| `./setup.sh restore` | Restore a previous backup |

### Manual install

1. Clone the repository:

   ```bash
   git clone https://github.com/christopherhagler/nvim.git ~/.config/nvim
   ```

2. Open Neovim — `lazy.nvim` bootstraps and installs all plugins on first launch.
3. Run `:Mason` to install LSP servers, formatters, linters, and debug adapters.

## Air-gapped install (RPM)

For systems with **no internet access** (air-gapped RHEL 8 / Rocky 8),
`setup.sh` can't be used — it downloads plugins and Mason packages. Instead,
build a self-contained RPM that bundles **everything**: Neovim (compiled
against EL8 glibc), Node.js, ripgrep, this config, all plugins, compiled
treesitter parsers, and every Mason tool (LSP servers, formatters, linters,
debug adapters).

### Build via GitHub Actions (easiest)

The **Build offline RPM** workflow builds the artifact in a Rocky Linux 8
container (matching RHEL 8's glibc) on GitHub's runners:

- Manual: Actions tab → *Build offline RPM* → *Run workflow* → download the
  `nvim-config-rpm` artifact when the run finishes (~30–60 min).
- Release: push a version tag (`git tag v1.0.0 && git push --tags`) — the RPM
  is built and attached to the GitHub Release automatically.

### Build manually (on an internet-connected RHEL 8 / Rocky 8 x86_64 host)

```bash
git clone https://github.com/christopherhagler/nvim.git && cd nvim
bash rpm/build-rpm.sh
# → dist/nvim-config-<version>-1.el8.x86_64.rpm  (~1 GB)
```

The script installs its own build dependencies via dnf, builds Neovim from
source, bakes all plugins/parsers/tools into the payload using a synthetic
`$HOME`, and — before packaging — proves the result works with **zero
network** by re-running it inside an empty network namespace (`unshare -rn`):
clean boot, LSP attach on C/Python/bash buffers, treesitter, and DAP configs.

Component versions (Neovim tag, Node.js, ripgrep, tree-sitter CLI, python for
debugpy) are pinned at the top of `rpm/build-rpm.sh` and overridable via env.

The build script keeps no package lists of its own. It reads
`lua/config/servers.lua`, `lua/config/tools.lua`, and `lua/config/parsers.lua`
out of the staged config at build time — translating LSP server names to Mason
package names with mason-lspconfig's own mapping — so adding a server or tool to
the editor config is all that is needed to get it into the RPM.

### Install (on the air-gapped target)

```bash
sudo dnf install ./nvim-config-<version>-1.el8.x86_64.rpm
nvim-config-install   # once per user: copies config + plugins into $HOME
exec bash -l          # pick up PATH (nvim, node, rg) from /etc/profile.d
nvim
```

The RPM installs the payload read-only under `/opt/nvim-config` and declares
only two dependencies: `git` and `python3.11` (for debugpy). `nvim-config-install`
backs up any existing `~/.config/nvim` before activating, and is safe to
re-run to reset to the packaged state. `/etc/profile.d/nvim-config.sh` also
sets `NVIM_OFFLINE=1`, which tells the config to skip all startup install
checks.

To update: build a new RPM with a newer config, `sudo dnf upgrade` it on the
target, and each user re-runs `nvim-config-install`.

## File Structure

```text
init.lua                    # Entry point — lazy.nvim bootstrap
lua/
  config/
    options.lua             # Core Neovim options
    keymaps.lua             # Global key mappings
    autocmds.lua            # Autocommands (whitespace trim, yank highlight, etc.)
    commands.lua            # User commands (:Build, :Run, :CMake*, :CompileCommands, :FormatOnSave)
    project.lua             # Project root detection — one marker list, shared by everything below
    build.lua               # Build/run detection, async compile into the quickfix list
    cmake.lua               # CMake build type / target / preset, and target discovery via the file API
    compiledb.lua           # compile_commands.json generation for clangd
    venv.lua                # Python virtualenv resolution (pyright + debugpy + :Run)
    cfamily.lua             # Buffer-local C/C++ setup (include path, man pages)
    indent.lua              # Per-filetype indent widths (applied by after/ftplugin)
    servers.lua             # LSP servers to install/enable — single source of truth
    tools.lua               # Mason formatters/linters/debug adapters — single source of truth
    parsers.lua             # Treesitter parsers — single source of truth
  plugins/
    ui.lua                  # tokyonight, lualine, which-key, noice, trouble, indent guides
    editor.lua              # Treesitter + textobjects, matchup, autopairs, surround, grug-far, neogen, undotree
    explorer.lua            # nvim-tree (file explorer), aerial (symbols outline)
    telescope.lua           # Fuzzy finder
    lsp.lua                 # Mason, mason-lspconfig, native vim.lsp config, blink.cmp, snippets
    formatting.lua          # conform.nvim (clang-format, prettier, black, stylua, shfmt, cmake-format)
    linting.lua             # nvim-lint (markdownlint, yamllint); every other language is covered by its LSP
    dap.lua                 # nvim-dap + UI, codelldb + cpptools/gdb (C/C++), debugpy (Python), js-debug, bashdb
    testing.lua             # neotest + pytest / jest / vitest / gtest adapters
    git.lua                 # vim-fugitive, gitsigns
    terminal.lua            # toggleterm
    ai.lua                  # claudecode.nvim (Claude Code editor integration)
after/ftplugin/             # Per-filetype settings; applies lua/config/indent.lua
                            # (c.lua and cpp.lua additionally pull in config/cfamily.lua)
.stylua.toml                # Lua formatting (stylua defaults to tabs; this repo uses 2 spaces)
rpm/                        # Offline RPM build for air-gapped EL8 systems
  build-rpm.sh              # One-command builder (run on a connected EL8 host)
  nvim-config.spec          # RPM spec
  nvim-config-install       # Per-user activation script (ships in the RPM)
```

## Key Mappings

Leader key: `,`

### General

| Key | Action |
| :--- | :--- |
| `<leader>w` | Save buffer |
| `jk` | Exit insert mode |
| `<C-d>` / `<C-u>` | Scroll down / up (centered) |
| `n` / `N` | Next / prev search result (centered) |
| `<Esc>` | Clear search highlight |
| `<leader>t` | Toggle horizontal terminal |
| `<leader>u` | Toggle undo tree |

### Completion (blink.cmp)

| Key | Action |
| :--- | :--- |
| `<Tab>` / `<S-Tab>` | Select next / previous item, or jump between snippet fields |
| `<CR>` | Accept the selected item |
| `<Esc>` | Dismiss the menu (stays in insert mode) |
| `jk` | Leave insert mode, menu open or not |
| `<C-space>` | Show / toggle documentation |
| `<C-b>` / `<C-f>` | Scroll the documentation window |

Nothing is preselected, so `<CR>` only ever accepts something you chose with
`<Tab>` — a bare `<CR>` inserts a newline. `<Esc>` only swallows the keypress
while the menu is actually open; with it closed it leaves insert mode as usual.
`jk` is mapped `noremap` to a literal `<Esc>`, so it bypasses the completion
mapping entirely and does both in one press.

### Navigation

| Key | Action |
| :--- | :--- |
| `<C-h/j/k/l>` | Move between windows |
| `[b` / `]b` | Previous / next buffer |
| `[q` / `]q` | Previous / next quickfix item (wraps) |
| `[l` / `]l` | Previous / next location list item (wraps) |
| `<leader>xc` | Toggle the quickfix window |
| `<leader>n` | Toggle file explorer (nvim-tree) |
| `<leader>N` | Reveal current file in explorer |
| `<F8>` | Toggle symbols outline (aerial) |

The quickfix list is where compiler errors, test failures, grep results and LSP
references all land, so `]q` / `[q` are the motions that tie building, testing
and searching together. Both wrap rather than raising `E553` at the end.

### Text objects and movement (treesitter)

Defined against the parse tree, so they work the same in C, C++, Python, Lua,
JS/TS and every other configured language.

| Key | Object |
| :--- | :--- |
| `af` / `if` | A function (with signature) / its body |
| `ac` / `ic` | A class / its body |
| `aa` / `ia` | An argument or parameter |
| `ai` / `ii` | An if/else statement / its body |
| `al` / `il` | A loop / its body |
| `am` / `im` | A function call / its arguments |

Combine with any operator: `daf` deletes a function, `cia` changes an argument,
`vac` selects a class, `yif` yanks a function body.

| Key | Action |
| :--- | :--- |
| `]f` / `[f` | Next / previous function |
| `]F` / `[F` | Next / previous function end |
| `]]` / `[[` | Next / previous class |
| `<leader>sa` / `<leader>sA` | Swap parameter with the next / previous one |
| `<leader>sf` / `<leader>sF` | Swap function with the next / previous one |
| `%` | Jump between matching pairs, including `#if` / `#else` / `#endif`, `if`/`end`, `do`/`done`, and HTML tags (vim-matchup) |

`]c` / `[c` are deliberately left to gitsigns for hunk navigation.

### Telescope

| Key | Action |
| :--- | :--- |
| `<C-p>` / `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fd` | Diagnostics |
| `<leader>fs` | Document symbols (current file) |
| `<leader>fS` | Workspace symbols (whole project, via the LSP index) |
| `<leader>fw` | Grep the word under the cursor (or the visual selection) |
| `<leader>f/` | Fuzzy find inside the current buffer |
| `<leader>fc` | Changed files (git status) |
| `<leader>fp` | Resume the last picker, query intact |
| `<leader>fk` | Search keymaps |

`<leader>fS` asks the language server, not the filesystem — on a C or C++ tree
it is the fastest way to reach a function whose file you don't know.

Telescope is read-only — it finds matches but cannot change them. Project-wide
edits go through grug-far below.

### Search & Replace (grug-far)

Project-wide find and replace, backed by ripgrep. Opens a normal buffer: edit
the search/replace/files fields at the top, watch the live preview update, then
apply across every matching file.

| Key | Action |
| :--- | :--- |
| `<leader>rr` | Replace in project (also works on a visual selection) |
| `<leader>rw` | Replace word under cursor |
| `<leader>rf` | Replace in current file only |

Inside the results buffer:

| Key | Action |
| :--- | :--- |
| `<leader>ra` | Apply all replacements to disk |
| `<leader>rs` | Sync edited results back to their files |
| `<leader>rl` | Sync just the current line |
| `<leader>rq` | Send results to quickfix |
| `<leader>ru` | Refresh results |
| `<leader>rh` | Search history |
| `<leader>rx` | Toggle the replacement between literal text and Lua interpreter |
| `<leader>rm` | Show the underlying ripgrep command |
| `<leader>rc` | Close |
| `<enter>` | Jump to the match under the cursor |
| `g?` | Full keymap help |

Because `maplocalleader` is also `,`, grug-far's `<localleader><letter>`
defaults would collide with the leader namespace — `<localleader>r` is a prefix
of `<leader>rr`, and so on for `,l ,q ,c ,f ,x`. Each would stall for
`timeoutlen` inside a grug-far buffer, the same trap the `gr` defaults set under
LSP below. The colliding ones are remapped in `lua/plugins/editor.lua`;
everything else keeps its upstream default (see `g?`).

### Build & Run

| Key | Action |
| :--- | :--- |
| `<leader>bb` | Build the project (async, errors to quickfix) |
| `<leader>br` | Run the current file in a terminal split |
| `<leader>bd` | Build, then start debugging on success |
| `<leader>bc` | Build with a custom command (prefilled with the detected one) |
| `<leader>bk` | Stop the running build |
| `<leader>bt` | CMake: choose the build type (Debug / RelWithDebInfo / Release / MinSizeRel) |
| `<leader>bT` | CMake: choose which target to build |
| `<leader>bp` | CMake: choose a configure preset from `CMakePresets.json` |
| `<leader>bi` | CMake: show the active build type, target and build directory |

See [Building and running](#building-and-running) for what gets detected, and
[CMake projects](#cmake-projects) for the build type / target / preset model.

### LSP

| Key | Action |
| :--- | :--- |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gy` | Go to type definition |
| `gi` | Go to implementation |
| `gr` | Find references |
| `K` | Hover documentation |
| `<leader>rn` | Rename symbol |
| `<leader>a` | Code actions |
| `<leader>re` | Refactor |
| `<leader>lc` | CodeLens action |
| `<leader>lf` | Format buffer (manual; via conform) |
| `<leader>li` | Toggle inlay hints |
| `<leader>ld` | Generate a doc comment for the symbol below (neogen) |
| `<leader>lI` / `<leader>lO` | Incoming / outgoing calls (call hierarchy) |
| `<leader>lb` / `<leader>lB` | Base / derived types (type hierarchy) |
| `<leader>lh` | Switch source/header (C/C++, clangd) |
| `<leader>lg` | Generate `compile_commands.json` (C/C++) |
| `<leader>K` | Man page for the word under the cursor (C/C++) |
| `<leader>e` | Show line diagnostics |
| `<leader>xf` | Send diagnostics to location list |
| `[g` / `]g` | Prev / next diagnostic |

`gr` finds every textual reference; `<leader>lI` answers the narrower question
of what actually *calls* this, which is the one that matters when a name like
`init` has two hundred references. `<leader>lb`/`<leader>lB` answer the third
version of the question — what this type derives from, and what derives from it
— which in C++ is usually the one you actually want. `<leader>ld` writes the
comment skeleton in each language's own convention — doxygen for C/C++,
google-style docstrings for Python, JSDoc for JS/TS, LDoc for Lua.

`<leader>a` and `<leader>re` work in visual mode as well as normal. That is not
cosmetic: a code action over a *range* is how clangd offers "extract function"
and "extract variable", and neither is reachable from a normal-mode cursor.

Neovim ships its own `gr`-prefixed LSP mappings (`grr`, `grn`, `gra`, `gri`,
`grt`, and `grx` as of 0.12). Every one of them is rebound above, so the config
deletes them — otherwise `gr` would be a prefix of a live mapping and each press
would stall for `timeoutlen` (500 ms) waiting for a second key. `grx` is worth
calling out: it arrived with the 0.12 CodeLens rewrite, so upgrading Neovim
silently reintroduced that stall until it was added to the deletion list.

`<leader>lf` is a global mapping rather than an LSP one, so filetypes with a
formatter but no language server (yaml, scss, markdown) can still be formatted.
In visual mode it formats just the selection.

### Debugger (nvim-dap)

VSCode-style function keys for stepping, plus leader mappings for the rest.
The same keys drive every configured language: C/C++ (codelldb / gdb), Python
(debugpy), JS/TS and React (js-debug, node or Chrome), and Bash (bashdb).
`<F5>` lists every configuration that applies to the current filetype.

| Key | Action |
| :--- | :--- |
| `<F5>` | Continue / start |
| `<S-F5>` | Terminate |
| `<F9>` | Toggle breakpoint |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<S-F11>` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Run to cursor |
| `<leader>de` | Exception breakpoints (per-adapter list) |
| `<leader>dv` | Evaluate expression under cursor / selection |
| `<leader>du` | Toggle DAP UI |
| `<leader>dr` | Debug REPL |
| `<leader>dl` | Run last |
| `<leader>dt` | Terminate session |
| `<leader>dC` | Clear all breakpoints |

**Picking what to debug.** The C/C++ launch configurations never ask you to type
a path.

In a configured **CMake** project the list comes from CMake itself — the file
API reports which targets are executables and where each one's binary lands —
with the currently selected build target (`<leader>bT`) first. That beats
guessing: a filesystem sweep cannot tell a test fixture from the program, and it
happily offers stale binaries from a build directory that was renamed rather
than deleted.

Anything CMake does not account for — a hand-built binary, a Makefile or Cargo
project — still comes from the original scan of `build/`, `bin/`, `out/`,
`cmake-build-*/` and `target/debug/`, offered **newest first** since the binary
you just rebuilt is nearly always the one you want. Either way the last choice
for a project is remembered and floated to the top, and "Enter a path manually…"
is always the final entry. Each language also has a "with arguments" variant
that prompts for argv, so the common case stays a single keypress.

`<leader>bd` builds first and then starts the debugger, which is the pairing that
avoids stepping through source that no longer matches the binary.

**Language notes.**

- **C/C++** — codelldb (LLDB) is listed first on macOS, gdb via cpptools first on Linux; both stay available everywhere. Launches use an integrated terminal, so a program that reads stdin works.
- **Python** — debugpy runs from Mason's own venv, but the *debugged program* runs under the project's virtualenv (see [Python virtualenvs](#python-virtualenvs)). Without that split, every third-party import fails under the debugger only.
- **JS/TS** — node launch/attach, plus "Launch Chrome against dev server" for browser debugging. `.jsx` and `.tsx` are wired up too, which plain `javascript`/`typescript` configs miss.
- **Bash** — needs bash >= 4 (macOS ships 3.2; Homebrew's is used when present).

### Testing (neotest)

Runs whichever framework the project uses: pytest, jest, vitest, or gtest.
Failures show up as signs in the gutter and land in the quickfix list, so `]q`
walks them the same way it walks compiler errors.

| Key | Action |
| :--- | :--- |
| `<leader>Tr` | Run the nearest test |
| `<leader>Tf` | Run the current file |
| `<leader>Ta` | Run every test in the project |
| `<leader>Tl` | Run the last test again |
| `<leader>Td` | Debug the nearest test (breakpoints, DAP UI) |
| `<leader>Tk` | Stop the running test |
| `<leader>Ts` | Toggle the summary tree |
| `<leader>To` | Show output for the test under the cursor |
| `<leader>Tp` | Toggle the output panel |
| `<leader>Tw` | Watch the current file and re-run on change |
| `]t` / `[t` | Next / previous failed test |

`<leader>T` rather than `<leader>t`, which is already the terminal toggle.

C++ is the one language that cannot be auto-discovered: gtest tests are compiled
into a binary whose path only the build system knows, so it has to be recorded
once per project. `:ConfigureGtest` is a **buffer-local** command that only
exists inside the neotest summary window, not a global one:

1. `<leader>Ts` to open the summary tree.
2. Mark the test files or directories with `m`.
3. `:ConfigureGtest` in that window, and give it the path to the compiled test
   binary (`build/my_tests`).

The answer is stored per project, so this survives restarts.

### Claude (claudecode.nvim)

Connects the local `claude` CLI to Neovim with the same protocol as the official
VS Code extension: selection/file context, diagnostics, and native diff review.

| Key | Action |
| :--- | :--- |
| `<leader>cc` | Toggle Claude terminal |
| `<leader>cf` | Focus Claude |
| `<leader>cm` | Select model |
| `<leader>cb` | Add current file to context |
| `<leader>cs` | Send selection to Claude (visual) |
| `<leader>ca` / `<leader>cr` | Accept / reject proposed diff |

### Diagnostics (Trouble)

| Key | Action |
| :--- | :--- |
| `<leader>xx` | Project-wide diagnostics panel |
| `<leader>xb` | Current buffer diagnostics |
| `<leader>xs` | Symbols panel |
| `<leader>xq` | Quickfix list |
| `<leader>xl` | Location list |

### Session

| Key | Action |
| :--- | :--- |
| `<leader>qs` | Restore session for current directory |
| `<leader>ql` | Restore last session |
| `<leader>qd` | Don't save session on exit |

### Git

| Key | Action |
| :--- | :--- |
| `<leader>gs` | Git status |
| `<leader>gc` | Git commit |
| `<leader>gp` | Git push |
| `<leader>gl` | Git log |
| `<leader>gd` | Git diff |
| `<leader>gb` | Git blame |
| `]c` / `[c` | Next / prev hunk |
| `<leader>hs` / `<leader>hr` | Stage/unstage hunk (toggle) / reset hunk |
| `<leader>hS` / `<leader>hR` | Stage / reset whole buffer |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>hd` | Diff this file against the index |

## Building and running

`<leader>bb` builds, `<leader>br` runs. Neither needs a plugin or any per-project
setup, and both are implemented in `lua/config/build.lua`.

**Build** detects the project's build system by walking up from the current file:

| Marker | Command |
| :--- | :--- |
| `CMakeLists.txt` | `cmake` configure + build for the active profile — see [CMake projects](#cmake-projects) |
| `Makefile` | `make` |
| `Cargo.toml` | `cargo build` |
| `package.json` | `npm run build` |
| none, in a `.c`/`.cpp` file | `cc`/`c++` with `-Wall -Wextra -g` into the cache directory |

The build runs **asynchronously** — `:make` would freeze the editor for the
length of the compile — and its output is parsed with `errorformat` into the
quickfix list, so `]q` and `[q` walk the errors. On failure the quickfix window
opens without stealing the cursor; on success it closes and reports any
warnings. `<leader>bk` stops a build in progress.

The CMake line configures every time, which is a no-op once the cache exists.
That is deliberate: a fresh clone builds on the first `<leader>bb`, and
`compile_commands.json` stays in step with the build for clangd.

## CMake projects

CMake gets more than a fixed command line, because a fixed command line gets one
important thing wrong. `cmake -S . -B build && cmake --build build` configures
with **no** `CMAKE_BUILD_TYPE`, and on a single-config generator that leaves the
per-configuration flags empty — so the compiler runs without `-g` and the binary
carries no debug information at all. Breakpoints then never bind, which looks
like a broken debugger rather than a wrong build. Every IDE defaults to a Debug
configuration for this reason, and so does this config.

| Key | Command | What it sets |
| :--- | :--- | :--- |
| `<leader>bt` | `:CMakeBuildType [type]` | Debug (default), RelWithDebInfo, Release, MinSizeRel |
| `<leader>bT` | `:CMakeTarget [name]` | Build one target instead of everything (`all` clears it) |
| `<leader>bp` | `:CMakePreset` | A configure preset from `CMakePresets.json` |
| `<leader>bi` | `:CMakeStatus` | Shows the active profile and build directory |

Each choice is remembered **per project root** and persists across restarts
(`stdpath('state')/cmake-profiles.json`), so it is a rare trip rather than
something to set every session.

**Presets win when present.** `CMakePresets.json` is how a modern C++ project
shares one configuration between CI, the command line and every editor, so
selecting a preset hands it the build directory, the generator and the cache
variables; the build type above then no longer applies. Preset names come from
`cmake --list-presets`, so `hidden` presets and unmet `condition` blocks are
filtered out by CMake itself rather than by a second-guessing parser here.

**Targets come from the CMake file API**, not from parsing `--target help` —
that target does not exist under Ninja, and it cannot report where a target's
output lands. The file API does, which is what makes the debugger useful:
`<F5>` offers the executables CMake says the project produces, with the selected
target first, instead of sweeping the filesystem for anything executable. The
old scan is still there as the fallback for non-CMake projects and hand-built
binaries.

`<leader>bd` builds and then starts the debugger on success — the single
keypress an IDE's Debug button is. Debugging a binary you forgot to rebuild is
the classic way to lose ten minutes single-stepping through source that no
longer matches the machine code.

Multi-config generators (Ninja Multi-Config, Visual Studio) are handled too:
they choose the configuration at build time, so the config passes `--config`
instead of `CMAKE_BUILD_TYPE`, detected from `CMAKE_CONFIGURATION_TYPES` in the
cache.

**Run** executes the current file: `python3` (from the project venv), `node` or
`tsx`, `bash`, `nvim -l` for Lua, and for C/C++ a compile chained to the
resulting binary with `&&`. Output goes to a terminal split that is reused
across runs, with focus inside it so a program reading stdin is immediately
usable. Pressing `<leader>br` again from inside that terminal re-runs the last
command, rather than complaining that a terminal has no filetype.

`:Build <cmd>`, `:BuildStop` and `:Run` are the command-line equivalents.

## C/C++ project setup

clangd needs a `compile_commands.json` — the record of how each file is actually
compiled, with its `-I` paths, `-D` defines and language standard. Without one
it has to guess, and the guess fails in the most visible way possible: every
project header reports as "file not found", so completion, go-to-definition and
diagnostics all quietly degrade at once.

Neither cmake nor make writes that file by default. `:CompileCommands` picks the
right way to produce it for the current project and restarts clangd:

| Project | What it does |
| :--- | :--- |
| CMake | Runs the same configure `<leader>bb` uses (so the two never fight over the cache), then symlinks `compile_commands.json` from the build directory to the project root |
| Makefile | Runs `bear -- make -B` to observe a full rebuild and record every compile |
| Anything else | Writes a `.clangd` with fallback include paths and a language standard **probed from the compiler** |

`:CompileCommands!` skips detection and writes the `.clangd` fallback directly.
`<leader>lg` is the same thing on a key. A symlink is used rather than a copy so
it stays correct as the build directory is regenerated.

The generated `.clangd` scopes its `-std` by file extension, using `If:
PathMatch:` fragments. A bare `CompileFlags.Add` reaches every file the server
opens, C and C++ alike, so a project-wide `-std=c++20` puts `Invalid argument
'-std=c++20' not allowed with 'C'` on line 1 of every `.c` in the tree. For the
same reason the built-in fallback in `lua/plugins/lsp.lua` is only `-Wall
-Wextra`, with no `-std` at all — one clangd process serves both languages.

**Cross-compiling?** clangd finds a toolchain's system headers by *running* the
compiler named in `compile_commands.json`, but only for drivers allow-listed
with `--query-driver`, which is empty by default. Point it at an ARM or vendor
GCC build without that and every `#include <...>` reports as missing while the
same tree compiles cleanly — the most confusing clangd failure in embedded work.
Set it per project (see [Project-local configuration](#project-local-configuration)):

```lua
vim.g.clangd_query_driver = "/opt/toolchains/**/arm-none-eabi-*"
```

`$CLANGD_QUERY_DRIVER` works too. It is a comma-separated glob list and it
executes whatever it matches, so keep it as narrow as the toolchain needs.

Other C/C++ specifics:

- `gf` on an `#include` works — `include/`, `inc/`, `src/` and `lib/` under the project root are added to `path`, along with the system include directories.
- `K` is LSP hover; `<leader>K` opens the man page for the word under the cursor, trying section 3 then 2. Two different questions, two different keys.
- `<leader>lh` switches between source and header (a clangd extension).
- Comments default to `//` rather than `/* */`, so `gcc`/`gc` can comment out a region containing a block comment.
- Background indexing is limited to half the available cores at low priority; on a large tree, indexing on all cores makes the editor unusable while it runs.

## Python virtualenvs

pyright and debugpy both default to whatever `python3` is first on `$PATH`,
which is almost never the interpreter a project's dependencies are installed
into. The failure is quiet rather than loud: imports resolve as missing, types
degrade to `Unknown`, and the debugger runs the wrong interpreter.

`lua/config/venv.lua` walks up from the project root looking for `.venv`,
`venv`, `.env` or `env` (an activated `$VIRTUAL_ENV` wins over all of them) and
feeds the result to pyright, debugpy, neotest's pytest runner, and `<leader>br`.
No plugin, no `fd`, nothing to configure — so it behaves identically on the
air-gapped hosts.

## The project root

Builds, `:CompileCommands`, the debugger's executable picker, `<leader>Ta`, the
C/C++ `path`, and virtualenv lookup all need to know where the current project
starts, and they all ask `lua/config/project.lua` — one marker list, so they
cannot disagree with each other:

```text
compile_commands.json, CMakeLists.txt, Makefile, makefile,
package.json, Cargo.toml, pyproject.toml, setup.py, .git
```

The search walks **up from the file you are editing**, not from the directory
Neovim was started in, and stops at the first ancestor containing any marker
(`:help vim.fs.root`). In a monorepo that means `services/api/main.py` gets
`services/api`, and the cwd is only used when nothing matches. Editing a file
outside the current project therefore builds, debugs and tests the project that
file belongs to.

## Project-local configuration

`exrc` is enabled, so Neovim reads a `.nvim.lua` from the directory it was
started in. Neovim 0.11+ asks once per file before running it and remembers the
answer, so an untrusted repo cannot execute anything silently.

```lua
-- .nvim.lua in a project root
vim.g.build_cmd = "ninja -C out/debug"        -- overrides <leader>bb detection
vim.g.run_cmd   = "./out/debug/server --config dev.toml"
vim.g.gdb_path  = "/opt/toolchain/bin/arm-none-eabi-gdb"  -- used by the DAP configs
vim.g.clangd_query_driver = "/opt/toolchain/bin/arm-none-eabi-*"  -- see C/C++ setup
```

`.nvim.lua` is sourced before the first buffer is read, so settings the LSP
configuration consults — `clangd_query_driver` among them — are in place by the
time the server starts.

Debug configurations can also come from a `.vscode/launch.json`, which nvim-dap
reads automatically.

## Formatting

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim) and is **manual** — there is no format-on-save. Format the current buffer with `<leader>lf`.

`:FormatOnSave` toggles automatic formatting for the session, for projects with
a CI formatting gate where forgetting once costs a round trip.

| Filetype | Formatter |
| :--- | :--- |
| C / C++ | `clang-format` |
| CMake | `cmake-format` |
| Python | `black`, `isort` |
| JS / TS / HTML / CSS / JSON / YAML / Markdown | `prettier` |
| Lua | `stylua` |
| Shell | `shfmt` |

Indent widths in `lua/config/indent.lua` are kept in step with what these
formatters actually emit, so hand-written and formatted code agree. Both
`stylua` and `shfmt` default to **hard tabs**, so they are pinned to spaces —
`shfmt` via `-i 2` in `lua/plugins/formatting.lua`, `stylua` via `.stylua.toml`
(which, being a project file, only governs this repo).

### C/C++ style

The default C/C++ style lives in `lua/plugins/formatting.lua` (not in a global `~/.clang-format`): **K&R braces, 4-space indent, 120-column limit**. If a project provides its own `.clang-format`, conform detects it and uses that file instead (`--style=file`) — so per-project overrides just work by adding a `.clang-format` to the project.

## Linting

Each language is linted by exactly one thing, and wherever possible that thing
is its language server — because a server can offer a **quick fix** for what it
reports, which a standalone linter cannot.

| Language | Linter | Runs as |
| :--- | :--- | :--- |
| C / C++ | clang-tidy | inside clangd |
| Python | ruff | LSP server |
| Shell | shellcheck | spawned by bashls |
| JS / TS | eslint | LSP server (`<leader>a` → "fix all auto-fixable problems") |
| Markdown | markdownlint | nvim-lint |
| YAML | yamllint | nvim-lint |

Only the last two have no language server, which is the entire reason
`nvim-lint` is still installed. The eslint server attaches only where an eslint
config exists, so projects without one see nothing.

Both of those two are toned down, because their stock rules duplicate the
formatter and drown out everything else — markdownlint's default put 58
line-length errors on this README, yamllint's put 5 on the workflow file in this
repo. prettier owns the layout of both filetypes and will not rewrap prose, so
line-length (`MD013`, `line-length`), `document-start` and the `truthy` reading
of GitHub Actions' `on:` key are switched off. Everything a formatter cannot
fix — unlabelled code fences, duplicate keys, bad indentation, syntax errors —
still reports.

A project that ships its own `.markdownlint.*` or `.yamllint*` takes over
completely, the same way a project `.clang-format` does. The file is located by
walking up from the buffer, so it is found even when Neovim was started outside
the project.

## Plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim).

| Plugin | Purpose |
| :--- | :--- |
| `folke/tokyonight.nvim` | Colorscheme (night style) |
| `folke/trouble.nvim` | Project-wide diagnostics panel |
| `folke/persistence.nvim` | Session save/restore per working directory |
| `nvim-lualine/lualine.nvim` | Status line |
| `folke/noice.nvim` | Floating command line popup and notification UI |
| `rcarriga/nvim-notify` | Toast notifications (used by noice) |
| `MunifTanjim/nui.nvim` | UI component library (used by noice) |
| `folke/which-key.nvim` | Keybinding hints |
| `lukas-reineke/indent-blankline.nvim` | Indent guides |
| `folke/todo-comments.nvim` | TODO/FIXME highlighting |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting and folding (C, C++, Python, JS, TS, ASM, …) |
| `nvim-treesitter/nvim-treesitter-context` | Sticky function/class context |
| `nvim-treesitter/nvim-treesitter-textobjects` | Function/class/parameter text objects, movement, swapping |
| `andymass/vim-matchup` | `%` over `#if`/`#endif`, `if`/`end`, `do`/`done`, HTML tags |
| `windwp/nvim-autopairs` | Auto-close brackets and quotes |
| `RRethy/vim-illuminate` | Highlights all uses of the word under cursor |
| `kylechui/nvim-surround` | Surround motions |
| `danymat/neogen` | Doc comment generation (doxygen, docstrings, JSDoc, LDoc) |
| `mbbill/undotree` | Undo history browser |
| `nvim-tree/nvim-tree.lua` | File explorer |
| `stevearc/aerial.nvim` | LSP-powered symbols outline |
| `nvim-telescope/telescope.nvim` | Fuzzy finder |
| `MagicDuck/grug-far.nvim` | Project-wide search and replace (ripgrep) |
| `mason-org/mason.nvim` | LSP/tool installer |
| `mason-org/mason-lspconfig.nvim` | Bridges Mason with native `vim.lsp` config (Neovim 0.11+) |
| `saghen/blink.cmp` | Completion engine (built-in snippets, cmdline completion, auto-brackets) |
| `b0o/schemastore.nvim` | JSON schema catalog for jsonls |
| `stevearc/conform.nvim` | Formatting — clang-format (C/C++), cmake-format, prettier, black/isort, stylua, shfmt |
| `mfussenegger/nvim-lint` | Linting for markdown and yaml; every other language is linted by its LSP |
| `mfussenegger/nvim-dap` | Debug adapter protocol |
| `rcarriga/nvim-dap-ui` | Debug UI |
| `mfussenegger/nvim-dap-python` | Python debug adapter (debugpy) |
| `nvim-neotest/neotest` | Test runner UI, quickfix integration, debug-a-test |
| `neotest-python` / `-jest` / `-vitest` / `-gtest` | Framework adapters (pytest, jest, vitest, gtest) |
| `codelldb` / `cpptools` (Mason) | C/C++ debug adapters — LLDB (local macOS) and gdb/gdbserver (Linux) |
| `js-debug-adapter` (Mason) | JavaScript / TypeScript debug adapter |
| `bash-debug-adapter` (Mason) | Bash debug adapter (bashdb; needs bash >= 4) |
| `tpope/vim-fugitive` | Git commands |
| `lewis6991/gitsigns.nvim` | Git gutter signs and hunk actions |
| `akinsho/toggleterm.nvim` | Horizontal split terminal |
| `coder/claudecode.nvim` | Claude Code editor integration (selection context, native diffs) |
