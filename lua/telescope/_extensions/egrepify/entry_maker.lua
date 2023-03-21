local entry_display = require("telescope.pickers.entry_display")
local ts_utils = require("telescope.utils")
local ext_utils = require("telescope._extensions.egrepify.utils")

local title_suffix = string.format(" %s", ext_utils.repeat_char("─", 1000))
local str = require("plenary.strings")

local function line_display(entry, data, opts)
	entry = entry or {}
	local lnum_col_str = table.concat(
		vim.tbl_values({
			opts.lnum and str.align_str(tostring(entry.lnum), 4, true) or nil,
			opts.lnum and ":" or nil,
			opts.col and str.align_str(tostring(entry.col), 3, true) or nil,
		}),
		""
	)
	local out = {}
	if opts.lnum or opts.col then
		out[#out + 1] = {
			lnum_col_str,
			{
				lnum_col_str,
				function()
					local hl_table = {}
					if opts.lnum then
						hl_table[#hl_table + 1] = { { 0, 4 }, opts.lnum_hl }
					end
					if opts.col then
						hl_table[#hl_table + 1] = { { 5, #lnum_col_str }, opts.col_hl }
					end
					if vim.tbl_isempty(hl_table) then
						return { { 0, 1 }, "Normal" }
					end
					return hl_table
				end,
			},
		}
	end
	out[#out + 1] = {
		entry.ordinal,
		function()
			-- TODO: can we get proper selection highlighting?
			-- local current_picker
			-- local bufnr = vim.api.nvim_get_current_buf()
			-- if vim.bo[bufnr].filetype == "TelescopePrompt" then
			--   current_picker = action_state.get_current_picker(bufnr)
			-- end
			-- local text_hl = "GruvboxFg3"
			-- if current_picker then
			--   if current_picker:is_multi_selected(entry) then
			--     text_hl = "TelescopeSelection"
			--   end
			-- end
			local highlights = {}
			local beginning = 0
			if not vim.tbl_isempty(data["submatches"]) then
				for _, submatch in ipairs(data["submatches"]) do
					local s = submatch["start"]
					local f = submatch["end"]
					if opts.text_hl then
						highlights[#highlights + 1] = { { beginning, s }, opts.text_hl }
					end
					highlights[#highlights + 1] = { { s, f }, "TelescopeMatching" }
					beginning = f
				end
				if opts.text_hl then
					highlights[#highlights + 1] = { { beginning, #entry.text }, opts.text_hl }
				end
			end
			return highlights
		end,
	}
	return out
end

local function title_display(filename, data, opts)
	local display_filename = ts_utils.transform_path({ cwd = opts.cwd }, filename)
	local suffix_ = opts.title_suffix or ""
	local display, hl_group = ts_utils.transform_devicons(display_filename, display_filename .. suffix_, false)
	if hl_group then
		return display,
			{
				{ { 1, 3 }, hl_group },
				{
					{ 4, 4 + #display_filename },
					opts.title_hl,
				},
				suffix_ ~= "" and {
					{ 4 + #display_filename, 4 + #display_filename + #opts.title_suffix },
					opts.title_suffix_hl,
				} or nil,
			}
	else
		return display
	end
end

return function(opts)
	opts = opts or {}
	opts.title_hl = vim.F.if_nil(opts.title_hl, "EgrepifyTitle")
	opts.title_suffix = vim.F.if_nil(opts.title_suffix, title_suffix)
	opts.title_suffix_hl = vim.F.if_nil(opts.title_suffix_hl, "EgrepifySuffix")
	opts.lnum = vim.F.if_nil(opts.lnum, true)
	opts.lnum_hl = vim.F.if_nil(opts.lnum_hl, "EgrepifyLnum")
	opts.col = vim.F.if_nil(opts.col, false)
	opts.col_hl = vim.F.if_nil(opts.col_hl, "EgrepifyCol")
	local lnum_col_width = 1
	if opts.lnum then
		lnum_col_width = lnum_col_width + 4
	end
	if opts.col then
		lnum_col_width = lnum_col_width + 3
	end

	local items = {}
	if opts.lnum or opts.col then
		items[#items + 1] = { width = lnum_col_width }
	end
	items[#items + 1] = { remaining = true }

	opts.display_line_create = vim.F.if_nil(opts.display_line_create, {
		separator = (opts.lnum or opts.col) and " " or "",
		items = items,
	})
	opts.title_display = vim.F.if_nil(opts.title_display, title_display)

	return function(stream)
		local json_line = vim.json.decode(stream)
		if json_line == nil then
			return nil
		end
		local kind = json_line["type"]
		if json_line then
			if kind == "match" then
				local data = json_line["data"]
				local text = data["lines"]["text"]:gsub("\n", " ")
				data.text = text
				-- if text == " " then
				-- 	return nil
				-- end
				local start = not vim.tbl_isempty(data["submatches"]) and data["submatches"][1]["start"] or 0
				local line_displayer = entry_display.create(opts.display_line_create)
				local entry = {
					filename = data["path"]["text"],
					lnum = data["line_number"],
					-- byte offset zero-indexed
					col = start + 1,
					value = data,
					ordinal = text,
				}

				local display = function()
					return line_displayer(line_display(entry, data, opts))
				end
				entry.display = display
				return entry
			elseif
				-- parse beginning of rg output for a file
				kind == "begin"
			then
				local data = json_line["data"]
				local filename = data["path"]["text"]
				return {
					value = filename,
					ordinal = filename,
					display = function()
						return opts.title_display(filename, data, opts)
					end,
				}
			end
		end
		-- TODO: check if other entry kinds are valid
		-- skip other entry kinds
		return nil
	end
end
