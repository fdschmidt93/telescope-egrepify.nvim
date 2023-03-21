local ext_entry_maker = require "telescope._extensions.egrepify.entry_maker"
local ext_utils = require "telescope._extensions.egrepify.utils"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local conf = require("telescope.config").values

local flatten = vim.tbl_flatten

---@mod telescope-egrepify.picker Picker
---@brief [[
---You can access the picker with defaults and user-configuration by calling
--->lua
---  require("telescope").extensions.egrepify.picker()
---<
--- or via vimscript
--->vim
---  :Telescope egrepify
---<
--- The available configuration options are listed at |telescope-egrepify.picker.PickerConfig|.
---@brief ]]

---@class PickerConfig
---@field cwd string directory to run `rg` input
---@field vimgrep_arguments table args for `rg`, see |telescope.defaults.vimgrep_arguments|
---@field AND boolean search with fzf-like AND logic to ordered sub-tokens of prompt
---@field prefixes table prefixes for `rg` input, see |telescope-egrepify.prefix|
---@field title_hl string hl for title (default: `EgrepifyTitle` w/ link to `Title`)
---@field title_suffix string string after filename title (default: " " .. "──────────")
---@field title_suffix_hl string title suffix hl [`EgrepifySuffix`, links to `Comment`]
---@field lnum boolean include lnum in result entry
---@field lnum_hl string lnum hl [`EgrepifyLnum`, links to `Constant`]
---@field col boolean include col in result entry
---@field col_hl string col hl (default: `EgrepifyCol`, links to `Constant`)

local Picker = {}

---telescope-egrepify picker
---@param opts PickerConfig see |telescope-egrepify.picker.PickerConfig|
---@usage `require("telescope").extensions.egrepify.picker()`
function Picker.picker(opts)
  opts = opts or {}

  -- matches everything in between sub-tokens of prompt akin to fzf
  opts.AND = vim.F.if_nil(opts.AND, _TelescopeEgrepifyConfig.AND)
  opts.prefixes = vim.F.if_nil(opts.prefixes, _TelescopeEgrepifyConfig.prefixes)

  -- opting out of prefixes
  for k, v in pairs(opts.prefixes) do
    if v == false then
      opts.prefixes[k] = nil
    end
  end

  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  local args = flatten { vimgrep_arguments, { "--json" } }

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
    return flatten { args, prompt_args, "--", prompt }
  end, ext_entry_maker(opts), opts.max_results, opts.cwd)

  pickers
      .new(opts, {
        prompt_title = "Live Grep",
        finder = live_grepper,
        default_selection_index = 2,
        previewer = conf.grep_previewer(opts),
        sorter = sorters.empty(),
      })
      :find()
end


---@export Picker
return Picker.picker
