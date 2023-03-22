local action_state = require "telescope.actions.state"
local transform_mod = require("telescope.actions.mt").transform_mod

local ext_utils = require "telescope._extensions.egrepify.utils"

-- do not spam the user with notifications; "lazy-loaded"
local function dismiss_notifications()
  local has_notify, notify = pcall(require, "notify")
  if has_notify then
    notify.dismiss()
  end
end

local ext_actions = setmetatable({}, {
  __index = function(_, k)
    error("Key does not exist for 'fb_actions': " .. tostring(k))
  end,
})

function ext_actions.toggle_prefixes(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker.use_prefixes = not current_picker.use_prefixes
  local msg = current_picker.use_prefixes and "Prefixes enabled" or "Prefixes disabled"
  dismiss_notifications()
  ext_utils.notify("picker", { msg = msg, level = "INFO" })
  current_picker:refresh()
end

ext_actions = transform_mod(ext_actions)
return ext_actions
