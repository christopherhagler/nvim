return {
  -- Mason: installs and manages LSP servers, DAP adapters, linters, formatters
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
      },
    },
  },

  -- Bridges mason with nvim-lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "clangd",       -- C/C++
        "pyright",      -- Python
        "ts_ls",        -- TypeScript/JavaScript
        "html",         -- HTML
        "cssls",        -- CSS
        "jsonls",       -- JSON
        "lua_ls",       -- Lua (for editing this config)
        "bashls",       -- Bash/Shell
        "asm_lsp",      -- Assembly
      },
      automatic_installation = true,
    },
  },

  -- Completion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      { "L3MON4D3/LuaSnip", build = "make install_jsregexp" },
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          -- TAB / S-TAB to navigate completions (mirrors CoC behaviour)
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500 },
          { name = "path",     priority = 250 },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" }, { name = "cmdline" } }),
        matching = { disallow_symbol_nonprefix_matching = false },
      })
    end,
  },

  -- LSP servers
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      { "j-hui/fidget.nvim", opts = {} },         -- LSP progress notifications
      { "folke/lazydev.nvim", ft = "lua", opts = {} }, -- Lua LS for nvim config
    },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Diagnostic appearance
      vim.diagnostic.config({
        virtual_text = { prefix = "●" },
        signs = true,
        update_in_insert = false,
        underline = true,
        severity_sort = true,
        float = { border = "rounded", source = "always" },
      })

      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

      vim.lsp.handlers["textDocument/hover"] =
        vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
      vim.lsp.handlers["textDocument/signatureHelp"] =
        vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

      local on_attach = function(client, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
        end

        -- Navigation (mirrors CoC bindings)
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("gy", vim.lsp.buf.type_definition, "Go to type definition")
        map("gi", vim.lsp.buf.implementation, "Go to implementation")
        map("gr", require("telescope.builtin").lsp_references, "Find references")
        map("K", vim.lsp.buf.hover, "Hover documentation")

        -- Actions
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>a", vim.lsp.buf.code_action, "Code actions")
        map("<leader>ac", vim.lsp.buf.code_action, "Code action at cursor")
        map("<leader>re", function()
          vim.lsp.buf.code_action({ context = { only = { "refactor" } } })
        end, "Refactor")
        map("<leader>cl", vim.lsp.codelens.run, "CodeLens action")
        map("<leader>qf", vim.diagnostic.setloclist, "Quickfix diagnostics")
        map("<leader>lf", function()
          vim.lsp.buf.format({ async = true })
        end, "Format buffer")

        -- Diagnostics
        map("[g", vim.diagnostic.goto_prev, "Prev diagnostic")
        map("]g", vim.diagnostic.goto_next, "Next diagnostic")

        -- Aerial integration
        require("aerial").on_attach(client, bufnr)

        -- CodeLens refresh if supported
        if client.supports_method("textDocument/codeLens") then
          vim.lsp.codelens.refresh()
          vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
            buffer = bufnr,
            callback = vim.lsp.codelens.refresh,
          })
        end
      end

      require("mason-lspconfig").setup_handlers({
        -- Default handler
        function(server_name)
          lspconfig[server_name].setup({
            capabilities = capabilities,
            on_attach = on_attach,
          })
        end,

        -- clangd: enable background indexing and clang-tidy
        ["clangd"] = function()
          lspconfig.clangd.setup({
            capabilities = capabilities,
            on_attach = on_attach,
            cmd = {
              "clangd",
              "--background-index",
              "--clang-tidy",
              "--header-insertion=iwyu",
              "--completion-style=detailed",
              "--function-arg-placeholders",
            },
          })
        end,

        -- pyright
        ["pyright"] = function()
          lspconfig.pyright.setup({
            capabilities = capabilities,
            on_attach = on_attach,
            settings = {
              python = {
                analysis = {
                  typeCheckingMode = "basic",
                  autoSearchPaths = true,
                  useLibraryCodeForTypes = true,
                },
              },
            },
          })
        end,

        -- lua_ls: aware of vim globals
        ["lua_ls"] = function()
          lspconfig.lua_ls.setup({
            capabilities = capabilities,
            on_attach = on_attach,
            settings = {
              Lua = {
                diagnostics = { globals = { "vim" } },
                workspace = { checkThirdParty = false },
                telemetry = { enable = false },
              },
            },
          })
        end,

        -- asm_lsp: hover docs for x86/x86_64/ARM instructions
        ["asm_lsp"] = function()
          lspconfig.asm_lsp.setup({
            capabilities = capabilities,
            on_attach = on_attach,
            filetypes = { "asm", "s", "S" },
          })
        end,
      })
    end,
  },
}
