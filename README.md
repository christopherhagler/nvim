# Neovim Configuration

A Lua-first Neovim setup targeting C/C++, Python, and web development. Uses `lazy.nvim` for plugin management, native LSP for language intelligence, and `nvim-dap` for debugging.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [File Structure](#file-structure)
- [Key Mappings](#key-mappings)
- [Formatting](#formatting)
- [Plugins](#plugins)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/christopherhagler/nvim/development/setup.sh | bash
```

This downloads and runs `setup.sh`, which checks your dependencies, backs up any existing config, clones the repo, and installs all plugins automatically.

## Prerequisites

- **Neovim** >= 0.11.0 (0.12.x recommended) — native `vim.lsp` config requires 0.11+
- **Git**
- **ripgrep** — live grep in Telescope
- **make** — required to build the telescope-fzf-native extension
- **A C/C++ compiler** (clang recommended; clangd is installed automatically via Mason)
- **Node.js** — for TypeScript/JavaScript LSP, prettier, and the JS debug adapter
- **Python 3** — for pyright and debugpy

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
| `./setup.sh health` | Check tool availability and run `:checkhealth` |
| `./setup.sh backup` | Snapshot current config to a timestamped backup |
| `./setup.sh restore` | Restore a previous backup |

### Manual install

1. ```bash
   git clone https://github.com/christopherhagler/nvim.git ~/.config/nvim
   ```
2. Open Neovim — `lazy.nvim` bootstraps and installs all plugins on first launch.
3. Run `:Mason` to install LSP servers, formatters, linters, and debug adapters.

## File Structure

```
init.lua                    # Entry point — lazy.nvim bootstrap
lua/
  config/
    options.lua             # Core Neovim options
    keymaps.lua             # Global key mappings
    autocmds.lua            # Autocommands (whitespace trim, yank highlight, etc.)
  plugins/
    ui.lua                  # tokyonight, lualine, which-key, noice, trouble, indent guides
    editor.lua              # Treesitter, autopairs, Comment.nvim, surround
    explorer.lua            # nvim-tree (file explorer), aerial (symbols outline)
    telescope.lua           # Fuzzy finder
    lsp.lua                 # Mason, mason-lspconfig, native vim.lsp config, nvim-cmp, snippets
    formatting.lua          # conform.nvim (clang-format, prettier, black, stylua, shfmt)
    linting.lua             # nvim-lint (flake8, eslint_d, shellcheck)
    dap.lua                 # nvim-dap + UI, codelldb + cpptools/gdb (C/C++), debugpy (Python)
    git.lua                 # vim-fugitive, gitsigns
    terminal.lua            # toggleterm
    ai.lua                  # claudecode.nvim (Claude Code editor integration)
after/ftplugin/             # Per-language indentation settings
  asm.lua, c.lua, cpp.lua, python.lua, javascript.lua, typescript.lua, sh.lua
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
| `<leader>t` | Toggle floating terminal |

### Navigation

| Key | Action |
| :--- | :--- |
| `<C-h/j/k/l>` | Move between windows |
| `[b` / `]b` | Previous / next buffer |
| `<leader>n` | Toggle file explorer (nvim-tree) |
| `<leader>N` | Reveal current file in explorer |
| `<F8>` | Toggle symbols outline (aerial) |

### Telescope

| Key | Action |
| :--- | :--- |
| `<C-p>` / `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fd` | Diagnostics |
| `<leader>fs` | Document symbols |

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
| `<leader>lh` | Switch source/header (C/C++, clangd) |
| `<leader>e` | Show line diagnostics |
| `<leader>xf` | Send diagnostics to location list |
| `[g` / `]g` | Prev / next diagnostic |

### Debugger (nvim-dap)

VSCode-style function keys for stepping, plus leader mappings for the rest.

| Key | Action |
| :--- | :--- |
| `<F5>` | Continue / start |
| `<S-F5>` | Terminate |
| `<F9>` | Toggle breakpoint |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<S-F11>` | Step out |
| `<leader>dB` | Conditional breakpoint |
| `<leader>du` | Toggle DAP UI |
| `<leader>dr` | Debug REPL |
| `<leader>dl` | Run last |

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
| `<leader>hs` / `<leader>hr` | Stage / reset hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |

## Formatting

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim) and is **manual** — there is no format-on-save. Format the current buffer with `<leader>lf`.

| Filetype | Formatter |
| :--- | :--- |
| C / C++ | `clang-format` |
| Python | `black`, `isort` |
| JS / TS / HTML / CSS / JSON / YAML | `prettier` |
| Lua | `stylua` |
| Shell | `shfmt` |

### C/C++ style

The default C/C++ style lives in `lua/plugins/formatting.lua` (not in a global `~/.clang-format`): **K&R braces, 4-space indent, 120-column limit**. If a project provides its own `.clang-format`, conform detects it and uses that file instead (`--style=file`) — so per-project overrides just work by adding a `.clang-format` to the project.

## Plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim).

| Plugin | Purpose |
| :--- | :--- |
| `folke/tokyonight.nvim` | Colorscheme (moon style) |
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
| `windwp/nvim-autopairs` | Auto-close brackets and quotes |
| `numToStr/Comment.nvim` | `gcc` / `gc` commenting |
| `RRethy/vim-illuminate` | Highlights all uses of the word under cursor |
| `kylechui/nvim-surround` | Surround motions |
| `nvim-tree/nvim-tree.lua` | File explorer |
| `stevearc/aerial.nvim` | LSP-powered symbols outline |
| `nvim-telescope/telescope.nvim` | Fuzzy finder |
| `williamboman/mason.nvim` | LSP/tool installer |
| `williamboman/mason-lspconfig.nvim` | Bridges Mason with native `vim.lsp` config (Neovim 0.11+) |
| `hrsh7th/nvim-cmp` | Completion engine |
| `L3MON4D3/LuaSnip` | Snippet engine |
| `stevearc/conform.nvim` | Formatting — clang-format (C/C++), prettier, black/isort, stylua, shfmt |
| `mfussenegger/nvim-lint` | Linting (flake8, eslint_d, shellcheck) |
| `mfussenegger/nvim-dap` | Debug adapter protocol |
| `rcarriga/nvim-dap-ui` | Debug UI |
| `mfussenegger/nvim-dap-python` | Python debug adapter (debugpy) |
| `codelldb` / `cpptools` (Mason) | C/C++ debug adapters — LLDB (local macOS) and gdb/gdbserver (Linux) |
| `js-debug-adapter` (Mason) | JavaScript / TypeScript debug adapter |
| `tpope/vim-fugitive` | Git commands |
| `lewis6991/gitsigns.nvim` | Git gutter signs and hunk actions |
| `akinsho/toggleterm.nvim` | Floating terminal |
| `coder/claudecode.nvim` | Claude Code editor integration (selection context, native diffs) |
