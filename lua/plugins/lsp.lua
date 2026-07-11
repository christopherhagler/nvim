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
      -- Install servers
      -- NOTE: mirrored (as mason package names) in rpm/build-rpm.sh for the
      -- offline RPM; the build script fails if the counts drift.
      require("mason-lspconfig").setup({
        ensure_installed = {
          "clangd",   -- C/C++
          "pyright",  -- Python
          "ts_ls",    -- TypeScript/JavaScript
          "html",     -- HTML
          "cssls",    -- CSS
          "jsonls",   -- JSON
          "lua_ls",   -- Lua (for editing this config)
          "bashls",   -- Bash/Shell
        },
      })

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

      local on_attach = function(client, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
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
        map("<leader>lf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, "Format buffer")

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
      end

      -- Global defaults applied to every LSP server
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
        on_attach    = on_attach,
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
