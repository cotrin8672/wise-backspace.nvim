# wise-backspace.nvim

Smart Backspace for Neovim insert mode.

Current release: `1.0.1`.

`wise-backspace.nvim` leaves ordinary text deletion to native `<BS>`, so typo fixes remain part of insert redo and work with `.`. It only takes over when everything to the left of the cursor on the current line is indentation, then removes that indentation all at once.

## Behavior

- On ordinary text, return native `<BS>`.
- When the cursor's left side contains only spaces or tabs, remove all of that indentation.
- On a whitespace-only line, remove all indentation and then join upward with native line deletion.
- Pair deletion is intentionally out of scope. If you use `nvim-autopairs`, keep `map_bs = false`.

## Setup

```lua
require("wise-backspace").setup()
```

With lazy.nvim:

```lua
{
  "cotrin8672/wise-backspace.nvim",
  tag = "v1.0.1",
  event = { "InsertEnter", "CmdlineEnter" },
  opts = {
    ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  },
}
```

Options:

- `ignored_filetypes`: filetypes that always use native `<BS>`.

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
