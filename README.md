# Neovim Configuration Readme

This repository contains a modular and robust Neovim configuration. It is built around the Lua-first ecosystem, leveraging `coc.nvim` for a powerful IDE-like experience, `telescope.nvim` for fuzzy finding, and `lualine.nvim` for a modern status line.

## Table of Contents

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [File Structure](#file-structure)
* [Key Mappings](#key-mappings)
    * [General](#general)
    * [File Management](#file-management)
    * [Window Navigation](#window-navigation)
    * [Telescope](#telescope)
    * [CoC (Code completion / LSP)](#coc-code-completion--lsp)
    * [Language-Specific (Compile & Run)](#language-specific-compile--run)
* [Plugins](#plugins)

## Prerequisites

* **Neovim** >= 0.5.0
* **Git**
* **Node.js** (required for `coc.nvim`)
* **ripgrep** (required for `telescope.nvim`'s live grep)
* **ctags** (for tag generation)
* A **C/C++ compiler** (gcc, g++, clang) for C/C++ support

## Installation

1.  **Backup your existing configuration:**
    ```bash
    mv ~/.config/nvim ~/.config/nvim.bak
    mv ~/.local/share/nvim ~/.local/share/nvim.bak
    ```

2.  **Clone this repository:**
    ```bash
    git clone [https://your-repository-url.git](https://your-repository-url.git) ~/.config/nvim
    ```

3.  **Install Plugins:**
    Open Neovim. The configuration will automatically install `vim-plug` and then all configured plugins.
    ```bash
    nvim
    ```
    If it doesn't happen automatically, run:
    ```vim
    :PlugInstall
    ```

4.  **Install CoC Extensions:**
    After plugins are installed, install the necessary Language Server Protocol (LSP) extensions for CoC:
    ```vim
    :CocInstall coc-pyright coc-tsserver coc-json coc-html coc-css coc-sh coc-java coc-clangd
    ```
    *Note: You may be prompted to install language servers (like `clangd` or `jdt.ls`). Say "yes".*

## File Structure

* **`init.vim`**: The entry point for the configuration. It loads all other modules.
* **`lua/`**: Contains the core Lua configuration files.
    * `options.lua`: General Neovim options and settings.
    * `plugins.lua`: Plugin definitions using `vim-plug`.
    * `mappings.lua`: Global key mappings.
    * `plugin_config/`: Configuration for specific plugins.
        * `lualine.lua`: Configuration for the status line.
* **`after/ftplugin/`**: Language-specific configurations loaded automatically by filetype.
    * `c.lua`, `cpp.lua`, `python.lua`, `java.lua`, `javascript.lua`, `typescript.lua`, `sh.lua`.

## Key Mappings

The leader key is set to **`<Space>`**.

### General

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `<leader>w` | `:w<CR>` | Save buffer |
| `jk` (in insert mode) | `<Esc>` | Exit insert mode |
| `<C-d>` | `<C-d>zzzv` | Scroll down and center |
| `<C-u>` | `<C-u>zzzv` | Scroll up and center |
| `n` | `nzzzv` | Next search result and center |
| `N` | `Nzzzv` | Previous search result and center |
| `<leader>t` | *custom* | Generate ctags for the project |

### File Management

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `<leader>n` | `:NERDTreeToggle<CR>` | Toggle NERDTree file explorer |
| `<F8>` | `:TagbarToggle<CR>` | Toggle Tagbar outline |

### Window Navigation

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `<C-h>` | `<C-w>h` | Navigate left |
| `<C-j>` | `<C-w>j` | Navigate down |
| `<C-k>` | `<C-w>k` | Navigate up |
| `<C-l>` | `<C-w>l` | Navigate right |

### Telescope

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `<leader>ff` | `:Telescope find_files<CR>` | Find files |
| `<leader>fg` | `:Telescope live_grep<CR>` | Live grep in files |
| `<leader>fb` | `:Telescope buffers<CR>` | List open buffers |
| `<leader>fh` | `:Telescope help_tags<CR>` | Search help tags |

### CoC (Code completion / LSP)

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `<TAB>` (in insert mode) | | Next completion item |
| `<S-TAB>` (in insert mode) | | Previous completion item |
| `gd` | `<Plug>(coc-definition)` | Go to definition |
| `gy` | `<Plug>(coc-type-definition)` | Go to type definition |
| `gi` | `<Plug>(coc-implementation)` | Go to implementation |
| `gr` | `<Plug>(coc-references)` | Find references |
| `K` | `:call CocActionAsync('doHover')` | Show documentation hover |
| `<leader>rn` | `<Plug>(coc-rename)` | Rename symbol |
| `[g` | `<Plug>(coc-diagnostic-prev)` | Previous diagnostic |
| `]g` | `<Plug>(coc-diagnostic-next)` | Next diagnostic |
| `<leader>a` | `<Plug>(coc-codeaction-selected)`| Code action for selection |
| `<leader>ac` | `<Plug>(coc-codeaction-cursor)` | Code action at cursor |
| `<leader>qf` | `<Plug>(coc-fix-current)` | Quickfix action |
| `<leader>re` | `<Plug>(coc-codeaction-refactor)`| Refactor |

### Language-Specific (Compile & Run)

These mappings are available only in their respective filetypes.

| Keymap | C | C++ | Java | Python | Javascript | Typescript | Bash |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `<leader>x` | Run `./%:r` | Run `./%:r` | Run `java %:r` | Run with `python3` | Run with `node` | Run with `ts-node` | Run with `bash` |
| `<leader>c` | Compile with `gcc` | Compile with `g++` | Compile with `javac` | Run `pytest` | Run local `eslint` | Run local `eslint` | Run local `shellcheck` |

## Plugins

Core plugins are managed via `vim-plug`.

* **`coc.nvim`**: Intellisense engine, full LSP support.
* **`telescope.nvim`**: Highly extendable fuzzy finder.
* **`lualine.nvim`**: A blazing fast and easy to configure statusline.
* **`nerdtree`**: A file system explorer.
* **`vim-fugitive`**: A Git wrapper so awesome, it should be illegal.
* **`which-key.nvim`**: Displays available keybindings in popup.
* **`vim-sensible`**: Defaults everyone can agree on.
* **`vim-airline-themes`**: Themes for airline (used by lualine).
* **`vimspector`**: A multi-language debugging system.
* **`fzf.vim`**: FZF integration for Neovim.
* **`tagbar`**: Displays tags of the current file in a sidebar.
* **`vim-devicons`**: Adds file type icons to plugins.
* **`vim-gutentags`**: Manages tag files automatically.
* **`vim-jinja`**: Jinja2 template support.
