local wise = require("wise-backspace")

local tests = {}

local current_treesitter_enabled = false

local function test(name, fn, opts)
  tests[#tests + 1] = { name = name, fn = fn, variants = not (opts and opts.variants == false) }
end

local function eq(actual, expected)
  local same = actual == expected
  if type(actual) == "table" or type(expected) == "table" then
    same = vim.deep_equal(actual, expected)
  end

  if not same then
    error(("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feed(keys)
  vim.api.nvim_feedkeys(termcodes(keys), "xt", false)
end

local function left(count)
  return string.rep("<C-G>U<Left>", count)
end

local function del(count)
  return string.rep("<Del>", count)
end

local function replace_leading(col, leading_len, replacement)
  return left(col) .. del(leading_len) .. replacement
end

local function join_after_removing_leading(col, leading_len)
  return replace_leading(col, leading_len, "") .. "<BS>"
end

local function setup(opts)
  opts = opts or {}
  opts.treesitter = opts.treesitter or {
    enabled = current_treesitter_enabled,
    languages = { "lua" },
  }
  wise.setup(opts)
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
  setup()
end

local function set_cursor(line, col)
  vim.api.nvim_win_set_cursor(0, { line, col })
end

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
  setup({ ignored_filetypes = { "lua" } })
  vim.bo.filetype = "markdown"
  set_cursor(1, 4)
  eq(wise.backspace(), replace_leading(4, 4, ""))

  setup({ ignored_filetypes = { "markdown" } })
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

test("first line deletes leading indentation without joining", function()
  reset({ "        value" })
  set_cursor(1, 8)
  eq(wise.backspace(), replace_leading(8, 8, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "value" })
end)

test("cursor inside indentation behaves as if it were at first non-whitespace", function()
  reset({ "            value" })
  set_cursor(1, 4)
  eq(wise.backspace(), replace_leading(12, 12, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "value" })
end)

test("tabs and spaces are both indentation", function()
  reset({ "\t    value" })
  set_cursor(1, 3)
  eq(wise.backspace(), replace_leading(5, 5, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "value" })
end)

test("over-indented line under normal code unindents to previous non-empty line", function()
  reset({ "root", "        value" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "root", "value" })
end)

test("over-indented line preserves previous non-empty indentation", function()
  reset({ "  root", "        value" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, "  "))

  feed("i<BS><Esc>")
  eq(lines(), { "  root", "  value" })
end)

test("correctly indented line joins with previous line", function()
  reset({ "root", "value" })
  set_cursor(2, 0)
  feed("i<BS><Esc>")
  eq(lines(), { "rootvalue" })
end)

test("left side indentation with right text joins when indentation already matches", function()
  reset({ "  root", "  value" })
  set_cursor(2, 2)
  eq(wise.backspace(), join_after_removing_leading(2, 2))

  feed("i<BS><Esc>")
  eq(lines(), { "  rootvalue" })
end)

test("opening pair overindent returns to one shiftwidth deeper", function()
  reset({ "if ok {", "        value" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, "    "))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok {", "    value" })
end)

test("opening pair correct indent joins upward", function()
  reset({ "if ok {", "    value" })
  set_cursor(2, 4)
  eq(wise.backspace(), join_after_removing_leading(4, 4))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok {value" })
end)

test("dot-prefixed continuation overindent returns to one shiftwidth deeper", function()
  reset({ "object", "        .call()" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, "    "))

  feed("i<BS><Esc>")
  eq(lines(), { "object", "    .call()" })
end)

test("dot-prefixed continuation at correct indent joins upward", function()
  reset({ "object", "    .call()" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "object.call()" })
end)

test("whitespace-only line under opening pair unindents before it joins", function()
  reset({ "if ok {", "        " })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, "    "))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok {", "    " })
end)

test("empty bracket block collapses to a single line", function()
  reset({ "call({", "        ", "})" })
  set_cursor(2, 8)
  feed("i<BS><Esc>")
  eq(lines(), { "call({})" })
end)

test("only whitespace before first non-empty line removes indentation", function()
  reset({ "", "        value" })
  set_cursor(2, 8)
  feed("i<BS><Esc>")
  eq(lines(), { "", "value" })
end)

test("blank line before first non-empty line joins upward after indentation is gone", function()
  reset({ "", "value" })
  set_cursor(2, 0)
  feed("i<BS><Esc>")
  eq(lines(), { "value" })
end)

test("previous blank line is removed after current indentation matches previous non-empty line", function()
  reset({ "root", "", "value" })
  set_cursor(3, 0)
  feed("i<BS><Esc>")
  eq(lines(), { "root", "value" })
end)

test("mapping keeps native behavior when cursor left side contains text", function()
  reset({ "  hello" })
  set_cursor(1, 7)
  feed("a<BS><Esc>")
  eq(lines(), { "  hell" })
end)

test("mapping removes paired brackets when cursor is between them", function()
  reset({ "call()" })
  set_cursor(1, 5)
  feed("i<BS><Esc>")
  eq(lines(), { "call" })
end)

test("mapping removes paired quotes when cursor is between them", function()
  reset({ 'value = ""' })
  set_cursor(1, 9)
  feed("i<BS><Esc>")
  eq(lines(), { "value = " })
end)

test("mapping does not remove mismatched pair-like text", function()
  reset({ "call(]" })
  set_cursor(1, 5)
  feed("i<BS><Esc>")
  eq(lines(), { "call]" })
end)

test("dot repeat keeps ordinary backspace in the insert redo sequence", function()
  reset({ "alpha beta" })
  set_cursor(1, 0)
  feed("ciwgpj<BS>t-5-mini<Esc>w.")
  eq(lines(), { "gpt-5-mini gpt-5-mini" })
end)

test("dot repeat replays smart unindent", function()
  reset({ "root", "    x", "root", "    y" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "root", "x", "root", "    y" })

  set_cursor(4, 4)
  feed(".")
  eq(lines(), { "root", "x", "root", "y" })
end)

test("treesitter disabled keeps lua keyword blocks on the default path", function()
  current_treesitter_enabled = false
  reset({ "if ok then", "        value", "end" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok then", "value", "end" })
end, { variants = false })

test("treesitter enabled unindents lua keyword block overindent to one shiftwidth", function()
  current_treesitter_enabled = true
  reset({ "if ok then", "        value", "end" })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, "    "))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok then", "    value", "end" })
end, { variants = false })

test("treesitter enabled does not join lua keyword block at correct indent", function()
  current_treesitter_enabled = true
  reset({ "if ok then", "    value", "end" })
  set_cursor(2, 4)
  eq(wise.backspace(), replace_leading(4, 4, ""))

  feed("i<BS><Esc>")
  eq(lines(), { "if ok then", "value", "end" })
end, { variants = false })

test("treesitter enabled collapses empty lua if block", function()
  current_treesitter_enabled = true
  reset({ "if ok then", "    ", "end" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "if ok then end" })
end, { variants = false })

test("treesitter enabled collapses empty lua function block", function()
  current_treesitter_enabled = true
  reset({ "local function f()", "    ", "end" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "local function f() end" })
end, { variants = false })

test("treesitter enabled collapses empty lua do block", function()
  current_treesitter_enabled = true
  reset({ "do", "    ", "end" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "do end" })
end, { variants = false })

test("treesitter enabled collapses empty lua repeat block", function()
  current_treesitter_enabled = true
  reset({ "repeat", "    ", "until ok" })
  set_cursor(2, 4)
  feed("i<BS><Esc>")
  eq(lines(), { "repeat until ok" })
end, { variants = false })

test("treesitter enabled handles other supported lua block forms", function()
  local cases = {
    { { "while ok do", "        value", "end" }, { "while ok do", "    value", "end" } },
    { { "for i = 1, 3 do", "        value", "end" }, { "for i = 1, 3 do", "    value", "end" } },
    { { "local x = function()", "        value", "end" }, { "local x = function()", "    value", "end" } },
  }

  current_treesitter_enabled = true
  for _, case in ipairs(cases) do
    reset(case[1])
    set_cursor(2, 8)
    feed("i<BS><Esc>")
    eq(lines(), case[2])
  end
end, { variants = false })

test("treesitter ignores unsupported languages without errors", function()
  current_treesitter_enabled = true
  reset({ "if ok", "        value", "endif" })
  vim.bo.filetype = "vim"
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, ""))
end, { variants = false })

test("treesitter configured languages fall back when lua is not enabled", function()
  current_treesitter_enabled = true
  reset({ "if ok then", "        value", "end" })
  setup({ treesitter = { enabled = true, languages = { "query" } } })
  set_cursor(2, 8)
  eq(wise.backspace(), replace_leading(8, 8, ""))
end, { variants = false })

local failures = {}
local passed = 0

for _, case in ipairs(tests) do
  local variants = case.variants and { false, true } or { current_treesitter_enabled }
  for _, enabled in ipairs(variants) do
    current_treesitter_enabled = enabled
    local label = case.variants and ("%s [treesitter=%s]"):format(case.name, tostring(enabled)) or case.name
    local ok, err = xpcall(case.fn, debug.traceback)
    if ok then
      passed = passed + 1
      print("ok - " .. label)
    else
      failures[#failures + 1] = "not ok - " .. label .. "\n" .. err
    end
  end
end

if #failures > 0 then
  for _, failure in ipairs(failures) do
    print(failure)
  end
  vim.cmd("cquit")
end

print(("passed %d tests"):format(passed))
vim.cmd("qa!")
