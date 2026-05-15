local M = {}

local function current_line_context()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return row, col, vim.api.nvim_get_current_line()
end

local function is_leading_spaces(text)
  return text ~= "" and text:find("^ +$") ~= nil
end

local function contains_tab(text)
  return text:find("\t", 1, true) ~= nil
end

local function is_spaces_only_line(line)
  return line:find("^ *$") ~= nil
end

local function keys_for_delete(count)
  if count == 1 then
    return "<BS>"
  end
  return string.rep("<C-G>U<Left>", count) .. string.rep("<Del>", count)
end

local function keys_for_blank_line(col, line_length)
  return string.rep("<C-G>U<Left>", col) .. string.rep("<Del>", line_length) .. "<BS>"
end

function M.backspace_keys()
  local _, col, line = current_line_context()
  local before_cursor = line:sub(1, col)

  if not is_leading_spaces(before_cursor) or contains_tab(before_cursor) then
    return "<BS>"
  end

  if is_spaces_only_line(line) then
    return keys_for_blank_line(col, #line)
  end

  return keys_for_delete(col)
end

return M
