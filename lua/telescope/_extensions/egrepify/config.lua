local egrep_actions = require "telescope._extensions.egrepify.actions"
local egrep_utils = require "telescope._extensions.egrepify.utils"

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local config = {}

local title_suffix = string.format(" %s", egrep_utils.repeat_char("─", 1000))

_TelescopeEgrepifyConfig = {
  AND = true,
  permutations = false,
  lnum = true,
  lnum_width = false,
  lnum_hl = "EgrepifyLnum",
  col = false,
  col_width = false,
  col_hl = "EgrepifyCol",
  use_prefixes = true,
  title = true,
  filename_hl = "EgrepifyFile",
  title_suffix = title_suffix,
  title_suffix_hl = "EgrepifySuffix",
  grep_open_files = false,
  mappings = {
    i = {
      ["<C-z>"] = egrep_actions.toggle_prefixes,
      ["<C-a>"] = egrep_actions.toggle_and,
      ["<C-r>"] = egrep_actions.toggle_permutations,
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
    -- ensure "title" lines are not selected when iterating selections
    for _, key in ipairs {
      "move_selection_next",
      "move_selection_previous",
      "move_selection_better",
      "move_selection_worse",
    } do
      actions[key]:enhance {
        post = function()
          local entry = action_state.get_selected_entry()
          if entry and entry.kind == "begin" then
            actions[key](prompt_bufnr)
          end
        end,
      }
    end
    actions.to_fuzzy_refine:enhance {
      pre = function()
        local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
        -- modifying table which has entry maker options
        current_picker._opts.title = false
        local entry_manager = current_picker.manager
        -- creating new LinkedList without "title" lines
        local list_excl_titles = require("telescope.algos.linked_list"):new { track_at = entry_manager.max_results }
        for val in entry_manager.linked_states:iter() do
          if val[1].kind == "match" then
            list_excl_titles:append(val)
          end
        end
        entry_manager.linked_states = list_excl_titles
        current_picker:refresh()
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
          if val[1].kind == "match" then
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
