local M = {}
--
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
	for token in prompt:gmatch("%S+") do
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
			args[#args + 1] = string.format([[--%s=%s]], prefix_opts.flag, token_str)
			indices[#indices + 1] = i
		end
	end
	for i = #indices, 1, -1 do
		table.remove(prompt_tokens, indices[i])
	end
	return prompt_tokens, args
end

return M
