local indent = require("wise-backspace.indent")

local M = {}

local defaults = {
  ignored_filetypes = { "", "python", "haskell", "markdown", "text" },
}

local config = {
  ignored_filetypes = vim.list_extend({}, defaults.ignored_filetypes),
}

local ignored_filetypes = {}

local function rebuild_ignored_filetypes()
  ignored_filetypes = {}
  for _, filetype in ipairs(config.ignored_filetypes) do
    ignored_filetypes[filetype] = true
  end
end

local function apply_config(opts)
  opts = opts or {}
  config = {
    ignored_filetypes = vim.list_extend({}, opts.ignored_filetypes or defaults.ignored_filetypes),
  }
  rebuild_ignored_filetypes()
end

rebuild_ignored_filetypes()

function M.backspace()
  if ignored_filetypes[vim.bo.filetype] then
    return "<BS>"
  end

  return indent.backspace_keys()
end

function M.setup(opts)
  apply_config(opts)

  vim.keymap.set("i", "<BS>", function()
    return M.backspace()
  end, {
    desc = "Wise Backspace",
    expr = true,
    replace_keycodes = true,
  })

  vim.keymap.set("c", "<BS>", function()
    return "<BS>"
  end, {
    desc = "Wise Backspace",
    expr = true,
    replace_keycodes = true,
  })
end

return M
