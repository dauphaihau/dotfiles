return {
	-- Format
	{
		"stevearc/conform.nvim",
		opts = {
			-- formatters by filetype
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "black" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				json = { "prettier" },
				go = { "gofmt" },
			},
			-- enable format on save
			format_on_save = {
				timeout_ms = 500,
				lsp_fallback = true,
			},
		},
	},

	-- Multi select
	{
		"mg979/vim-visual-multi",
		branch = "master",
		keys = {
			-- disable <leader>s from LazyVim defaults
			{ "<leader>s", false },
		},
	},

	-- Jump cursor
	{
		url = "https://codeberg.org/andyg/leap.nvim",
	},

	-- Autocomplete
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
		},
		opts = function()
			local cmp = require("cmp")
			return {
				mapping = cmp.mapping.preset.insert(),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "buffer" },
					{ name = "path" },
				},
			}
		end,
	},
}
