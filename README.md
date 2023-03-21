# telescope-egripfy.nvim

This [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)-extension is my personal alternative to [telescope-live-grep-args.nvim](https://github.com/nvim-telescope/telescope-live-grep-args.nvim).

![Screenshot](https://user-images.githubusercontent.com/39233597/226608982-b3400cea-3aca-499c-afb3-51912443a240.png)
The screenshot shows searching for `require` only in files with `md` extension (i.e. markdown files). For more prefixes and configuration, see [Prefixes](#prefixes).

# Prefixes

The core functionality of `telescope-egripfy.nvim` are `prefixes`. The below prefixes are the builtin-defaults. Should you want to use this extension, please __carefully__ read the table below on how a prefix is added.  The configuration section shows how to add another prefix.
```lua
-- DEFAULTS
-- filter for file suffixes
-- example prompt: #lua,md $MY_PROMPT
-- searches with ripgrep prompt $MY_PROMPT in files with extensions lua and md
-- i.e. rg --glob "*.{lua,md} -- $MY_PROMPT
["#"] = {
    flag = "glob",
    cb = function(input)
        return string.format([[*.{%s}]], input)
    end,
},
-- filter for (partial) folder names
-- example prompt: >conf $MY_PROMPT
-- searches with ripgrep prompt $MY_PROMPT in paths that have "conf" in folder
-- i.e. rg --glob "**/conf*/** -- $MY_PROMPT
[">"] = {
    flag = "glob",
    cb = function(input)
        return string.format([[**/{%s}*/**]], input)
    end,
},
-- filter for (partial) folder names
-- example prompt: &egrep $MY_PROMPT
-- searches with ripgrep prompt $MY_PROMPT in paths that have "egrep" in file name
-- i.e. rg --glob "*egrep* -- $MY_PROMPT
["&"] = {
    flag = "glob",
    cb = function(input)
        return string.format([[*{%s}*]], input)
    end,
}
```

See also `Configuration`

# Configuration

It will allow you to easily build custom functionality for shorthands to create `ripgrep` flags on-the-fly seamlessly.

```lua
require("telescope").setup {
  extensions = {
    egrepify = {
      lnum = true,                -- default, not required
      lnum = true,                -- default, not required
      lnum_hl = "EgrepifyLnum",   -- default, not required, links to `Constant`
      col = false,                -- default, not required
      col_hl = "EgrepifyCol",     -- default, not required, links to `Constant`
	  title_hl = "EgrepifyTitle"  -- default, not required, links to `Title`
      -- suffix = long line, see screenshot
      -- EXAMPLE ON HOW TO ADD PREFIX!
      prefixes = {
        -- ADDED ! to invert matches
        -- example prompt: ! sorter
        -- matches all lines that do not comprise sorter
        ["!"] = {
          flag = "invert-match",
        },
	},
      },
    },
  },
}
```

# DISCLAIMER

Please consider forking or well-formed PRs instead to fix issues or add new features. This extension foremost serves my own needs and turned into a plugin as maybe other users may want to personalize `rg` via `telescope.nvim` in similar fashion.

# Naming

Kudos to ChatGPT:

> `egrepify` combines the concept of "grep" (a common Unix command for searching through files) with the word "Epsilon" (the fifth letter of the Greek alphabet, which can represent "my" in mathematical notation). The resulting word suggests a personalized or customized version of grep.

