local ts_utils = require "telescope.utils"
local egrep_conf = require("telescope._extensions.egrepify.config").values

local str = require "plenary.strings"

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

local function line_display(entry, data, opts)
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
      [8] = entry.ordinal,
    },
    ""
  )
  local highlights = {}
  local begin = 0
  local end_ = 0
  -- begin = end_ + 1 to skip the separators
  if opts.title == false then
    highlights[#highlights + 1] = { { begin, 3 }, devicon_hl }
    begin = 4
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
      highlights[#highlights + 1] = { { end_, end_ + #entry.ordinal }, opts.egrep_hl }
    end
  end
  return display, highlights
end

local function title_display(filename, _, opts)
  local display_filename = ts_utils.transform_path({ cwd = opts.cwd }, filename)
  local suffix_ = opts.title_suffix or ""
  local display, hl_group = ts_utils.transform_devicons(display_filename, display_filename .. suffix_, false)
  if hl_group then
    return display,
        {
          { { 0, 3 }, hl_group },
          {
            { 4, 4 + #display_filename },
            opts.filename_hl,
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
        -- local line_displayer = entry_display.create(opts.display_line_create)
        local entry = {
          filename = data["path"]["text"],
          lnum = data["line_number"],
          -- byte offset zero-indexed
          col = start + 1,
          value = data,
          ordinal = text,
          kind = kind,
        }

        local display = function()
          -- return line_displayer(line_display(entry, data, opts))
          return line_display(entry, data, opts)
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
