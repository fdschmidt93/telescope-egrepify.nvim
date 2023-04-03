local M = {}

---Repeat `char` `N` times
---@param char string: character to repeat
---@param N number: number of times to repeat
---@return string: the repeated string
M.repeat_char = function(char, N)
  local t = {}
  for i = 1, N do
    t[i] = char
  end
  return table.concat(t)
end

---Tokenizes the `prompt` into space-separated tokens (i.e. words)
---@param prompt string: the prompt to tokenize
---@return table: the tokens in the prompt
M.tokenize = function(prompt)
  local tokens = {}
  for token in prompt:gmatch "%S+" do
    tokens[#tokens + 1] = token
  end
  return tokens
end

---Parses prefixed flag from the prompt
---@param prompt_tokens table: the prompt tokens
---@param prefix string: the prefix to look format
---@param prefix_opts table: the prefix options (flag: string and cb: function?)
---@return table, table: prompt tokens and extraced flag
M.prefix_handler = function(prompt_tokens, prefix, prefix_opts)
  local prefix_width = #prefix
  local indices = {}
  local args = {}
  for i, token in ipairs(prompt_tokens) do
    local token_prefix = token:sub(1, prefix_width)
    if token_prefix == prefix then
      local token_str = token:sub(prefix_width + 1, -1)
      token_str = prefix_opts.cb and prefix_opts.cb(token_str) or token_str
      if not token_str or token_str == "" then
        args[#args + 1] = string.format([[--%s]], prefix_opts.flag)
      else
        args[#args + 1] = string.format([[--%s=%s]], prefix_opts.flag, token_str)
      end
      indices[#indices + 1] = i
    end
  end
  for i = #indices, 1, -1 do
    table.remove(prompt_tokens, indices[i])
  end
  return prompt_tokens, args
end

--- Telescope Wrapper around vim.notify
---@param funname string: name of the function that will be
---@param opts table: opts.level string, opts.msg string
M.notify = function(funname, opts)
  -- avoid circular require
  local egrep_config = require "telescope._extensions.egrepify.config"
  local quiet = vim.F.if_nil(opts.quiet, egrep_config.values.quiet)
  if not quiet then
    local level = vim.log.levels[opts.level]
    if not level then
      error("Invalid error level", 2)
    end
    vim.notify(string.format("[egrepify.%s] %s", funname, opts.msg), level, {
      title = "telescope-egrepify.nvim",
    })
  end
end

-- Get the list of open buffers, relative to cwd if provided
M._get_open_files = function(cwd)
  local cwd_len = (cwd ~= nil) and #vim.fs.normalize(cwd) or 0
  local buffers = vim.api.nvim_list_bufs()
  local open_buffers = {}
  for _, bufnr in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      local buf_name = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
      -- exclude empty buffers
      if buf_name ~= "" then
        if cwd then
          buf_name = buf_name:sub(cwd_len + 2, -1)
        end
        open_buffers[#open_buffers + 1] = buf_name
      end
    end
  end
  return open_buffers
end

--- Return regex to match all permutations of tokens with wildcards inbetween
---@param tokens string[]: the prompt tokens
---@return string: the regex pattern
M.permutations = function(tokens)
  local result = {}
  local function permute(tokens_, i, n)
    if i == n then
      table.insert(result, table.concat(tokens_, ".*"))
    else
      for j = i, n do
        tokens_[i], tokens_[j] = tokens_[j], tokens_[i]
        permute(tokens_, i + 1, n)
        tokens_[i], tokens_[j] = tokens_[j], tokens_[i]
      end
    end
  end
  permute(tokens, 1, #tokens)
  return string.format("%s%s%s", "(", table.concat(result, "|"), ")")
end

return M
