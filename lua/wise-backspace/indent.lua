local treesitter = require("wise-backspace.treesitter")

local M = {}

local function current_line_context()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return row, col, vim.api.nvim_get_current_line()
end

local function contains_only_whitespace(text)
  return text:find("%S") == nil
end

local function leading_whitespace(line)
  return line:match("^[ \t]*")
end

local function leading_whitespace_width(line)
  local tabstop = vim.bo.tabstop
  local width = 0
  for char in leading_whitespace(line):gmatch(".") do
    if char == "\t" then
      width = width + tabstop
    else
      width = width + 1
    end
  end
  return width
end

local function first_non_whitespace_col(line)
  local index = line:find("%S")
  if index then
    return index - 1
  end
  return #line
end

local function previous_non_whitespace_line(row)
  for lnum = row - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
    if line and not contains_only_whitespace(line) then
      return line, lnum
    end
  end
end

local function line_at(row)
  return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
end

local function is_opening_pair(char)
  return char == "(" or char == "[" or char == "{" or char == "<"
end

local function line_last_non_whitespace_char(line)
  return line and line:match("(%S)%s*$")
end

local function line_first_non_whitespace_char(line)
  return line and line:match("^%s*(%S)")
end

local function within_empty_brackets(prev_line, current_line, next_line)
  if not prev_line or not next_line or not contains_only_whitespace(current_line) then
    return false
  end

  local previous = line_last_non_whitespace_char(prev_line)
  local next = line_first_non_whitespace_char(next_line)
  return (previous == "(" and next == ")")
    or (previous == "[" and next == "]")
    or (previous == "{" and next == "}")
    or (previous == "<" and next == ">")
end

local function contains_pair(line, col)
  local before = line:sub(col, col)
  local after = line:sub(col + 1, col + 1)
  return (before == "(" and after == ")")
    or (before == "[" and after == "]")
    or (before == "{" and after == "}")
    or (before == "<" and after == ">")
    or (before == "'" and after == "'")
    or (before == '"' and after == '"')
    or (before == "`" and after == "`")
end

local function current_line_starts_with_dot(line)
  return line:match("^%s*%.") ~= nil
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

local function collapse_empty_brackets(col, current_len, next_line)
  local next_indent = #(next_line:match("^[ \t]*"))
  return left(col) .. del(current_len) .. "<BS><Del>" .. del(next_indent)
end

local function collapse_empty_keyword_block(col, current_len, next_line)
  local next_indent = #(next_line:match("^[ \t]*"))
  return left(col) .. del(current_len) .. "<BS> <Del>" .. del(next_indent)
end

function M.backspace_keys(treesitter_opts)
  local row, cursor_col, current_line = current_line_context()
  local behind_cursor = current_line:sub(1, cursor_col)

  if not contains_only_whitespace(behind_cursor) then
    if contains_pair(current_line, cursor_col) then
      return "<BS><Del>"
    end
    return "<BS>"
  end

  local col = first_non_whitespace_col(current_line)
  local leading_len = #leading_whitespace(current_line)
  local prev_line = line_at(row - 1)
  local next_line = line_at(row + 1)
  local prev_non_ws_line, prev_non_ws_row = previous_non_whitespace_line(row)

  if row == 1 then
    return replace_leading(col, leading_len, "")
  end

  if not prev_non_ws_line then
    if leading_whitespace_width(current_line) > 0 then
      return replace_leading(col, leading_len, "")
    end
    return "<BS>"
  end

  if within_empty_brackets(prev_line, current_line, next_line) then
    return collapse_empty_brackets(col, #current_line, next_line)
  end

  if contains_only_whitespace(current_line) and treesitter.empty_block(treesitter_opts, row) then
    return collapse_empty_keyword_block(col, #current_line, next_line)
  end

  local previous_indent = leading_whitespace(prev_non_ws_line)
  local previous_indent_width = leading_whitespace_width(prev_non_ws_line)
  local current_indent_width = leading_whitespace_width(current_line)
  local previous_ends_opening_pair = is_opening_pair(line_last_non_whitespace_char(prev_non_ws_line))
  local previous_starts_keyword_block = treesitter.block_after_previous_line(treesitter_opts, row, prev_non_ws_row)

  if previous_ends_opening_pair or current_line_starts_with_dot(current_line) then
    local correct_indent = previous_indent .. string.rep(" ", vim.bo.shiftwidth)
    local correct_width = previous_indent_width + vim.bo.shiftwidth
    if current_indent_width > correct_width then
      return replace_leading(col, leading_len, correct_indent)
    end
    return join_after_removing_leading(col, leading_len)
  end

  if previous_starts_keyword_block then
    local correct_indent = previous_indent .. string.rep(" ", vim.bo.shiftwidth)
    local correct_width = previous_indent_width + vim.bo.shiftwidth
    if current_indent_width > correct_width then
      return replace_leading(col, leading_len, correct_indent)
    end
  end

  if current_indent_width > previous_indent_width then
    return replace_leading(col, leading_len, previous_indent)
  end

  return join_after_removing_leading(col, leading_len)
end

return M
