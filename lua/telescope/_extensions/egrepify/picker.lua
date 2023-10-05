local action_state = require "telescope.actions.state"
local egrep_entry_maker = require "telescope._extensions.egrepify.entry_maker"
local egrep_utils = require "telescope._extensions.egrepify.utils"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local conf = require("telescope.config").values
local egrep_conf = require("telescope._extensions.egrepify.config").values
local actions = require "telescope.actions"

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

-- sorting_strategy "descending" puts title "after" matches, while "ascending" has title "before" matches
local descending_sorter = sorters.new {
  scoring_function = function()
    -- telescope does not manage entries if score is 1
    -- required to activate `tiebreak`
    return 0
  end,
}

local descending_tiebreak = function(current_entry, existing_entry)
  if current_entry.filename == existing_entry.filename then
    if existing_entry.kind == "begin" then
      return true
    end
  end
  return false
end

---@class PickerConfig
---@field cwd string directory to run `rg` input
---@field grep_open_files boolean search only open files (default: false)
---@field search_dirs string[] directory/directories/files to search, mutually excl. with `grep_open_files`(default: false)
---@field vimgrep_arguments table args for `rg`, see |telescope.defaults.vimgrep_arguments|
---@field use_prefixes boolean use prefixes in prompt, toggleable with <C-z> (default: true)
---@field AND boolean search with fzf-like AND logic to ordered sub-tokens of prompt
---@field permutations boolean search permutations of sub-tokens of prompt, implies AND true
---@field prefixes table prefixes for `rg` input, see |telescope-egrepify.prefix|
---@field filename_hl string hl for title (default: `EgrepifyFile` w/ link to `Title`)
---@field title boolean filename as title, false to inline (default: true)
---@field title_suffix string string after filename title, only if `title == true` (default: " " .. "──────────")
---@field title_suffix_hl string title suffix hl [`EgrepifySuffix`, links to `Comment`]
---@field lnum boolean include lnum in result entry
---@field lnum_hl string lnum hl [`EgrepifyLnum`, links to `Constant`]
---@field col boolean include col in result entry
---@field col_hl string col hl (default: `EgrepifyCol`, links to `Constant`)
---@field results_ts_hl boolean highlight results entries with treesitter, may increase latency!
---@field sorting_strategy string see |telescope.defaults.sorting_strategy|, "descending" has slight perf. hit

local Picker = {}

-- storage for 'cached' egrepify-specific picker opts
local cached_opts = {}

-- Show deprecation message `msg` once
--@field field string deprecation message to display
local deprecate = function(msg)
  vim.notify_once(msg, vim.log.levels.WARN, { title = "telescope-egrepify" })
end

---telescope-egrepify picker
---@param opts PickerConfig see |telescope-egrepify.picker.PickerConfig|
---@usage `require("telescope").extensions.egrepify.picker()`
function Picker.picker(opts)
  opts = opts or {}

  local search_dirs = vim.F.if_nil(opts.search_dirs, {})

  if search_dirs then
    for i, path in ipairs(search_dirs) do
      search_dirs[i] = vim.fn.expand(path)
    end
  end

  -- opting out of prefixes
  for k, v in pairs(opts.prefixes) do
    if v == false then
      opts.prefixes[k] = nil
    end
  end

  ---@diagnostic disable-next-line: undefined-field
  if opts.title_hl then
    deprecate "title_hl is deprecated, use filename_hl instead"
    ---@diagnostic disable-next-line: undefined-field
    opts.filename_hl = opts.title_hl
  end

  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  local open_files = vim.F.if_nil(opts.grep_open_files, egrep_conf.grep_open_files)
      and egrep_utils._get_open_files(opts.cwd)
    or {}
  local args = flatten { vimgrep_arguments, { "--json" } }

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    local tokens = egrep_utils.tokenize(prompt)
    local prompt_args = {}
    local current_picker
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype == "TelescopePrompt" then
      current_picker = action_state.get_current_picker(bufnr)
    end

    -- restore internal options, should only be nil if picker was cached
    -- unfortunately currently no other way to detect if it was cached or not
    if current_picker and current_picker.use_prefixes == nil and current_picker.AND == nil then
      for k, v in pairs(cached_opts) do
        current_picker[k] = v
      end
    end

    if current_picker and current_picker.use_prefixes == true then
      for prefix, prefix_opts in pairs(opts.prefixes) do
        local prefix_args
        tokens, prefix_args = egrep_utils.prefix_handler(tokens, prefix, prefix_opts)
        prompt_args[#prompt_args + 1] = prefix_args
      end
    end
    if not current_picker.permutations then
      prompt = table.concat(tokens, " ")
      -- matches everything in between sub-tokens of prompt
      if current_picker.AND then
        prompt = prompt:gsub("%s", ".*")
      end
    else -- matches everything in between sub-tokens and permutations
      prompt = egrep_utils.permutations(tokens)
    end

    local search_list = #open_files > 0 and open_files or search_dirs

    return flatten { args, prompt_args, "--", prompt, search_list }
  end, egrep_entry_maker(opts), opts.max_results, opts.cwd)

  local sorting_strategy = vim.F.if_nil(opts.sorting_strategy, require("telescope.config").values.sorting_strategy)
  local is_descending = sorting_strategy == "descending"
  local tiebreak = is_descending and descending_tiebreak or nil
  local sorter = is_descending and descending_sorter or sorters.empty()

  local picker -- so we can refer to picker in actions.close:enhance
  picker = pickers.new(opts, {
    prompt_title = "Live Grep",
    finder = live_grepper,
    -- slight hack that should be simple and work well in practice
    -- descending puts title "after" matches, while ascending has title "before" matches
    default_selection_index = is_descending and 1 or 2,
    previewer = conf.grep_previewer(opts),
    sorter = sorter,
    tiebreak = tiebreak,
    attach_mappings = function()
      actions.close:enhance {
        post = function()
          if picker.cache_picker then
            cached_opts._opts = picker._opts
            cached_opts.use_prefixes = picker.use_prefixes
            cached_opts.AND = picker.AND
            cached_opts.permutations = picker.permutations
          end
        end,
      }
      return true
    end,
  })
  -- caching opts to be able to remove `title` from opts for entry maker for fuzzy refine
  picker._opts = opts
  picker.use_prefixes = vim.F.if_nil(opts.use_prefixes, egrep_conf.use_prefixes)
  -- matches everything in between sub-tokens of prompt akin to fzf
  picker.AND = vim.F.if_nil(opts.AND, egrep_conf.AND)
  -- matches everything in between sub-tokens and permutations
  picker.permutations = vim.F.if_nil(opts.permutations, egrep_conf.permutations)

  if picker.permutations then
    picker.AND = true
  end

  picker:find()
end

---@export Picker
return Picker.picker
