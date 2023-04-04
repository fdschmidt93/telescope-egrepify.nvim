# telescope-egripfy.nvim

`telescope-egripfy.nvim` is a [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)-extension that enhances live grepping with opinionated defaults and functionality.

## Features

- Extensible prefix-based CLI parsing for `ripgrep`, e.g. by default `#md,lua sorter` would look for sorter in files with `md` or `lua` extensions
- Better (opinionated) defaults like `AND` for tokens in prompt: `this here` expands to "this*.here" in regex matching this, any characters in between, __and__ here
- Custom entry maker to parse `ripgrep` json to separate filenames as "section titles" (inspired by [consult.el](https://github.com/minad/consult)), configure line and column numbers, and perform accurate line highlighting

## Motivation

Fuzzy-search is often not great at filtering results. 99% of my time, I mostly want to restrict searches by `AND` (intersection of words in search prompt) and files. `ripgrep` syntax is not _as_ trivial as `fzf` but with, e.g., helpers like `telescope-egripfy`'s prefixes enables more precise finding and filtering.

![Screenshot](https://user-images.githubusercontent.com/39233597/226608982-b3400cea-3aca-499c-afb3-51912443a240.png)
The screenshot shows searching for `require` only in files with `md` extension (i.e. markdown files). For more prefixes and configuration, see [Prefixes](#prefixes).

# Prefixes

The core functionality of `telescope-egripfy.nvim` are `prefixes`. What you need to know at a glance:

- Prefixes seamlessly expand user-specific `ripgrep` flags on-the-fly
- The below prefixes are the builtin-defaults with examples on how they are used
- During search, you can toggle the use of prefixes by hitting <C-z> (z) in insert (normal) mode
- The configuration section shows how to opt out of a default and add another prefix.

```lua
-- DEFAULTS
-- filter for file suffixes
-- example prompt: #lua,md $MY_PROMPT
-- searches with ripgrep prompt $MY_PROMPT in files with extensions lua and md
-- i.e. rg --glob="*.{lua,md}" -- $MY_PROMPT
{ ["#"] = {
      -- #$REMAINDER
      -- # is caught prefix
      -- `input` becomes $REMAINDER
      -- in the above example #lua,md -> input: lua,md
      flag = "glob",
      cb = function(input)
          return string.format([[*.{%s}]], input)
      end,
  },
  -- filter for (partial) folder names
  -- example prompt: >conf $MY_PROMPT
  -- searches with ripgrep prompt $MY_PROMPT in paths that have "conf" in folder
  -- i.e. rg --glob="**/conf*/**" -- $MY_PROMPT
  [">"] = {
      flag = "glob",
      cb = function(input)
          return string.format([[**/{%s}*/**]], input)
      end,
  },
  -- filter for (partial) folder names
  -- example prompt: &egrep $MY_PROMPT
  -- searches with ripgrep prompt $MY_PROMPT in paths that have "egrep" in file name
  -- i.e. rg --glob="*egrep*" -- $MY_PROMPT
  ["&"] = {
      flag = "glob",
      cb = function(input)
          return string.format([[*{%s}*]], input)
      end,
  }
}
```

See also `Configuration`.

# Installation

Here is one way to install this extension with [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
{
    "fdschmidt93/telescope-egrepify.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
}
```

Make sure to

```lua
require "telescope".setup({ "$YOUR_TELESCOPE_OPTS" })
require "telescope".load_extension "egrepify"
```

to appropriately setup the plugin. See [Configuration](#Configuration) for options to configure the extension.


## Usage

You can call this extension with vimscript

```vim
:Telescope egrepify
```

or lua

```lua
require "telescope".extensions.egrepify.egrepify {}
```


# Configuration

The below configuration reflects defaults and examples on how to customize `telescope-egripfy.nvim` to your liking.

```lua
local egrep_actions = require "telescope._extensions.egrepify.actions"

require("telescope").setup {
  extensions = {
    egrepify = {
      -- intersect tokens in prompt ala "str1.*str2" that ONLY matches
      -- if str1 and str2 are consecutively in line with anything in between (wildcard)
      AND = true,                     -- default
      permutations = false,           -- opt-in to imply AND & match all permutations of prompt tokens
      lnum = true,                    -- default, not required
      lnum_hl = "EgrepifyLnum",       -- default, not required, links to `Constant`
      col = false,                    -- default, not required
      col_hl = "EgrepifyCol",         -- default, not required, links to `Constant`
      title = true,                   -- default, not required, show filename as title rather than inline
      filename_hl = "EgrepifyFile",   -- default, not required, links to `Title`
      -- suffix = long line, see screenshot
      -- EXAMPLE ON HOW TO ADD PREFIX!
      prefixes = {
        -- ADDED ! to invert matches
        -- example prompt: ! sorter
        -- matches all lines that do not comprise sorter
        -- rg --invert-match -- sorter
        ["!"] = {
          flag = "invert-match",
        },
        -- HOW TO OPT OUT OF PREFIX
        -- ^ is not a default prefix and safe example
        ["^"] = false
      },
      -- default mappings
      mappings = {
        i = {
          -- toggle prefixes, prefixes is default
          ["<C-z>"] = egrep_actions.toggle_prefixes,
          -- toggle AND, AND is default, AND matches tokens and any chars in between
          ["<C-a>"] = egrep_actions.toggle_and,
          -- toggle permutations, permutations of tokens is opt-in
          ["<C-r>"] = egrep_actions.toggle_permutations,
        },
      },
    },
  },
}
require("telescope").load_extension "egrepify"
```

# Mappings


| Insert mode | egrepify_actions           | Description                                                                      |
| --------------- | -------------------- | -------------------------------------------------------------------------------- |
| `<C-z>`       | toggle_prefixes               | Toggle using prefixes on and off (default: on)    |
| `<C-a>`       | toggle_and               | Toggle using AND on and off (default: on)    |
| `<C-r>`       | toggle_permutations               | Toggle matching permutations (implies AND) on and off (default: off)    |

# DISCLAIMER

Please consider forking for your own customization or well-formed PRs instead to fix issues or add new features. This extension foremost serves my own needs and turned into a plugin as maybe other users may want to personalize `rg` via `telescope.nvim` in similar fashion. Many options _are_ configurable, but I would like to avoid added maintenace burden beyond review (and hopefully merging) of PRs.

# Naming

Kudos to ChatGPT:

> `egrepify` combines the concept of "grep" (a common Unix command for searching through files) with the word "Epsilon" (the fifth letter of the Greek alphabet, which can represent "my" in mathematical notation). The resulting word suggests a personalized or customized version of grep.

