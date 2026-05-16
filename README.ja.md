# wise-backspace.nvim

Neovim の insert mode で使う smart Backspace プラグインです。

現在のリリースは `1.0.4` です。

通常の文字削除は native `<BS>` に委譲します。そのため、入力中の typo 修正は insert redo に残り、`.` repeat でも Backspace が期待通りに効きます。カーソル左側がインデントだけの場合に限り、インデント補正または前行 join を行うキー列を返します。

## 動作

- 通常文字上では native `<BS>` を返す。
- 単純な対応ペアの間では、左右のペアをまとめて削除する。
- カーソル左側が spaces または tabs だけの場合、カーソルがインデント途中にあっても、最初の非空白文字または行末にいるものとして扱う。
- 1 行目では、前行 join せずに先頭インデントだけを削除する。
- インデントが深すぎる行では、直前の非空白行と同じインデントまで戻す。
- 直前の非空白行が opening pair で終わる場合、または現在行が dot-prefixed continuation の場合、深すぎるインデントを `shiftwidth` 1 段分まで戻す。すでにその位置なら前行へ join する。
- 空白だけの行が空の bracket block 内にある場合、block を 1 行に collapse する。
- Tree-sitter support を明示的に有効化した場合、Lua の `if ... end` などの keyword block でもインデント補正と空 block collapse を行う。
- それ以外では、先頭インデントを削除して native の行削除で前行へ join する。

## セットアップ

```lua
require("wise-backspace").setup()
```

lazy.nvim の例:

```lua
{
  "cotrin8672/wise-backspace.nvim",
  tag = "v1.0.4",
  event = "InsertEnter",
  opts = {
    ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  },
}
```

オプション:

- `ignored_filetypes`: 常に native `<BS>` を使う filetype。
- `treesitter`: optional な Tree-sitter block support。デフォルトでは無効。

```lua
require("wise-backspace").setup({
  ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
  treesitter = {
    enabled = false,
    languages = { "lua" },
  },
})
```

デフォルトの ignored filetypes:

```lua
{ "", "python", "haskell", "markdown", "text" }
```

Tree-sitter support は Neovim 組み込みの Tree-sitter API を使い、`nvim-treesitter` には依存しません。明示的に opt-in した場合だけ有効です。

```lua
require("wise-backspace").setup({
  treesitter = {
    enabled = true,
    languages = { "lua" },
  },
})
```

現在の built-in provider は Lua の `if ... end`, `do ... end`, `while ... end`, `for ... end`, `repeat ... until`, function block に対応します。未対応言語や parser がない場合は、通知せずデフォルト挙動へ fallback します。

初回の insert mode / command-line entry で lazy-load する例:

```lua
vim.api.nvim_create_autocmd("InsertEnter", {
  once = true,
  callback = function()
    require("wise-backspace").setup()
  end,
})
```
