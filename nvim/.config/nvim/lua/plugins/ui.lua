return {
	-- Auto switch Neovim theme based on OS theme
	{
		"f-person/auto-dark-mode.nvim",
		config = function()
			require("auto-dark-mode").setup({
				update_interval = 1000, -- check every 1s
				set_dark_mode = function()
					vim.cmd("colorscheme github_dark") -- your dark theme
				end,
				set_light_mode = function()
					vim.cmd("colorscheme github_light") -- your light theme
				end,
			})
			require("auto-dark-mode").init()
		end,
	},

	-- Theme
	{
		"projekt0n/github-nvim-theme",
		config = function()
			require("github-theme").setup({})
			vim.cmd("colorscheme github_dark")
		end,
	},

	-- Statusline (Lualine)
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				theme = "auto", -- auto-detects colorscheme
				globalstatus = true, -- one statusline for all windows
				section_separators = "",
				component_separators = "",
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				lualine_c = { "filename" },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		},
	},

	-- Icon
	{
		"akinsho/bufferline.nvim",
		version = "*",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("bufferline").setup({
				options = {
					numbers = "ordinal",
					diagnostics = "nvim_lsp",
					separator_style = "slant",
					always_show_bufferline = true,
					show_buffer_close_icons = true,
					show_close_icon = false,
					color_icons = true,
				},
			})
		end,
	},
}
