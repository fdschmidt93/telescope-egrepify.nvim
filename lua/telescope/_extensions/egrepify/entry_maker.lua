local ts_utils = require "telescope.utils"
local egrep_conf = require("telescope._extensions.egrepify.config").values

local os_sep = require("plenary.path").path.sep
local str = require "plenary.strings"

local find_whitespace = function(string_)
  local offset = 0
  for i = 1, #string_ do
    if string.sub(string_, i, i) == " " then
      offset = i
      break
    end
  end
  return offset
end

local function collect(tbl)
  local out = {}
  for i = 1, 8 do
    local val = tbl[i]
    if val then
      out[#out + 1] = val
    end
  end
  return out
end

-- get the string width of a number without converting to string
local function num_width(num)
  return math.floor(math.log10(num) + 1)
end

local get_line_highlights = function(bufnr, root, lnum, lang)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
  local query = vim.treesitter.query.get(lang, "highlights")
  local line_highlights = setmetatable({}, {
    __index = function(t, k)
      local obj = {}
      rawset(t, k, obj)
      return obj
    end,
  })
  if query then
    for id, node in query:iter_captures(root, bufnr, lnum, lnum + 1) do
      local hl = "@" .. query.captures[id]
      if hl and type(hl) ~= "number" then
        local row1, col1, row2, col2 = node:range()

        if row1 == row2 then
          local row = row1 + 1

          for index = col1, col2 do
            line_highlights[row][index] = hl
          end
        else
          local row = row1 + 1
          for index = col1, #line[row] do
            line_highlights[row][index] = hl
          end

          while row < row2 + 1 do
            row = row + 1

            for index = 0, #(line[row] or {}) do
              line_highlights[row][index] = hl
            end
          end
        end
      end
    end
  end
  return line_highlights
end

local ts_highlight_defs = function(path)
  local lang = vim.filetype.match { filename = path }
  -- check if buffer is opened
  local bufnr
  local buffers = vim.iter(vim.api.nvim_list_bufs()):filter(function(b)
    return vim.api.nvim_buf_get_name(b) and vim.api.nvim_buf_is_loaded(b)
  end)
  if #buffers == 1 then
    bufnr = buffers[1]
  else
    -- read buffer
    -- local current_bufnr = vim.api.nvim_get_current_buf
    -- if vim.bo[current_bufnr].filetype == "TelescopePrompt" then
    -- local previewer =
    -- end
    bufnr = vim.fn.bufadd(path)
    if vim.fn.bufload(bufnr) == 0 then
      bufnr = nil
    end
  end
  local root
  if type(bufnr) == "number" then
    local parser = vim.treesitter.get_parser(bufnr, lang)
    root = parser:parse()[1]:root()
  end
  return setmetatable({ bufnr = bufnr, path = path, root = root, lang = lang }, {
    __index = function(self, lnum)
      if self.bufnr then
        if not self[lnum] then
          self[lnum] = get_line_highlights(self.bufnr, self.root, lnum, self.lang)
        end
        return self[lnum]
      else
        return {}
      end
    end,
  })
end

local function line_display(entry, data, opts, ts_highlights)
  entry = entry or {}
  local file_devicon, devicon_hl
  if opts.title == false then
    file_devicon, devicon_hl = ts_utils.transform_devicons(entry.filename, entry.filename, false)
  end
  local lnum
  local lnum_width = opts.lnum and (opts.lnum_width or num_width(entry.lnum)) or 0
  local col_width = opts.col and (opts.col_width or num_width(entry.col)) or 0
  if opts.lnum then
    lnum = type(opts.lnum_width) == "number" and str.align_str(tostring(entry.lnum), opts.lnum_width, true)
      or tostring(entry.lnum)
  end
  local col
  if opts.col then
    col = type(opts.col_width) == "number" and str.align_str(tostring(entry.col), opts.col_width, true)
      or tostring(entry.col)
  end
  local display = table.concat(
    collect {
      [1] = file_devicon,
      [2] = opts.title == false and ":" or nil,
      [3] = lnum,
      [4] = lnum and ":" or nil,
      [5] = col,
      [6] = col and ":" or nil,
      [7] = (lnum or col) and " " or nil,
      [8] = entry.text,
    },
    ""
  )
  local highlights = {}
  local begin = 0
  local end_ = 0
  -- begin = end_ + 1 to skip the separators
  if opts.title == false then
    begin = find_whitespace(file_devicon)
    highlights[#highlights + 1] = { { 0, begin }, devicon_hl }
    end_ = #entry.filename + begin
    highlights[#highlights + 1] = { { begin, end_ }, opts.filename_hl }
    begin = end_ + 1
  end
  if lnum then
    end_ = begin + lnum_width
    highlights[#highlights + 1] = { { begin, end_ }, opts.lnum_hl }
    begin = end_ + 1
  end
  if col then
    end_ = begin + col_width
    highlights[#highlights + 1] = { { begin, end_ }, opts.col_hl }
    begin = end_ + 1
  end
  if lnum or col then
    begin = begin + 1
  end

  if not ts_highlights[entry.path] then
    ts_highlights[entry.path] = ts_highlight_defs(entry.path)
  end

  for index, hl in pairs(ts_highlights[entry.path][lnum]) do
    highlights[#highlights + 1] = { { begin + index, begin + index + 1 }, hl }
  end

  if not vim.tbl_isempty(data["submatches"]) then
    local matches = data["submatches"]
    for i = 1, #matches do
      local submatch = matches[i]
      local s, f = submatch["start"], submatch["end"]
      if opts.egrep_hl then
        highlights[#highlights + 1] = { { begin, begin + s }, opts.egrep_hl }
      end
      highlights[#highlights + 1] = { { begin + s, begin + f }, "TelescopeMatching" }
      end_ = begin + f
    end
    if opts.egrep_hl then
      highlights[#highlights + 1] = { { end_, end_ + #entry.text }, opts.egrep_hl }
    end
  end
  return display, highlights
end

local function title_display(filename, _, opts)
  local display_filename = ts_utils.transform_path({ cwd = opts.cwd }, filename)
  local suffix_ = opts.title_suffix or ""
  local display, hl_group = ts_utils.transform_devicons(display_filename, display_filename .. suffix_, false)
  local offset = find_whitespace(display)
  local end_filename = offset + #display_filename
  local end_suffix = end_filename + #opts.title_suffix
  if hl_group then
    return display,
      {
        { { 0, offset }, hl_group },
        {
          { offset, end_filename },
          opts.filename_hl,
        },
        suffix_ ~= "" and {
          { end_filename, end_suffix },
          opts.title_suffix_hl,
        } or nil,
      }
  else
    return display
  end
end

return function(opts)
  opts = opts or {}
  opts.filename_hl = vim.F.if_nil(opts.filename_hl, egrep_conf.filename_hl)
  opts.title_suffix = vim.F.if_nil(opts.title_suffix, egrep_conf.title_suffix)
  opts.title_suffix_hl = vim.F.if_nil(opts.title_suffix_hl, egrep_conf.title_suffix_hl)
  opts.lnum = vim.F.if_nil(opts.lnum, egrep_conf.lnum)
  opts.lnum_hl = vim.F.if_nil(opts.lnum_hl, egrep_conf.lnum_hl)
  opts.col = vim.F.if_nil(opts.col, egrep_conf.col)
  opts.col_hl = vim.F.if_nil(opts.col_hl, egrep_conf.col_hl)
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
  local ts_highlights = {}

  return function(stream)
    local json_line = vim.json.decode(stream)
    if json_line == nil then
      return nil
    end
    local kind = json_line["type"]
    if json_line then
      if kind == "match" then
        local data = json_line["data"]
        local lines = data["lines"]
        if not lines then
          return
        end
        local text = lines["text"]
        if not text then
          return
        end
        text = text:gsub("\n", " ")
        local start = not vim.tbl_isempty(data["submatches"]) and data["submatches"][1]["start"] or 0
        local filename = data["path"]["text"]
        local lnum = data["line_number"]
        -- byte offset zero-indexed
        local col = start + 1
        local entry = {
          filename = filename,
          path = opts.cwd .. os_sep .. filename,
          lnum = lnum,
          text = text,
          col = col,
          value = data,
          ordinal = string.format("%s:%s:%s:%s", filename, lnum, col, text),
          kind = kind,
        }

        local display = function()
          return line_display(entry, data, opts, ts_highlights)
        end
        entry.display = display
        return entry
      elseif
        -- parse beginning of rg output for a file
        kind == "begin" and opts.title ~= false
      then
        local data = json_line["data"]
        local filename = data["path"]["text"]
        return {
          value = filename,
          ordinal = filename,
          filename = filename,
          path = opts.cwd .. os_sep .. filename,
          kind = kind,
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
