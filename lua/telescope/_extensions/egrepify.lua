local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local ext_config = require("telescope._extensions.egrepify.config")
local ext_picker = require("telescope._extensions.egrepify.picker")

-- Initialize highlights

vim.api.nvim_set_hl(0, "EgrepifyTitle", { link = "Title" })
vim.api.nvim_set_hl(0, "EgrepifySuffix", { link = "Comment" })
vim.api.nvim_set_hl(0, "EgrepifyLnum", { link = "Constant" })
vim.api.nvim_set_hl(0, "EgrepifyCol", { link = "Constant" })

local egrepify = function(opts)
	opts = opts or {}
	local defaults = (function()
		if ext_config.values.theme then
			return require("telescope.themes")["get_" .. ext_config.values.theme](ext_config.values)
		end
		return vim.deepcopy(ext_config.values)
	end)()

	if ext_config.values.mappings then
		defaults.attach_mappings = function(prompt_bufnr, map)
			if ext_config.values.attach_mappings then
				ext_config.values.attach_mappings(prompt_bufnr, map)
			end
			for mode, tbl in pairs(ext_config.values.mappings) do
				for key, action in pairs(tbl) do
					map(mode, key, action)
				end
			end
			return true
		end
	end

	if opts.attach_mappings then
		local opts_attach = opts.attach_mappings
		opts.attach_mappings = function(prompt_bufnr, map)
			defaults.attach_mappings(prompt_bufnr, map)
			return opts_attach(prompt_bufnr, map)
		end
	end
	local popts = vim.tbl_deep_extend("force", defaults, opts)
	ext_picker(popts)
end

return telescope.register_extension({
  setup = ext_config.setup,
	exports = {
		egrepify = egrepify,
	},
})
