local ext_actions = require "telescope._extensions.egrepify.actions"
local ext_utils = require "telescope._extensions.egrepify.utils"

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local config = {}

local title_suffix = string.format(" %s", ext_utils.repeat_char("─", 1000))

_TelescopeEgrepifyConfig = {
  AND = true,
  lnum = true,
  lnum_hl = "EgrepifyLnum",
  col = false,
  col_hl = "EgrepifyCol",
  use_prefixes = true,
  title_suffix = title_suffix,
  title_suffix_hl = "EgrepifySuffix",
  grep_open_files = false,
  mappings = {
    i = {
      ["<C-z>"] = ext_actions.toggle_prefixes,
    },
    n = {
      ["z"] = ext_actions.toggle_prefixes,
    },
  },
  prefixes = {
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
  },
  attach_mappings = function(prompt_bufnr, map)
    map("i", "<c-space>", actions.to_fuzzy_refine)
    actions.move_selection_previous:enhance {
      -- ensure "title" lines are not selected
      post = function()
        local entry = action_state.get_selected_entry()
        if entry and entry.lnum == nil then
          actions.move_selection_previous(prompt_bufnr)
        end
      end,
    }
    actions.move_selection_next:enhance {
      -- ensure "title" lines are not selected
      post = function()
        local entry = action_state.get_selected_entry()
        if entry and entry.lnum == nil then
          actions.move_selection_next(prompt_bufnr)
        end
      end,
    }
    actions.send_to_qflist:enhance {
      -- ensure "title" lines are not sent to qflist
      pre = function()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local entry_manager = current_picker.manager
        -- creating new LinkedList without "title" lines
        local original_linked_states = entry_manager.linked_states
        local list_excl_titles = require("telescope.algos.linked_list"):new { track_at = entry_manager.max_results }
        for val in entry_manager.linked_states:iter() do
          if val[1].lnum ~= nil then
            list_excl_titles:append(val)
          end
        end
        entry_manager.linked_states = list_excl_titles
        -- restore original linked_states after qflist entries are created
        -- see telescope.actions.send_to_qflist
        -- pre is triggered right before caching picker for resumption
        actions.close:enhance {
          pre = function()
            entry_manager.linked_states = original_linked_states
          end,
        }
      end,
    }
    return true
  end,
} or _TelescopeEgrepifyConfig

config.values = _TelescopeEgrepifyConfig

config.setup = function(opts)
  -- TODO maybe merge other keys as well from telescope.config
  config.values.mappings =
    vim.tbl_deep_extend("force", config.values.mappings, require("telescope.config").values.mappings)
  config.values = vim.tbl_deep_extend("force", config.values, opts)
end

return config
