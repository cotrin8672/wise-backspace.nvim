# wise-backspace.nvim

Smart Backspace for Neovim insert mode.

Current release: `1.0.4`.

`wise-backspace.nvim` leaves ordinary text deletion to native `<BS>`, so typo fixes remain part of insert redo and work with `.`. It only takes over when everything to the left of the cursor on the current line is indentation, then returns a key sequence that either fixes indentation or joins the line upward.

## Behavior

- On ordinary text, return native `<BS>`.
- When the cursor is between a simple matched pair, remove both sides of the pair.
- When the cursor's left side contains only spaces or tabs, behave as if the cursor were at the first non-whitespace character or at end of line.
- On the first line, remove leading indentation without joining upward.
- On an over-indented line, reduce indentation to the previous non-empty line's indentation.
- After an opening pair or before a dot-prefixed continuation, reduce over-indentation to one `shiftwidth` deeper than the previous non-empty line; if it is already there, join upward.
- On a whitespace-only line inside an empty bracket block, collapse the block onto one line.
- When Tree-sitter support is explicitly enabled, Lua keyword blocks such as `if ... end` can use the same indentation reduction and empty-block collapse behavior.
- Otherwise, remove leading indentation and join upward with native line deletion.

## Setup

```lua
require("wise-backspace").setup()
```

With lazy.nvim:

```lua
{
  "cotrin8672/wise-backspace.nvim",
  tag = "v1.0.4",
  event = { "InsertEnter", "CmdlineEnter" },
  opts = {
    ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  },
}
```

Options:

- `ignored_filetypes`: filetypes that always use native `<BS>`.
- `treesitter`: optional Tree-sitter block support. Disabled by default.

```lua
require("wise-backspace").setup({
  ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  treesitter = {
    enabled = false,
    languages = { "lua" },
  },
})
```

Default ignored filetypes:

```lua
{ "", "python", "haskell", "markdown", "text" }
```

Tree-sitter support uses Neovim's built-in Tree-sitter APIs and does not depend on `nvim-treesitter`. It is opt-in:

```lua
require("wise-backspace").setup({
  treesitter = {
    enabled = true,
    languages = { "lua" },
  },
})
```

Currently, the built-in provider supports Lua blocks such as `if ... end`, `do ... end`, `while ... end`, `for ... end`, `repeat ... until`, and function blocks. Unsupported languages or missing parsers silently fall back to the default behavior.

Lazy-loading on the first insert or command-line entry is supported:

```lua
vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
  once = true,
  callback = function()
    require("wise-backspace").setup()
  end,
})
```
