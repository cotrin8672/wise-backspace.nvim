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

local function termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feed(keys)
  vim.api.nvim_feedkeys(termcodes(keys), "xt", false)
end

local function delete_left(count)
  if count == 1 then
    return "<BS>"
  end
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
  eq(wise.backspace(), delete_left(4))

  wise.setup({ ignored_filetypes = { "markdown" } })
  eq(wise.backspace(), "<BS>")
end)

test("ordinary text returns native backspace", function()
  reset({ "  got" })
  set_cursor(1, 5)
  eq(wise.backspace(), "<BS>")
end)

test("ignored default filetypes return native backspace", function()
  reset({ "        value" })
  vim.bo.filetype = "markdown"
  set_cursor(1, 8)
  eq(wise.backspace(), "<BS>")

  vim.bo.filetype = ""
  eq(wise.backspace(), "<BS>")
end)

test("leading spaces before text are deleted all at once", function()
  reset({ "        value" })
  set_cursor(1, 8)
  eq(wise.backspace(), delete_left(8))

  reset({ "      value" })
  set_cursor(1, 6)
  eq(wise.backspace(), delete_left(6))

  reset({ "    value" })
  set_cursor(1, 4)
  eq(wise.backspace(), delete_left(4))
end)

test("single leading space deletion stays native", function()
  reset({ " x" })
  set_cursor(1, 1)
  eq(wise.backspace(), "<BS>")
end)

test("indentexpr does not limit full leading indent deletion", function()
  reset({ "        value" })
  vim.g.wise_backspace_test_indent = 4
  vim.bo.indentexpr = "g:wise_backspace_test_indent"
  set_cursor(1, 8)
  eq(wise.backspace(), delete_left(8))
end)

test("shiftwidth does not limit full leading indent deletion", function()
  reset({ "        value" })
  vim.bo.shiftwidth = 2
  set_cursor(1, 8)
  eq(wise.backspace(), delete_left(8))
end)

test("whitespace-only line deletes all spaces and joins upward", function()
  reset({ "if ok {", "        " })
  set_cursor(2, 8)
  eq(wise.backspace(), blank_line_delete(7, 8))
end)

test("leading tab returns native backspace", function()
  reset({ "\t    value" })
  set_cursor(1, 5)
  eq(wise.backspace(), "<BS>")
end)

test("mapping deletes all leading spaces before text", function()
  reset({ "        value" })
  set_cursor(1, 8)
  feed("i<BS><Esc>")
  eq(vim.api.nvim_get_current_line(), "value")
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

test("mapping joins whitespace-only line upward without changing following lines", function()
  reset({ "if ok {", "        ", "after()" })
  set_cursor(2, 0)
  feed("A<BS><Esc>")
  eq(vim.api.nvim_buf_line_count(0), 2)
  eq(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "if ok {")
  eq(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1], "after()")
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
