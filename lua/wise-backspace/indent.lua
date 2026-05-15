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

local function leading_space_count(line)
  return #(line:match("^ *"))
end

local function previous_non_empty_line(lnum)
  for candidate = lnum - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, candidate - 1, candidate, false)[1]
    if line:find("%S") then
      return line
    end
  end
end

local function line_ends_with_opener(line)
  return line:find("[%{%(%[<:]%s*$") ~= nil
end

local function indentexpr_target(lnum)
  local expr = vim.bo.indentexpr
  if expr == "" then
    return nil
  end

  local previous_lnum = vim.v.lnum
  vim.v.lnum = lnum
  local ok, value = pcall(vim.fn.eval, expr)
  vim.v.lnum = previous_lnum
  if not ok then
    error(value, 0)
  end

  local target = tonumber(value)
  if target and target >= 0 then
    return target
  end
end

local function shiftwidth_target(current)
  local shiftwidth = vim.fn.shiftwidth()
  return math.floor((current - 1) / shiftwidth) * shiftwidth
end

local function opener_floor(lnum)
  local previous = previous_non_empty_line(lnum)
  if previous and line_ends_with_opener(previous) then
    return leading_space_count(previous) + vim.fn.shiftwidth()
  end
end

local function target_column(lnum, current)
  local proper = indentexpr_target(lnum)
  if proper and proper < current then
    return proper
  end

  local target = shiftwidth_target(current)
  local floor = opener_floor(lnum)
  if floor and current > floor and target < floor then
    return floor
  end
  return target
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
  local lnum, col, line = current_line_context()
  local before_cursor = line:sub(1, col)

  if not is_leading_spaces(before_cursor) or contains_tab(before_cursor) then
    return "<BS>"
  end

  if is_spaces_only_line(line) then
    return keys_for_blank_line(col, #line)
  end

  local target = target_column(lnum, col)
  return keys_for_delete(col - target)
end

return M
