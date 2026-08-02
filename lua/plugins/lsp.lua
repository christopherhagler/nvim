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

      -- Neovim 0.11+ ships gr-prefixed LSP defaults (grr/grn/gra/gri/grt).
      -- We rebind all of them below (gr, <leader>rn, <leader>a, gi, gy), and
      -- leaving them in place would make every `gr` press wait out 'timeoutlen'
      -- to see whether a second key follows.
      for _, lhs in ipairs({ "grr", "grn", "gra", "gri", "grt" }) do
        pcall(vim.keymap.del, "n", lhs)
      end

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
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
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
          map("<leader>a",  vim.lsp.buf.code_action, "Code actions")
          map("<leader>re", function()
            vim.lsp.buf.code_action({ context = { only = { "refactor" } } })
          end, "Refactor")
          map("<leader>lc", vim.lsp.codelens.run, "CodeLens action")
          -- <leader>lf (format) is global — see lua/config/keymaps.lua. conform
          -- formats plenty of filetypes that have no LSP server attached.

          -- Diagnostics
          map("[g",          function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
          map("]g",          function() vim.diagnostic.jump({ count =  1, float = true }) end, "Next diagnostic")
          map("<leader>xf",  vim.diagnostic.setloclist, "Diagnostics to location list")

          -- Inlay hints (inline parameter names / inferred types), on by default
          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
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
          if client:supports_method("textDocument/codeLens") then
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
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders=true",
        },
      })

      vim.lsp.config("pyright", {
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
    end,
  },
}
