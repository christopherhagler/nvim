local map = vim.keymap.set

-- Save
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- Exit insert mode
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Centered search navigation
map("n", "n", "nzzzv", { desc = "Next search result" })
map("n", "N", "Nzzzv", { desc = "Prev search result" })

-- Centered scrolling
map("n", "<C-d>", "<C-d>zzzv", { desc = "Scroll down" })
map("n", "<C-u>", "<C-u>zzzv", { desc = "Scroll up" })

-- Telescope (mirrors original bindings)
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
map("n", "<C-p>", "<cmd>Telescope find_files<cr>", { desc = "Find files" })

-- File explorer / outline
map("n", "<leader>n", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })
map("n", "<F8>", "<cmd>AerialToggle<cr>", { desc = "Toggle symbols outline" })

-- Terminal
map("n", "<leader>t", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- LSP (set in lsp on_attach, mirrored here for which-key groups)
-- gd, gy, gi, gr, K, <leader>rn, <leader>a, <leader>ac, <leader>re, <leader>cl, [g, ]g, <leader>qf

-- Better indenting in visual mode
map("v", "<", "<gv")
map("v", ">", ">gv")
