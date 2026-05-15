local M = {}

local function current_line_context()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return row, col, vim.api.nvim_get_current_line()
end

local function is_leading_whitespace(text)
  return text ~= "" and text:find("^[ \t]+$") ~= nil
end

local function is_spaces_only_line(line)
  return line:find("^[ \t]*$") ~= nil
end

local function leading_indentation_width(line)
  return #(line:match("^[ \t]*"))
end

local function keys_for_delete(left_count, delete_count)
  if left_count == 1 and delete_count == 1 then
    return "<BS>"
  end
  return string.rep("<C-G>U<Left>", left_count) .. string.rep("<Del>", delete_count)
end

local function keys_for_blank_line(col, line_length)
  return string.rep("<C-G>U<Left>", col) .. string.rep("<Del>", line_length) .. "<BS>"
end

local function keys_for_indented_text(col, indent_width)
  return keys_for_delete(col, indent_width) .. "<BS>"
end

function M.backspace_keys()
  local _, col, line = current_line_context()
  local before_cursor = line:sub(1, col)

  if not is_leading_whitespace(before_cursor) then
    return "<BS>"
  end

  if is_spaces_only_line(line) then
    return keys_for_blank_line(col, #line)
  end

  return keys_for_indented_text(col, leading_indentation_width(line))
end

return M
