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
| `[q` / `]q` / `<leader>xq` | Previous / next quickfix item / toggle list |
| `[l` / `]l` / `<leader>xl` | Previous / next location list item / toggle list |
| `<leader>xd` | Send diagnostics to the location list |
| `<leader>xQ` / `<leader>xL` | Quickfix / location list in Trouble |
| `<leader>gs` / `<leader>gd` | Git status / diff |
| `]c` / `[c` / `<leader>hp` | Next / previous Git hunk / preview hunk |
| `<leader>hs` | Stage or unstage hunk |
| `<C-\>` / `<leader>T` | Toggle terminal |
| `<C-\><C-\>` | Hide terminal, from terminal mode |
| `<Esc><Esc>` | Leave terminal mode (in Claude's terminal, `<C-\><C-n>`) |
| `<C-h/j/k/l>` | Move between windows |
| `<C-\>h/j/k/l` | Move between windows, from terminal mode (`<C-h/j/k/l>` stay with the program) |
| `<leader>w` / `jk` | Save / leave insert mode |
| `<leader>,` | Repeat `f` / `t` backward (`,` is the leader) |
| `<F8>` / `<leader>o` / `<leader>u` | Toggle outline (both keys) / undo tree |

Completion: `<Tab>` / `<S-Tab>` select an item or move between snippet fields; `<CR>` accepts a selected item. Nothing is preselected. `<Esc>` dismisses the menu; `jk` leaves insert mode.

## Everyday Vim

Stock Vim keys you will reach for daily. Yanks and deletes go to the system clipboard.

**Open two files side by side**

| Key | Action |
| :--- | :--- |
| `:vs path/to/file` | Open a file in a split on the right (`:sp` opens below) |
| `<leader>ff`, type a name, `<C-v>` | Open the picked file on the right (`<C-x>` below, `<C-t>` in a new tab) |
| `<leader>n`, move to a file, `<C-v>` | Open it from the explorer on the right (`<C-x>` below, `<C-t>` in a new tab) |
| `<C-w>v` / `<C-w>s` | Split the current window right / below |
| `<C-h/j/k/l>` | Move between the windows |
| `:vs other_file`, then `:windo diffthis` | Compare the two files; `:diffoff!` ends it (`:diffsplit other_file` opens and compares in one step) |

**Windows, tabs, and files**

| Key | Action |
| :--- | :--- |
| `<C-w>q` / `<C-w>o` | Close this window / close all the others |
| `<C-w>x` | Swap this window with the next one |
| `<C-w>=` | Make windows equal size |
| `<C-w>\|` / `<C-w>_` | Maximize width / height |
| `5<C-w>>` / `5<C-w><` | Wider / narrower by 5 columns |
| `2<C-w>+` / `2<C-w>-` | Taller / shorter by 2 lines |
| `:tabnew file` / `gt` / `gT` / `:tabclose` | New tab / next / previous / close |
| `<C-^>` | Jump back to the previous file |
| `]b` / `[b` | Next / previous buffer |
| `:bd` | Close the current file |
| `gf` / `gx` | Open the file path / URL under the cursor |
| `:w` / `:wa` / `:q` / `:qa` | Save / save all / close window / quit |

**Select, copy, and paste**

| Key | Action |
| :--- | :--- |
| `ggVG` | Select all (`<C-a>` increments a number; it is not select all) |
| `ggVGy` or `:%y` | Copy the whole file |
| `ggdG` | Delete the whole file's contents |
| `v` / `V` / `<C-v>` | Select characters / lines / a block |
| `viw` / `vi(` / `vi"` | Select a word / inside parentheses / inside quotes |
| `gv` | Reselect the last selection |
| `<C-v>`, move, `I`, type, `<Esc>` | Insert the same text on several lines |
| `yy` / `dd` / `p` / `P` | Copy line / cut line / paste after / paste before |
| `y` / `d` / `c` on a selection | Copy / cut / replace it |
| `"_d` | Delete without overwriting the clipboard |

**Edit**

| Key | Action |
| :--- | :--- |
| `u` / `<C-r>` | Undo / redo |
| `.` | Repeat the last change |
| `ciw` / `ci"` / `ci(` | Replace a word / inside quotes / inside parentheses |
| `gcc` / `gc` on a selection | Toggle comment on a line / the selection |
| `>>` / `<<` | Indent / outdent a line (`>` / `<` keep a selection selected) |
| `gg=G` | Reindent the file (`<leader>lf` formats it) |
| `J` | Join the next line onto this one |
| `gUiw` / `guiw` | Uppercase / lowercase a word |
| `<C-a>` / `<C-x>` | Increment / decrement the number under the cursor |
| `]<Space>` / `[<Space>` | Add a blank line below / above |
| `ysiw"` / `cs"'` / `ds'` | Surround a word with `"` / change `"` to `'` / remove `'` |
| `S)` on a selection | Surround the selection with parentheses |
| `qa` ... `q` / `@a` / `@@` | Record macro `a` / play it / play it again |
| `:%s/old/new/gc` | Replace in this file, confirming each (`<leader>rr` for the project) |
| `gi` | Return to the last insert position |
| `<C-w>` in insert mode | Delete the previous word |

**Move and search**

| Key | Action |
| :--- | :--- |
| `gg` / `G` / `42G` | First line / last line / line 42 |
| `w` / `b` / `0` / `$` | Next word / previous word / line start / line end |
| `<C-d>` / `<C-u>` | Half a page down / up, centered |
| `%` | Jump to the matching bracket |
| `<C-o>` / `<C-i>` | Back / forward through jump history |
| `ma` / `'a` | Set mark `a` / jump to it |
| `/text` / `n` / `N` | Search / next / previous, centered |
| `*` / `#` | Search for the word under the cursor, forward / backward |
| `<Esc>` | Clear search highlight |
| `<M-n>` / `<M-p>` | Next / previous reference to the symbol under the cursor (Alt/Option must send Meta in your terminal) |
| `zc` / `zo` / `za` | Close / open / toggle a fold |
| `zM` / `zR` | Close / open all folds |

## Navigate and edit

| Key | Action |
| :--- | :--- |
| `gD` / `gy` / `gI` | Go to declaration / type definition / implementation |
| `]f` / `[f` | Next / previous function start |
| `]F` / `[F` | Next / previous function end |
| `]k` / `[k` | Next / previous class |
| `]]` / `[[` | Next / previous `{` in the first column, Vim's C function jump |
| `a` or `i` + `f` `c` `a` `i` `l` `m` | Around / inside function, class, parameter, conditional, loop, call (`daf`, `vic`) |
| `ih` | Inside Git hunk |
| `<leader>sa` / `<leader>sA` | Swap parameter with next / previous |
| `<leader>sf` / `<leader>sF` | Swap function with next / previous |
| `<leader>ld` | Generate doc comment |
| `<leader>re` | Refactor actions, on the cursor or a selection |
| `<leader>K` | Man page for the word under the cursor (C/C++/CUDA) |
| `<leader>rr` / `<leader>rw` / `<leader>rf` | Replace in project / word under cursor / current file (`<leader>rr` also takes a selection) |
| `<leader>ra` | Apply replacements, inside the replace window |
| `<leader>qs` / `<leader>ql` / `<leader>qd` | Restore this directory's session / restore last session / don't save on exit |
| `<leader>L` | Redraw the screen and update diffs |

## Search, Git, and language tools

**Find**

| Key | Action |
| :--- | :--- |
| `<C-p>` / `<leader>ff` | Files |
| `<leader>fg` / `<leader>fw` | Project text / word or selection |
| `<leader>f/` | Text in this file |
| `<leader>fb` / `<leader>fr` / `<leader>fc` | Open buffers / recent files / changed files |
| `<leader>fs` / `<leader>fS` | Symbols in this file / workspace |
| `<leader>fd` | Diagnostics |
| `<leader>fh` / `<leader>fk` | Help / keymaps |
| `<leader>fp` | Reopen the last picker |

**Git**

| Key | Action |
| :--- | :--- |
| `<leader>gs` / `<leader>gd` / `<leader>gl` | Status / diff / log |
| `<leader>gc` / `<leader>gp` | Commit / push |
| `<leader>gb` / `<leader>gB` | Blame the file / this line |
| `]c` / `[c` | Next / previous hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hs` / `<leader>hr` | Stage or unstage / reset a hunk or selection |
| `<leader>hS` / `<leader>hR` | Stage / reset the whole buffer |

**Diagnostics and lists**

| Key | Action |
| :--- | :--- |
| `<leader>e` | Show this line's diagnostics |
| `<leader>xx` / `<leader>xb` | Diagnostics in Trouble, for the project / this buffer |
| `<leader>xq` / `<leader>xQ` | Quickfix list, raw / in Trouble |
| `<leader>xl` / `<leader>xL` | Location list, raw / in Trouble |
| `<leader>xd` | Send diagnostics to the location list |

**Language**

| Key | Action |
| :--- | :--- |
| `<leader>lf` | Format buffer or selection |
| `<leader>lI` / `<leader>lO` | Incoming / outgoing calls |
| `<leader>lb` / `<leader>lB` | Base / derived types, where the server supports them |
| `<leader>li` / `<leader>lc` | Toggle inlay hints / run CodeLens, where the server supports them |
| `<leader>lh` / `<leader>lg` | Switch source and header (clangd) / set up the compile database (C/C++/CUDA) |

## Build and run

| Key | Action |
| :--- | :--- |
| `<leader>bb` | Build project |
| `<leader>br` | Run current file |
| `<leader>bd` | Build, then debug on success |
| `<leader>bc` | Choose this project's build command (remembered) |
| `<leader>bT` | Choose the target to build (CMake or Make) |
| `<leader>bt` / `<leader>bp` | Choose the CMake build type / configure preset |
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

Start or continue debugging with `<F5>` or `<leader>dc`; use `<leader>bd` to build first. C/C++ offers an executable picker. Project `.vscode/launch.json` configurations are loaded automatically.

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
| `<leader>dr` / `<leader>de` / `<leader>dl` | Debug REPL / exception breakpoints / rerun last session |
| `<leader>tr` / `<leader>tf` / `<leader>ta` | Run nearest test / file / project |
| `<leader>td` / `<leader>tl` | Debug nearest test / rerun last test |
| `<leader>ts` / `<leader>to` / `<leader>tp` | Test summary / test output / output panel |
| `<leader>tk` / `<leader>tw` | Stop running test / watch file |
| `]x` / `[x` | Next / previous failed test |

Debugging supports C/C++, CUDA, Python, MATLAB, JS/TS, and Bash. C/C++ uses LLDB on macOS and gdb on Linux. Leader mappings also work when your terminal captures function keys.

Tests use pytest, Jest, Vitest, or Google Test. For Google Test, open the summary (`<leader>ts`), mark test files/directories with `m`, then run `:ConfigureGtest` **inside that window** and select the compiled test binary. The choice persists per project.

### Python

Language tools, runs, debugging, and pytest share the detected project interpreter. Activate a virtualenv/Conda environment or create `.venv`, `venv`, `.env`, or `env` in the project. Run `:VenvRefresh` after creating or changing an environment during a session.

### MATLAB

With MATLAB installed, code runs in the persistent session managed by the language server:

- `<leader>br` or `<leader>mr` runs the file; `<leader>ms` runs a `%%` section or visual selection; `<leader>ml` runs the line. `]]` / `[[` move between `%%` sections.
- `<leader>mc` opens the command window; `<leader>mk` interrupts; `<leader>mo` toggles output.
- `<leader>mf` exports figures to PNG; `<leader>mx` closes all figures; `<F5>` starts debugging.
- `<leader>mh` shows help for the word under the cursor; `<leader>mw` lists workspace variables; `<leader>mp` reruns project path setup.

Project paths load from a custom `matlab_setup` command, a script chosen with `:MatlabSetup path/to/script.m` (or `<leader>mP` in that script; remembered per project, `:MatlabSetup!` forgets it), a root `.prj`, or a root `startup.m` or `start.m`. Use `:MatlabSetup` to reload them and `:Matlab <code>` to evaluate code. Run MATLAB tests with `runtests` in the command window. Without MATLAB, Octave can run scripts; full language and debugging features require MATLAB.

## Claude Code

With the `claude` CLI installed, Claude sees your open files, selection, and diagnostics, and proposes edits as diffs in Neovim.

| Key | Action |
| :--- | :--- |
| `<leader>cc` / `<leader>cf` | Toggle / focus Claude |
| `<leader>cb` / `<leader>cs` | Add current file / send selection |
| `<leader>cy` / `<leader>cn` | Accept / reject proposed diff |
| `<leader>cm` | Select model |

## Keys inside plugin windows

Press `q` to close help, man pages, quickfix, Trouble, and the outline. `g?` lists the keys in the explorer, Git status, and project replace windows; `?` does in the test summary.

**File picker**

| Key | Action |
| :--- | :--- |
| `<CR>` | Open here |
| `<C-v>` / `<C-x>` / `<C-t>` | Open on the right / below / in a new tab |
| `<C-j>` / `<C-k>` | Next / previous result |
| `<Tab>` | Mark a result |
| `<C-q>` | Send marked results, or all results if none are marked, to quickfix |
| `<Esc>` | Close |

**File explorer**

| Key | Action |
| :--- | :--- |
| `<CR>` | Open file or folder |
| `<C-v>` / `<C-x>` / `<C-t>` | Open on the right / below / in a new tab |
| `a` / `r` / `d` | Create (end with `/` for a folder) / rename / delete |
| `x` / `c` / `p` | Cut / copy / paste |
| `y` / `Y` | Copy name / relative path |
| `-` | Go up a folder |
| `H` / `I` | Toggle dotfiles / Git-ignored files |
| `f` / `F` | Filter / clear filter |
| `R` / `q` | Refresh / close |

**Git status (`<leader>gs`)**

| Key | Action |
| :--- | :--- |
| `s` / `u` | Stage / unstage the file under the cursor |
| `=` | Show or hide its diff inline |
| `dv` | Open its diff in a split |
| `cc` | Commit |
| `gq` | Close (`q` starts recording a macro here) |

**Test summary (`<leader>ts`)**

| Key | Action |
| :--- | :--- |
| `r` / `d` | Run / debug the test under the cursor |
| `m` / `R` / `M` | Mark / run marked / clear marks |
| `o` / `O` | Show full / short output |
| `i` | Jump to the test |
| `J` / `K` | Next / previous failed test |
| `w` / `u` | Watch / stop |
| `<CR>` / `e` | Expand / expand all |

**Project replace (`<leader>rr`)**

The window opens in insert mode; press `<Esc>` before these keys.

| Key | Action |
| :--- | :--- |
| `<leader>ra` | Apply all replacements |
| `\j` / `\k` | Apply next / previous |
| `<leader>rs` / `<leader>rl` | Save edits made in the results to their files / this line only |
| `\v` / `\n` / `\p` | Save edits for this file / next / previous |
| `<leader>rq` | Send results to quickfix |
| `<leader>ru` / `\b` | Refresh / abort |
| `<leader>rh` / `\a` | Open history / add to history |
| `<leader>rx` / `\e` | Swap replacement interpreter / search engine |
| `<leader>rm` | Show the search command |
| `\i` / `\o` | Preview / open the result under the cursor |
| `<leader>rc` | Close |

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
