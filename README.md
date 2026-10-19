# Neovim Configuration

A Lua-based Neovim setup for C/C++, CUDA, Python, MATLAB, shell, and web development. Includes completion, language servers, formatting, project builds, debugging, tests, and Git integration.

## Install

Supports macOS and Linux, including RHEL/Rocky. Install these prerequisites first:

- Neovim **0.12+**, Git, ripgrep, make, a C compiler, and unzip.
- **tree-sitter CLI 0.26+** for syntax parsers (package manager or `cargo install tree-sitter-cli`).
- Node.js and Python 3 for language tools.
- On Linux: `gdb` for C/C++ debugging; a clipboard tool such as `wl-clipboard` or `xclip` for desktop use. SSH uses OSC 52 for copying.

Then run:

```bash
curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh -o setup.sh
bash setup.sh install
nvim
```

The installer checks dependencies, backs up an existing config, and installs plugins, parsers, and language tools. Keep `setup.sh` for `update`, `health`, `backup`, and `restore` commands.

For a manual install, back up any existing `~/.config/nvim`, clone this repository there, and open Neovim. Tools install in the background on first launch.

Additional tools depend on your projects: CMake **3.14+**, `bear` for Makefile compile databases, a C++ compiler for C++, CUDA toolkit for CUDA builds/debugging, MATLAB R2021b+ for full MATLAB support, and Bash **4+** for shell debugging. Install test frameworks in each project.

On RHEL/Rocky 8, use a Neovim build compatible with glibc 2.28. On Linux ARM64, install `clangd` through the system package manager (`clang-tools-extra` on RHEL/Rocky).

## Essential shortcuts

The leader key is **`,`**: `<leader>ff` means press `,ff`. Pause after the leader to see available mappings, or use `<leader>fk` to search all keymaps.

