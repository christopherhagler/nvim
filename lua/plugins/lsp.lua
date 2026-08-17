return {
  -- Mason: installs and manages LSP servers
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
      },
    },
  },

  -- Completion engine (Rust fuzzy matcher; built-in snippets, cmdline, auto-brackets)
  {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = {
        -- 'enter' preset: <CR> accept, <C-space> show/toggle docs, <C-e> hide,
        -- <C-b>/<C-f> scroll docs
        preset = "enter",
        ["<Tab>"]   = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        -- Dismiss the menu with <Esc> instead of the preset's <C-e>. "hide"
        -- only fires while the menu is open and swallows the key; with the
        -- menu closed it falls through, so <Esc> still leaves insert mode
        -- normally. To bail out of both at once, `jk` is mapped noremap to a
        -- literal <Esc> (lua/config/keymaps.lua), so it bypasses this mapping
        -- and leaves insert mode in one press even with the menu up.
        ["<Esc>"] = { "hide", "fallback" },
      },
      completion = {
        -- Don't preselect: <CR> only accepts after an explicit <Tab> selection
        list = { selection = { preselect = false, auto_insert = true } },
        menu = { border = "rounded" },
        documentation = { auto_show = true, window = { border = "rounded" } },
        -- Auto-insert () after accepting a function/method completion
        accept = { auto_brackets = { enabled = true } },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- LSP: installation + native Neovim 0.11+ configuration.
  -- nvim-lspconfig is data-only here: it ships the lsp/<server>.lua base configs
  -- (cmd, filetypes, root markers) that vim.lsp.config/vim.lsp.enable build on.
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
      { "b0o/schemastore.nvim", lazy = true },
      { "j-hui/fidget.nvim",  opts = {} },
      { "folke/lazydev.nvim", ft = "lua", opts = {} },
    },
    config = function()
      -- Install and enable servers (list: lua/config/servers.lua, which
      -- rpm/build-rpm.sh reads directly when baking the offline payload)
      local servers = require("config.servers")
      require("mason-lspconfig").setup({
        ensure_installed = servers,
        -- Enable exactly these, rather than the default "every installed Mason
        -- package whose name matches an lspconfig server". That default also
        -- catches formatters: `stylua` has a `stylua --lsp` entry in
        -- nvim-lspconfig, so installing it for conform silently started a
        -- second, redundant server on every Lua buffer.
        automatic_enable = servers,
      })

      -- Neovim ships gr-prefixed LSP defaults, and we rebind every one of them
      -- below (gr, <leader>rn, <leader>a, gi, gy). Leaving any in place makes
      -- every `gr` press wait out 'timeoutlen' to see whether a second key
      -- follows — half a second of dead air on the most-used LSP mapping there
      -- is.
      --
      -- grx is the trap: 0.11 shipped grr/grn/gra/gri/grt, and 0.12 added grx
      -- (vim.lsp.codelens.run) with the codeLens rewrite. Upgrading silently
      -- reintroduced the stall this loop exists to prevent. `gra` is also
      -- mapped in Visual mode, where <leader>a now covers the same ground.
      for _, lhs in ipairs({ "grr", "grn", "gra", "gri", "grt", "grx" }) do
        pcall(vim.keymap.del, "n", lhs)
      end
      pcall(vim.keymap.del, "x", "gra")

      -- Diagnostic appearance
      vim.diagnostic.config({
        virtual_text    = { prefix = "●" },
        signs           = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.HINT]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
          },
        },
        update_in_insert = false,
        underline       = true,
        severity_sort   = true,
        float           = { border = "rounded", source = true },
      })

      -- Buffer-local LSP setup.
      --
      -- This is an LspAttach autocmd rather than an on_attach passed to
      -- vim.lsp.config("*") for a reason: nvim-lspconfig ships its own
      -- lsp/<server>.lua files, and several of them (clangd, pyright, ts_ls)
      -- define an on_attach of their own. Per-server config wins the merge, so
      -- a global on_attach is silently dropped for exactly those servers —
      -- which left C/C++, Python and TS/JS with none of the mappings below.
      -- LspAttach cannot be overridden by a server config.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
        callback = function(ev)
          local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
          local bufnr = ev.buf
          local map = function(keys, func, desc, mode)
            vim.keymap.set(mode or "n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
          end

          -- ruff and pyright both attach to Python buffers. ruff owns linting
          -- and quick fixes; silence its hover so K always comes from pyright.
          if client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          -- Navigation
          map("gd", vim.lsp.buf.definition,    "Go to definition")
          map("gD", vim.lsp.buf.declaration,   "Go to declaration")
          map("gy", vim.lsp.buf.type_definition, "Go to type definition")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gr", function() require("telescope.builtin").lsp_references() end, "Find references")
          map("K",  vim.lsp.buf.hover,         "Hover documentation")

          -- Actions
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          -- Visual mode as well as normal: a code action over a *range* is how
          -- clangd offers "extract function" and "extract variable", which are
          -- the two refactorings that only make sense on a selection. Without
          -- the visual binding they were unreachable except through the stock
          -- `gra` that the block above deletes.
          map("<leader>a", vim.lsp.buf.code_action, "Code actions", { "n", "v" })
          map("<leader>re", function()
            vim.lsp.buf.code_action({ context = { only = { "refactor" } } })
          end, "Refactor", { "n", "v" })
          -- Guarded like the type-hierarchy pair below: clangd has no CodeLens,
          -- so leaving this bound on a C++ buffer only offers a key that
          -- answers "not supported by any server".
          if client:supports_method("textDocument/codeLens") then
            map("<leader>lc", vim.lsp.codelens.run, "CodeLens action")
          end

          -- Call hierarchy: "who calls this?" / "what does this call?".
          -- gr answers it textually; these answer it structurally, which is
          -- the difference that matters in a C codebase where a name like
          -- `init` has 200 references and four of them are calls.
          map("<leader>lI", function() require("telescope.builtin").lsp_incoming_calls() end, "Incoming calls")
          map("<leader>lO", function() require("telescope.builtin").lsp_outgoing_calls() end, "Outgoing calls")

          -- Type hierarchy: the class-tree half of the same question. "What
          -- derives from this interface" is answered by neither gr (textual)
          -- nor the call hierarchy, and in C++ it is usually the one you want.
          if client:supports_method("textDocument/typeHierarchy") then
            map("<leader>lb", function() vim.lsp.buf.typehierarchy("supertypes") end, "Base types")
            map("<leader>lB", function() vim.lsp.buf.typehierarchy("subtypes") end, "Derived types")
          end
          -- <leader>lf (format) is global — see lua/config/keymaps.lua. conform
          -- formats plenty of filetypes that have no LSP server attached.

          -- Diagnostics
          map("[g",          function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
          map("]g",          function() vim.diagnostic.jump({ count =  1, float = true }) end, "Next diagnostic")
          map("<leader>xf",  vim.diagnostic.setloclist, "Diagnostics to location list")

          -- Inlay hints and CodeLens are the only two features here that talk to
          -- the server without being asked, so they are the two that can fail in
          -- the user's face. Both are gated on the buffer having a real file://
          -- URI: a :Gdiffsplit buffer is still filetype cpp, so clangd attaches
          -- to it, but the first inlayHint request against fugitive:// comes
          -- back "-32602: clangd only supports 'file' URI scheme for workspace
          -- files" — an error you did nothing to provoke and can do nothing
          -- about. Hover and go-to-definition stay mapped there; those only
          -- complain when you actually press them.
          local is_file = vim.uri_from_bufnr(bufnr):sub(1, 7) == "file://"

          -- Inlay hints (inline parameter names / inferred types), on by default
          if client:supports_method("textDocument/inlayHint") then
            if is_file then vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end
            map("<leader>li", function()
              vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
                { bufnr = bufnr }
              )
            end, "Toggle inlay hints")
          end

          -- C/C++: jump between source and header (clangd extension)
          if client.name == "clangd" then
            map("<leader>lh", function()
              client:request("textDocument/switchSourceHeader",
                { uri = vim.uri_from_bufnr(bufnr) },
                function(err, result)
                  if err or not result then
                    vim.notify("No matching source/header file", vim.log.levels.WARN)
                    return
                  end
                  vim.cmd.edit(vim.uri_to_fname(result))
                end, bufnr)
            end, "Switch source/header")
          end

          -- CodeLens: managed capability on 0.12+ (refreshes itself on changes)
          if is_file and client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.enable(true, { bufnr = bufnr })
          end
        end,
      })

      -- Global defaults applied to every LSP server. Only 'capabilities' is
      -- safe to set here: it is a table, so it deep-merges with each server's
      -- own config instead of being replaced wholesale the way a function is.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Per-server overrides
      --
      -- Cross-compilation: clangd learns a toolchain's system header paths by
      -- *running* the compiler named in compile_commands.json, but only for
      -- drivers matched by --query-driver, which is empty by default. Point an
      -- ARM or vendor GCC build at clangd without it and every #include <...>
      -- reports "file not found" while the same tree compiles cleanly — the
      -- single most confusing clangd failure in embedded work. Set it per
      -- project from a .nvim.lua (sourced before the first buffer is read, so
      -- it is in place by the time this runs):
      --
      --   vim.g.clangd_query_driver = "/opt/toolchains/**/arm-none-eabi-*"
      --
      -- It is a comma-separated glob list, and it executes what it matches, so
      -- keep it as narrow as the toolchain actually needs.
      local clangd_cmd = {
        "clangd",
        "--background-index",
        -- Indexing every translation unit on all cores makes a large project
        -- unresponsive while it runs. Half the cores keeps the editor usable.
        "-j=" .. math.max(1, math.floor((vim.uv.available_parallelism() or 4) / 2)),
        "--background-index-priority=low",
        "--clang-tidy",
        "--header-insertion=iwyu",
        "--completion-style=detailed",
        "--function-arg-placeholders=true",
        -- Complete symbols that aren't visible yet and add the #include for
        -- them — the main reason to prefer clangd over ctags in a big tree.
        "--all-scopes-completion",
        -- Preambles in RAM rather than /tmp: measurably faster completion,
        -- and avoids filling a small /tmp on the RHEL boxes.
        "--pch-storage=memory",
      }

      local query_driver = vim.g.clangd_query_driver or vim.env.CLANGD_QUERY_DRIVER
      if query_driver then
        table.insert(clangd_cmd, "--query-driver=" .. query_driver)
      end

      vim.lsp.config("clangd", {
        cmd = clangd_cmd,
        -- Without a compile_commands.json, clangd has to guess how each file is
        -- compiled and reports every project header as missing. These flags are
        -- the guess it uses until :CompileCommands generates the real thing
        -- (lua/config/compiledb.lua).
        --
        -- No -std here, deliberately: fallbackFlags are passed to every file the
        -- server opens, C and C++ alike, and one clangd process serves both
        -- filetypes in a mixed project. A -std=c++20 in this list puts "Invalid
        -- argument '-std=c++20' not allowed with 'C'" on line 1 of every .c file
        -- that has no compile command. Raising the standard is per-language, so
        -- it belongs in a .clangd file — which is what :CompileCommands! writes.
        init_options = {
          fallbackFlags = { "-Wall", "-Wextra" },
        },
      })

      vim.lsp.config("pyright", {
        -- Resolve the project's virtualenv before the server starts. Without
        -- this, pyright type-checks against whatever python3 is on $PATH, so
        -- every dependency installed in a .venv reads as a missing import.
        before_init = function(_, config)
          local python = require("config.venv").python(config.root_dir)
          if python then
            config.settings.python.pythonPath = python
          end
        end,
        settings = {
          python = {
            analysis = {
              typeCheckingMode       = "basic",
              autoSearchPaths        = true,
              useLibraryCodeForTypes = true,
              inlayHints = {
                variableTypes        = true,
                functionReturnTypes  = true,
                callArgumentNames    = true,
              },
            },
          },
        },
      })

      -- JSON validation/completion from the SchemaStore catalog
      -- (package.json, tsconfig.json, GitHub Actions, etc.)
      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas  = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace   = { checkThirdParty = false },
            telemetry   = { enable = false },
          },
        },
      })

      vim.lsp.config("eslint", {
        settings = {
          -- Monorepos run eslint from the nearest package dir, not the repo
          -- root, so relative plugin/config paths resolve the way the project's
          -- own `npx eslint` would.
          workingDirectories = { mode = "auto" },
        },
      })

      -- Emmet is an abbreviation expander, not a diagnostics source: it only
      -- ever contributes completion items, so it sits alongside html/cssls
      -- and ts_ls without either fighting it.
      vim.lsp.config("emmet_language_server", {
        filetypes = {
          "html", "css", "scss", "less",
          "javascript", "javascriptreact", "typescript", "typescriptreact",
        },
      })
    end,
  },
}
