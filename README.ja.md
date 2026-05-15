# wise-backspace.nvim

Neovim の insert mode で使う smart Backspace プラグインです。

現在のリリースは `1.0.0` です。

通常の文字削除は native `<BS>` に委譲します。そのため、入力中の typo 修正は insert redo に残り、`.` repeat でも Backspace が期待通りに効きます。カーソル左側が現在行の先頭空白だけの場合に限り、より自然なインデント位置へ戻るキー列を返します。

## 動作

- 通常文字上では native `<BS>` を返す。
- 空白だけの行では、spaces をすべて削除してから native の行削除で前行へ join する。
- 先頭空白では、現在行の `indentexpr` が現在インデントより小さい値を返す場合、その位置へ戻る。
- `indentexpr` が使えない場合は、`shiftwidth()` のひとつ前の境界へ戻る。
- 直前の非空行が `{`、`(`、`[`、`<`、`:` などの opener で終わる場合、開いたブロックの最初のインデントより浅く戻りすぎないようにする。
- 先頭空白に tab が含まれる場合は native `<BS>` を返す。
- ペア削除は実装しない。`nvim-autopairs` を使う場合は `map_bs = false` を維持する。

## セットアップ

```lua
require("wise-backspace").setup()
```

lazy.nvim の例:

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

設定できるオプションは `ignored_filetypes` だけです。

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
