local ext_entry_maker = require("telescope._extensions.egrepify.entry_maker")
local ext_utils = require("telescope._extensions.egrepify.utils")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values

local flatten = vim.tbl_flatten

---Live grep using `rg` with custom args parsing and entry making.
---@param opts table: options to pass to the picker
---@field vimgrep_arguments table: arguments to pass to `rg`
---@field AND boolean: whether to apply fzf-like AND logic to sub-tokens of prompt
---@field cwd string: directory to run `rg` input
---@field prefixes table: table of prefix tokens and their corresponding options
return function(opts)
	opts = opts or {}

	-- matches everything in between sub-tokens of prompt akin to fzf
	opts.AND = vim.F.if_nil(opts.AND, true)

	local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
	opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

	local args = flatten({ vimgrep_arguments, { "--json" } })

	opts.prefixes = vim.tbl_deep_extend("keep", vim.F.if_nil(opts.prefixes, {}), {
		-- filter for file suffixes
		["#"] = {
			flag = "glob",
			cb = function(input)
				return string.format([[*.{%s}]], input)
			end,
		},
		-- filter for (partial) folder names
		[">"] = {
			flag = "glob",
			cb = function(input)
				return string.format([[**/{%s}*/**]], input)
			end,
		},
		-- filter for (partial) file names
		["&"] = {
			flag = "glob",
			cb = function(input)
				return string.format([[*{%s}*]], input)
			end,
		},
	})

	local live_grepper = finders.new_job(function(prompt)
		if not prompt or prompt == "" then
			return nil
		end

		local tokens = ext_utils.tokenize(prompt)
		local prompt_args = {}
		for prefix, prefix_opts in pairs(opts.prefixes) do
			local prefix_args
			tokens, prefix_args = ext_utils.prefix_handler(tokens, prefix, prefix_opts)
			prompt_args[#prompt_args + 1] = prefix_args
		end
		prompt = vim.trim(table.concat(tokens, " "))
		-- matches everything in between sub-tokens of prompt
		if opts.AND then
			prompt = prompt:gsub("%s", ".*")
		end
		return flatten({ args, prompt_args, "--", prompt })
	end, ext_entry_maker(opts), opts.max_results, opts.cwd)

	pickers
		.new(opts, {
			prompt_title = "Live Grep",
			finder = live_grepper,
			default_selection_index = 2,
			previewer = conf.grep_previewer(opts),
			sorter = sorters.empty(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<c-space>", actions.to_fuzzy_refine)
				actions.move_selection_previous:enhance({
					-- ensure "title" lines are not selected
					post = function()
						local entry = action_state.get_selected_entry()
						if entry and entry.lnum == nil then
							actions.move_selection_previous(prompt_bufnr)
						end
					end,
				})
				actions.move_selection_next:enhance({
					-- ensure "title" lines are not selected
					post = function()
						local entry = action_state.get_selected_entry()
						if entry and entry.lnum == nil then
							actions.move_selection_next(prompt_bufnr)
						end
					end,
				})
				actions.send_to_qflist:enhance({
					-- TODO: affects `Telescope resume`
					-- ensure "title" lines are not sent to qflist
					pre = function()
						local current_picker = action_state.get_current_picker(prompt_bufnr)
						local entry_manager = current_picker.manager
						-- creating new LinkedList without "title" lines
						local LinkedList =
							require("telescope.algos.linked_list"):new({ track_at = entry_manager.max_results })
						for val in entry_manager.linked_states:iter() do
							if val[1].lnum ~= nil then
								LinkedList:append(val)
							end
						end
						entry_manager.linked_states = LinkedList
					end,
				})
				return true
			end,
		})
		:find()
end
