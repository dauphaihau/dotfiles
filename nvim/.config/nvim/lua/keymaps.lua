local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- enter add break line
map("n", "<S-CR>", "O", { noremap = true })
map("n", "<CR>", "o<Esc>", { noremap = true })

-- Keymaps for Neotree ( File explorer )
-- Toggle file explorer
map("n", "<leader>e", ":Neotree toggle<CR>", opts)
-- Open current file
map("n", "<leader>o", ":Neotree reveal<CR>", opts)

-- Tabs
map("n", "<Tab>", "<Cmd>BufferLineCyclePrev<CR>", { silent = true })
map("n", "<S-Tab>", "<Cmd>BufferLineCycleNext<CR>", { silent = true })

-- Keymaps for vim-visual-multi
vim.g.VM_maps = {
	["Find Under"] = "<C-n>", -- select word under cursor
	["Find Subword Under"] = "<C-n>", -- select subword
	["Select All"] = "<C-a>", -- select all occurrences
	["Add Cursor Down"] = "<C-Down>", -- add cursor below
	["Add Cursor Up"] = "<C-Up>", -- add cursor above
}

-- Optional: normal mode shortcuts to enter VM mode quickly
map({ "n", "v" }, "<C-n>", "<Plug>(VM-Find-Under)")
map({ "n", "v" }, "<C-a>", "<Plug>(VM-Select-All)")
map({ "n", "v" }, "<C-Down>", "<Plug>(VM-Add-Cursor-Down)")
map({ "n", "v" }, "<C-Up>", "<Plug>(VM-Add-Cursor-Up)")

map("n", "<leader>bp", "<Cmd>BufferLineMovePrev<CR>", { silent = true })
map("n", "<leader>bn", "<Cmd>BufferLineMoveNext<CR>", { silent = true })
map("n", "<leader>bb", "<Cmd>BufferLinePick<CR>", { silent = true })
map("n", "q", "<Cmd>bdelete<CR>", { silent = true })

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })

-- Format
map("n", ",f", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file" })

-- Keymaps for Leap ( File explorer )
map({ "n", "x", "o" }, "<leader>;", function()
	-- Load leap.nvim on demand
	require("lazy").load({ plugins = { "leap.nvim" } })
	require("leap").leap({ target_windows = { vim.fn.win_getid() } })
end, { desc = "Leap in current window" })

map({ "n", "x", "o" }, "<leader>S", function()
	require("lazy").load({ plugins = { "leap.nvim" } })
	require("leap").leap({ target_windows = require("leap.user").get_focusable_windows() })
end, { desc = "Leap across windows" })
