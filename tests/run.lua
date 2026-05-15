local wise = require("wise-backspace")

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function eq(actual, expected)
  if actual ~= expected then
    error(("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function errors(fn)
  local ok = pcall(fn)
  if ok then
    error("expected error", 2)
  end
end

local function termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feed(keys)
  vim.api.nvim_feedkeys(termcodes(keys), "xt", false)
end

local function smart_delete(count)
  return string.rep("<C-G>U<Left>", count) .. string.rep("<Del>", count)
end

local function blank_line_delete(col, line_length)
  return string.rep("<C-G>U<Left>", col) .. string.rep("<Del>", line_length) .. "<BS>"
end

local function reset(lines)
  vim.cmd("enew!")
  vim.bo.filetype = "lua"
  vim.bo.indentexpr = ""
  vim.bo.expandtab = true
  vim.bo.shiftwidth = 4
  vim.bo.tabstop = 8
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  wise.setup()
end

local function set_cursor(line, col)
  vim.api.nvim_win_set_cursor(0, { line, col })
end

test("insert and cmdline mappings are installed as expr mappings", function()
  reset()
  local insert = vim.fn.maparg("<BS>", "i", false, true)
  local cmdline = vim.fn.maparg("<BS>", "c", false, true)

  eq(insert.expr, 1)
  eq(insert.desc, "Wise Backspace")
  eq(cmdline.expr, 1)
  eq(cmdline.desc, "Wise Backspace")
end)

test("setup is idempotent and replaces ignored filetypes", function()
  reset({ "    x" })
  wise.setup({ ignored_filetypes = { "lua" } })
  vim.bo.filetype = "markdown"
  set_cursor(1, 4)
  eq(wise.backspace(), smart_delete(4))

  wise.setup({ ignored_filetypes = { "markdown" } })
  eq(wise.backspace(), "<BS>")
end)

test("ordinary text returns native backspace", function()
  reset({ "  got" })
  set_cursor(1, 5)
  eq(wise.backspace(), "<BS>")
end)

test("ignored default filetypes return native backspace", function()
  reset({ "        " })
  vim.bo.filetype = "markdown"
  set_cursor(1, 8)
  eq(wise.backspace(), "<BS>")

  vim.bo.filetype = ""
  eq(wise.backspace(), "<BS>")
end)

test("leading spaces delete to previous shiftwidth boundary", function()
  reset({ "        value" })
  set_cursor(1, 8)
  eq(wise.backspace(), smart_delete(4))

  reset({ "      value" })
  set_cursor(1, 6)
  eq(wise.backspace(), smart_delete(2))

  reset({ "    value" })
  set_cursor(1, 4)
  eq(wise.backspace(), smart_delete(4))
end)

test("single leading space deletion stays native", function()
  reset({ " x" })
  set_cursor(1, 1)
  eq(wise.backspace(), "<BS>")
end)

test("whitespace-only line deletes all spaces and joins upward", function()
  reset({ "if ok {", "        " })
  set_cursor(2, 8)
  eq(wise.backspace(), blank_line_delete(7, 8))
end)

test("shiftwidth zero follows Neovim effective shiftwidth", function()
  reset({ "        value" })
  vim.bo.shiftwidth = 0
  vim.bo.tabstop = 2
  set_cursor(1, 8)
  eq(wise.backspace(), smart_delete(2))
end)

test("indentexpr smaller than current indent wins", function()
  reset({ "      value" })
  vim.g.wise_backspace_test_indent = 2
  vim.bo.indentexpr = "g:wise_backspace_test_indent"
  set_cursor(1, 6)
  eq(wise.backspace(), smart_delete(4))
end)

test("indentexpr is evaluated with the current line in v:lnum", function()
  reset({ "root", "      value" })
  _G.WiseBackspaceIndentByLnum = function()
    if vim.v.lnum == 2 then
      return 2
    end
    return 0
  end
  vim.bo.indentexpr = "v:lua.WiseBackspaceIndentByLnum()"
  set_cursor(2, 6)
  eq(wise.backspace(), smart_delete(4))
end)

test("indentexpr equal or larger than current indent falls back", function()
  reset({ "      value" })
  vim.g.wise_backspace_test_indent = 8
  vim.bo.indentexpr = "g:wise_backspace_test_indent"
  set_cursor(1, 6)
  eq(wise.backspace(), smart_delete(2))
end)

test("indentexpr minus one falls back", function()
  reset({ "      value" })
  vim.g.wise_backspace_test_indent = -1
  vim.bo.indentexpr = "g:wise_backspace_test_indent"
  set_cursor(1, 6)
  eq(wise.backspace(), smart_delete(2))
end)

test("indentexpr errors are not swallowed", function()
  reset({ "      value" })
  vim.v.lnum = 42
  vim.bo.indentexpr = "WiseBackspaceMissingIndent()"
  set_cursor(1, 6)
  errors(function()
    wise.backspace()
  end)
  eq(vim.v.lnum, 42)
end)

test("opener fallback keeps over-indented lines inside the opened block", function()
  reset({ "if ok {", "", "        value" })
  set_cursor(3, 8)
  eq(wise.backspace(), smart_delete(4))
end)

test("opener fallback does not trap the cursor at the first block indent", function()
  reset({ "if ok {", "    value" })
  set_cursor(2, 4)
  eq(wise.backspace(), smart_delete(4))
end)

test("without opener fallback uses the nearest lower boundary", function()
  reset({ "let ok = true", "", "        value" })
  set_cursor(3, 8)
  eq(wise.backspace(), smart_delete(4))
end)

test("leading tab returns native backspace", function()
  reset({ "\t    value" })
  set_cursor(1, 5)
  eq(wise.backspace(), "<BS>")
end)

test("mapping changes real buffer text for smart indentation", function()
  reset({ "        value" })
  set_cursor(1, 8)
  feed("i<BS><Esc>")
  eq(vim.api.nvim_get_current_line(), "    value")
end)

test("mapping clears first whitespace-only line at insert end", function()
  reset({ "        " })
  set_cursor(1, 0)
  feed("A<BS><Esc>")
  eq(vim.api.nvim_get_current_line(), "")
end)

test("mapping joins whitespace-only line upward", function()
  reset({ "if ok {", "        " })
  set_cursor(2, 0)
  feed("A<BS><Esc>")
  eq(vim.api.nvim_buf_line_count(0), 1)
  eq(vim.api.nvim_get_current_line(), "if ok {")
end)

test("mapping changes real buffer text natively for ordinary text", function()
  reset({ "got" })
  set_cursor(1, 3)
  feed("a<BS><Esc>")
  eq(vim.api.nvim_get_current_line(), "go")
end)

test("dot repeat keeps ordinary backspace in the insert redo sequence", function()
  reset({ "alpha beta" })
  set_cursor(1, 0)
  feed("ciwgpj<BS>t-5-mini<Esc>w.")
  eq(vim.api.nvim_get_current_line(), "gpt-5-mini gpt-5-mini")
end)

local failures = {}

for _, case in ipairs(tests) do
  local ok, err = xpcall(case.fn, debug.traceback)
  if ok then
    print("ok - " .. case.name)
  else
    failures[#failures + 1] = "not ok - " .. case.name .. "\n" .. err
  end
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    print(failure)
  end
  vim.cmd("cquit")
end

print(("passed %d tests"):format(#tests))
vim.cmd("qa!")
