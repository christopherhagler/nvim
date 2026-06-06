return {
  -- Mason: installs and manages LSP servers
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
      local cmp      = require("cmp")
      local luasnip  = require("luasnip")
      local lspkind  = require("lspkind")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
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
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500 },
          { name = "path",     priority = 250 },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode         = "symbol_text",
            maxwidth     = 50,
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

  -- LSP: installation + native Neovim 0.11+ configuration (no nvim-lspconfig needed)
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "hrsh7th/cmp-nvim-lsp",
      { "j-hui/fidget.nvim",  opts = {} },
      { "folke/lazydev.nvim", ft = "lua", opts = {} },
    },
    config = function()
      -- Install servers
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
        signs           = true,
        update_in_insert = false,
        underline       = true,
        severity_sort   = true,
        float           = { border = "rounded", source = "always" },
      })

      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

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
        map("<leader>cl", vim.lsp.codelens.run, "CodeLens action")
        map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")

        -- Diagnostics
        map("[g",          vim.diagnostic.goto_prev, "Prev diagnostic")
        map("]g",          vim.diagnostic.goto_next, "Next diagnostic")
        map("<leader>xf",  vim.diagnostic.setloclist, "Diagnostics to quickfix")

        -- CodeLens refresh (namespaced augroup prevents stacking on re-attach)
        if client.supports_method("textDocument/codeLens") then
          vim.lsp.codelens.refresh()
          vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
            group    = vim.api.nvim_create_augroup("lsp_codelens_" .. bufnr, { clear = true }),
            buffer   = bufnr,
            callback = vim.lsp.codelens.refresh,
          })
        end
      end

      -- Global defaults applied to every LSP server
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
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
            },
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
