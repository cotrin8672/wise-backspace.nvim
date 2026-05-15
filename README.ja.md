# wise-backspace.nvim

Neovim の insert mode で使う smart Backspace プラグインです。

現在のリリースは `1.0.1` です。

通常の文字削除は native `<BS>` に委譲します。そのため、入力中の typo 修正は insert redo に残り、`.` repeat でも Backspace が期待通りに効きます。カーソル左側がインデントだけの場合に限り、そのインデントを一気に削除するキー列を返します。

## 動作

- 通常文字上では native `<BS>` を返す。
- カーソル左側が spaces または tabs だけの場合、そのインデントをすべて削除する。
- 空白だけの行では、インデントをすべて削除してから native の行削除で前行へ join する。
- ペア削除は実装しない。`nvim-autopairs` を使う場合は `map_bs = false` を維持する。

## セットアップ

```lua
require("wise-backspace").setup()
```

lazy.nvim の例:

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

オプション:

- `ignored_filetypes`: 常に native `<BS>` を使う filetype。

```lua
require("wise-backspace").setup({
  ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
})
```

デフォルトの ignored filetypes:

```lua
{ "", "python", "haskell", "markdown", "text" }
```

初回の insert mode / command-line entry で lazy-load する例:

```lua
vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
  once = true,
  callback = function()
    require("wise-backspace").setup()
  end,
})
```
