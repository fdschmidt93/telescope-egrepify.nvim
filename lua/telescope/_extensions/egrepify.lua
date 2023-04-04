---@mod telescope-egrepify.nvim Introduction
---@brief [[
---
---telescope-egrepify.nvim is a telescope.nvim extension to
---customize live grep with "prefixes" to enhance `rg` flags.
--- Features:
---   1. Add custom prefixes to `rg` flags
---   2. Custom entry maker for clear & customizable view on results
---   3. Better defaults (AND operator for tokens, prefixes, entry maker)
---
--- Prefix examples - search for sorter in:
---   1. `#md,lua sorter` in markdown & lua (file extension globbing)
---   2. `>lua sorter` in paths that contain lua in directory names
---   3. `&picker sorter` in files for which `picker` is in the file name
---
---@brief ]]

---@tag telescope-egrepify.prefix Prefix
---@brief [[
---The core functionality of `telescope-egripfy.nvim` are `prefixes`.
---The below prefixes are the builtin-defaults. Should you want to use
---extension, please __carefully__ read the table below on how a prefix
---is added. The configuration section shows how to add another prefix.
--->lua
---  -- DEFAULTS
---  -- filter for file suffixes
---  -- example prompt: #lua,md $MY_PROMPT
---  -- searches with ripgrep prompt $MY_PROMPT in files with extensions lua and md
---  -- i.e. rg --glob="*.{lua,md}" -- $MY_PROMPT
---  { ["#"] = {
---        -- #$REMAINDER
---        -- # is caught prefix
---        -- `input` becomes $REMAINDER
---        -- in the above example #lua,md -> input: lua,md
---        flag = "glob",
---        cb = function(input)
---            return string.format([[*.{%s}]], input)
---        end,
---    },
---    -- filter for (partial) folder names
---    -- example prompt: >conf $MY_PROMPT
---    -- searches with ripgrep prompt $MY_PROMPT in paths that have "conf" in folder
---    -- i.e. rg --glob="**/conf*/**" -- $MY_PROMPT
---    [">"] = {
---        flag = "glob",
---        cb = function(input)
---            return string.format([[**/{%s}*/**]], input)
---        end,
---    },
---    -- filter for (partial) folder names
---    -- example prompt: &egrep $MY_PROMPT
---    -- searches with ripgrep prompt $MY_PROMPT in paths that have "egrep" in file name
---    -- i.e. rg --glob="*egrep*" -- $MY_PROMPT
---    ["&"] = {
---        flag = "glob",
---        cb = function(input)
---            return string.format([[*{%s}*]], input)
---        end,
---    }
---  }
---<
---You can untoggle the use of prefixs by hitting <C-z> (z) in insert (normal) mode.
---If you want to opt-out of a single prefix you can set `prefix` or pass `prefix`
---to `opts` with the corresponding prefix character set to `false`:
--->lua
---  -- opting out of file extension
---  { ["#"] = false }
---<
---
---If you want to add a prefix, you can do so by adding a table to the `prefixes` table
---in the `setup` function. The table should have the following structure:
--->lua
---  {
---    -- prefix character
---    ["<prefix>"] = {
---      -- flag to be passed to `rg`
---      flag = "<flag>",
---      -- optional callback to be called with the remainder of parsed input
---      -- should return a string that is passed to `rg` as the flag values
---      -- If not provided, remainder, *if existing*, is passed as is
---      cb = function(input)
---        return "<flag_value>"
---      end,
---    },
---    -- example of a boolean flag
---     ["!"] = {
---       flag = "invert-match",
---     },
---  }
--- The default prefixes in the beginning of the section are good examples on how
--- to add a prefix.
---<
---@brief ]]

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error "This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)"
end

local egrep_config = require "telescope._extensions.egrepify.config"
local egrep_picker = require "telescope._extensions.egrepify.picker"

-- Initialize highlights
vim.api.nvim_set_hl(0, "EgrepifyFile", { link = "Title" })
vim.api.nvim_set_hl(0, "EgrepifySuffix", { link = "Comment" })
vim.api.nvim_set_hl(0, "EgrepifyLnum", { link = "Constant" })
vim.api.nvim_set_hl(0, "EgrepifyCol", { link = "Constant" })

local egrepify = function(opts)
  opts = opts or {}
  local defaults = (function()
    if egrep_config.values.theme then
      return require("telescope.themes")["get_" .. egrep_config.values.theme](egrep_config.values)
    end
    return vim.deepcopy(egrep_config.values)
  end)()

  if egrep_config.values.mappings then
    defaults.attach_mappings = function(prompt_bufnr, map)
      if egrep_config.values.attach_mappings then
        egrep_config.values.attach_mappings(prompt_bufnr, map)
      end
      for mode, tbl in pairs(egrep_config.values.mappings) do
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

  for prefix, prefix_opts in pairs(popts.prefixes) do
    if prefix_opts == false then
      popts.prefixes[prefix] = nil
    end
  end

  egrep_picker(popts)
end

-- this pattern is required for lemmy-help
local M = telescope.register_extension {
  setup = egrep_config.setup,
  exports = {
    egrepify = egrepify,
  },
}

return M
