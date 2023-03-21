local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local ext_picker = require("telescope._extensions.egrepify.picker")

-- Initialize highlights

vim.api.nvim_set_hl(0, "EgrepifyTitle", { link = "Title" })
vim.api.nvim_set_hl(0, "EgrepifySuffix", { link = "Comment" })
vim.api.nvim_set_hl(0, "EgrepifyLnum", { link = "Constant" })
vim.api.nvim_set_hl(0, "EgrepifyCol", { link = "Constant" })

return telescope.register_extension({
	exports = {
		egrepify = ext_picker,
	},
})
