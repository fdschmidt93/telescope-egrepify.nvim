local ext_entry_maker = require "telescope._extensions.egrepify.entry_maker"
local ext_utils = require "telescope._extensions.egrepify.utils"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local conf = require("telescope.config").values

local flatten = vim.tbl_flatten
---Live grep using `rg` with custom args parsing and entry making. -@param opts table: options to pass to the picker
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
