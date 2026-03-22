return {
	-- File explorer
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons", -- icons
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("neo-tree").setup({
				close_if_last_window = true, -- auto close nếu chỉ còn lại neo-tree
				popup_border_style = "rounded",
				enable_git_status = true,
				enable_diagnostics = true,

				filesystem = {
					filtered_items = {
						hide_dotfiles = false, -- show hidden files (.gitignore, .env, …)
						hide_gitignored = true,
						hide_by_name = { "node_modules" },
					},
					follow_current_file = { enabled = true }, -- auto highlight file opening
					group_empty_dirs = true,
					hijack_netrw_behavior = "open_default", -- afternative netrw
				},

				buffers = {
					follow_current_file = { enabled = true },
				},

				git_status = {
					window = { position = "float" },
				},
			})
		end,
	},
}
