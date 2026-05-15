# wise-backspace.nvim

Smart Backspace for Neovim insert mode.

Current release: `1.0.0`.

`wise-backspace.nvim` leaves ordinary text deletion to native `<BS>`, so typo fixes remain part of insert redo and work with `.`. It only takes over when everything to the left of the cursor on the current line is whitespace, then returns key sequences that move the caret back to a better indent position.

## Behavior

- On ordinary text, return native `<BS>`.
- On a whitespace-only line, remove all spaces and then join upward with native line deletion.
- In leading spaces, prefer the current line's `indentexpr` result when it is smaller than the current indent.
- Otherwise, move to the nearest lower `shiftwidth()` boundary.
- If the previous non-empty line ends with an opener such as `{`, `(`, `[`, `<`, or `:`, avoid moving deeper over-indented lines below that opened block's first indent level.
- If the leading whitespace contains a tab, return native `<BS>`.
- Pair deletion is intentionally out of scope. If you use `nvim-autopairs`, keep `map_bs = false`.

## Setup

```lua
require("wise-backspace").setup()
```

With lazy.nvim:

```lua
{
  "cotrin8672/wise-backspace.nvim",
  tag = "v1.0.0",
  event = { "InsertEnter", "CmdlineEnter" },
  opts = {
    ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  },
}
```

The only option is `ignored_filetypes`.

```lua
require("wise-backspace").setup({
  ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
})
```

Default ignored filetypes:

```lua
{ "", "python", "haskell", "markdown", "text" }
```

Lazy-loading on the first insert or command-line entry is supported:

```lua
vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
  once = true,
  callback = function()
    require("wise-backspace").setup()
  end,
})
```