| Key | Action |
| :--- | :--- |
| `<C-p>` / `<leader>ff` | Find project files |
| `<leader>fg` / `<leader>fw` | Search project text / word or selection |
| `<leader>fb` | Switch buffers |
| `<leader>n` / `<leader>N` | Toggle explorer / reveal current file |
| `<leader>fs` / `<leader>fS` | Find symbols in the file / workspace |
| `gd` / `gr` / `K` | Definition / references / documentation |
| `<leader>rn` / `<leader>a` | Rename symbol / code actions |
| `<leader>lf` | Format buffer or selection |
| `[d` / `]d` / `<leader>e` | Previous / next diagnostic / show message |
| `[e` / `]e` | Previous / next error (skips warnings) |
| `<leader>xx` | Open project diagnostics |
| `[q` / `]q` / `<leader>xc` | Previous / next quickfix item / toggle list |
| `<leader>gs` / `<leader>gd` | Git status / diff |
| `]c` / `[c` / `<leader>hp` | Next / previous Git hunk / preview hunk |
| `<leader>hs` | Stage or unstage hunk |
| `<C-\>` / `<leader>tt` | Toggle terminal (from terminal mode, `<Esc><Esc>` first) |
| `<Esc><Esc>` | Leave terminal mode (in Claude's terminal, `<C-\><C-n>`) |
| `<C-h/j/k/l>` | Move between windows (in a terminal, `<C-h>` / `<C-j>` only; `<C-k>` / `<C-l>` stay with the shell) |
| `<leader>w` / `jk` | Save / leave insert mode |

Completion: `<Tab>` / `<S-Tab>` select an item or move between snippet fields; `<CR>` accepts a selected item. Nothing is preselected. `<Esc>` dismisses the menu; `jk` leaves insert mode.

## Build and run

| Key | Action |
| :--- | :--- |
| `<leader>bb` | Build project |
| `<leader>br` | Run current file |
| `<leader>bd` | Build, then debug on success |
| `<leader>bc` | Choose this project's build command (remembered) |
| `<leader>bT` | Choose the target to build (CMake or Make) |
| `<leader>bi` | Show exactly what `<leader>bb` runs, and why |
| `<leader>bk` | Stop build |

`<leader>bb` runs, in order: the command remembered for this project, a `build_cmd` from its [`.nvim.lua`](#project-configuration), or what its files indicate: CMake, Make, Cargo, or an npm build script. Standalone C/C++ files compile with debug symbols. Builds run asynchronously and send errors and warnings to quickfix; use `[q` / `]q` to navigate them. Runs use a terminal split.

Projects build differently, so `<leader>bc` lists the commands built in this project before, or lets you edit one (`make image ARCH=arm64`, `./build.sh release`, …). The one you pick is built and becomes this project's `<leader>bb`; choose **Reset to auto-detect** to undo. `<leader>bT` in a Make project lists the Makefile's targets, including those from included makefiles and those that depend on variables in the current command, and remembers the pick the same way.

`:Build image` appends to the project's command, like `:make image`, and completes Make targets with `<Tab>`. `:Build make clean` (same program) or `:Build! ./other.sh` runs a different command once. `:Run` and `:BuildStop` match `<leader>br` and `<leader>bk`.

Make runs in parallel (`-j` with all cores) unless `MAKEFLAGS` sets the jobs, with `--output-sync` so recursive output stays in order. On macOS install GNU make 4+ (`brew install make`, used as `gmake`); `/usr/bin/make` 3.81 lacks output sync. For a Makefile that is not parallel-safe, remember plain `make` with `<leader>bc`. The project root is the topmost Makefile in the repository, so building from `drivers/foo.c` in a kernel-style tree builds the whole tree.

For CMake, choose a build type with `<leader>bt`, target with `<leader>bT`, or configure preset with `<leader>bp`. Until you choose a build type, a build directory you configured yourself keeps its own, and a new one uses Debug. Presets control their own configuration. Choices persist per project.

### C/C++ and CUDA

clangd needs each project's include paths and compiler flags. For CMake, `<leader>bb` sets this up: the first build links `compile_commands.json` to the project root and restarts clangd, so go-to-definition and diagnostics work from then on. To set it up without building, or for other build systems, run `:CompileCommands` (or `<leader>lg`):

- **CMake:** configure the project and link its `compile_commands.json` to the project root.
- **Make:** run a full rebuild of the project's own build command (target and variables included) through `bear` to record compiler commands.
- **Other projects:** generate a fallback `.clangd` file.

Use `<leader>lh` to switch between source and header. Project `.clang-format` files override the default C/C++ style (K&R braces, four spaces, 120 columns).

CUDA editing uses clangd and clang-format. Building requires `nvcc`; kernel debugging requires `cuda-gdb` on Linux. The toolkit is detected from `$CUDA_HOME`, `nvcc` on `$PATH`, or `/usr/local/cuda*`.

## Debug and test

Start debugging with `<F5>` or `<leader>dc`; use `<leader>bd` to build first. C/C++ offers an executable picker. Project `.vscode/launch.json` configurations are loaded automatically.

| Key | Action |
| :--- | :--- |
| `<F9>` / `<leader>db` | Toggle breakpoint |
| `<F10>` / `<leader>dn` | Step over |
| `<F11>` / `<leader>di` | Step into |
| `<S-F11>` / `<F12>` / `<leader>do` | Step out |
| `<leader>dk` / `<leader>dj` / `<leader>dh` | Stack frame up / down / hover value |
| `<S-F5>` / `<leader>dt` | Terminate |
| `<leader>dB` / `<leader>dx` | Conditional breakpoint / clear all breakpoints |
| `<leader>dC` / `<leader>dp` | Run to cursor / pause |
| `<leader>dv` / `<leader>du` | Evaluate expression / toggle debug UI |
| `<leader>tr` / `<leader>tf` / `<leader>ta` | Run nearest test / file / project |
| `<leader>td` / `<leader>tl` | Debug nearest test / rerun last test |
| `<leader>ts` / `<leader>to` | Test summary / test output |
| `]x` / `[x` | Next / previous failed test |

Debugging supports C/C++, CUDA, Python, MATLAB, JS/TS, and Bash. C/C++ uses LLDB on macOS and gdb on Linux. Leader mappings also work when your terminal captures function keys.

Tests use pytest, Jest, Vitest, or Google Test. For Google Test, open the summary (`<leader>ts`), mark test files/directories with `m`, then run `:ConfigureGtest` **inside that window** and select the compiled test binary. The choice persists per project.

### Python

Language tools, runs, debugging, and pytest share the detected project interpreter. Activate a virtualenv/Conda environment or create `.venv`, `venv`, `.env`, or `env` in the project. Run `:VenvRefresh` after creating or changing an environment during a session.

### MATLAB

With MATLAB installed, code runs in the persistent session managed by the language server:

- `<leader>br` runs the file; `<leader>ms` runs a `%%` section or visual selection; `<leader>ml` runs the line.
- `<leader>mc` opens the command window; `<leader>mk` interrupts; `<leader>mo` toggles output.
- `<leader>mf` exports figures to PNG; `<F5>` starts debugging.

Project paths load from a custom `matlab_setup` command, a script chosen with `:MatlabSetup path/to/script.m` (or `<leader>mP` in that script; remembered per project, `:MatlabSetup!` forgets it), a root `.prj`, or a root `startup.m` or `start.m`. Use `:MatlabSetup` to reload them and `:Matlab <code>` to evaluate code. Run MATLAB tests with `runtests` in the command window. Without MATLAB, Octave can run scripts; full language and debugging features require MATLAB.

## Claude Code

With the `claude` CLI installed, Claude sees your open files, selection, and diagnostics, and proposes edits as diffs in Neovim.

| Key | Action |
| :--- | :--- |
| `<leader>cc` / `<leader>cf` | Toggle / focus Claude |
| `<leader>cb` / `<leader>cs` | Add current file / send selection |
| `<leader>cy` / `<leader>cn` | Accept / reject proposed diff |
| `<leader>cm` | Select model |

## Project configuration

Builds, searches, and test runs use the current buffer's project root. Roots are detected from build/package files or `.git`; nested CMake projects use the topmost CMake project within the repository.

Start Neovim in the project directory to load its `.nvim.lua`. Neovim asks you to trust the file before running it.

```lua
-- .nvim.lua
require("config.project").setup({
  build_cmd = "ninja -C out/debug",
  run_cmd = "./out/debug/server --config dev.toml",
  -- gdb_path = "/opt/toolchain/bin/arm-none-eabi-gdb",
  -- clangd_query_driver = "/opt/toolchain/bin/arm-none-eabi-*",
  -- matlab_setup = "run('tools/setup_paths.m')",
  -- notrim = true,
})
```

Settings apply per project. Opening a different project's file does not load its `.nvim.lua`; register its overrides explicitly with `setup(options, absolute_root)`.

Formatting is manual by default; `:FormatOnSave` toggles it for the session. Project formatter and linter configuration files take precedence. Trailing whitespace is trimmed on save, except in Markdown, patches, and commit messages. Use `:TrimToggle` for the current buffer, `:TrimToggle!` for the session, or `notrim = true` above for a project.

## Offline install

For air-gapped RHEL/Rocky, download an RPM from the **Build offline RPM** GitHub Actions workflow, or build one on a connected host with [`rpm/build-rpm.sh`](rpm/build-rpm.sh). Use the EL8 build for EL8/9 (requires Python 3.11), and the EL10 build for EL10 (requires Python 3.12).

```bash
sudo dnf install ./nvim-config-<version>-1.el8.x86_64.rpm
nvim-config-install
exec bash -l
nvim
```

Run `nvim-config-install` once per user. After upgrading the RPM, rerun it to activate the packaged configuration and tools.

## Customize and troubleshoot

- [`lua/config/keymaps.lua`](lua/config/keymaps.lua): core shortcuts; plugin shortcuts live in [`lua/plugins/`](lua/plugins/).
- [`lua/config/options.lua`](lua/config/options.lua): editor settings.
- [`lua/config/servers.lua`](lua/config/servers.lua), [`tools.lua`](lua/config/tools.lua), and [`parsers.lua`](lua/config/parsers.lua): installed language servers, tools, and parsers.
- `:checkhealth` or `bash setup.sh health`: diagnose missing dependencies.
- `:Mason`: inspect installed language tools; `:Lazy`: inspect plugins.
- `bash tests/run.sh`: run this configuration's regression checks with Neovim 0.12+.
