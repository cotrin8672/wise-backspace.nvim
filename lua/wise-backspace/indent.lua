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
      return line, candidate
    end
  end
end

local function opener_column(line)
  local column = line:find("[%{%(%[<:]%s*$")
  if column then
    return column - 1
  end
end

local function is_non_code_node_type(node_type)
  return node_type:find("comment", 1, true)
    or node_type:find("string", 1, true)
    or node_type:find("character", 1, true)
    or node_type:find("regex", 1, true)
end

local function treesitter_opener_is_code(lnum, col)
  if not vim.treesitter or not vim.treesitter.get_node then
    return nil
  end

  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = 0,
    pos = { lnum - 1, col },
    include_anonymous = true,
  })
  if not ok or not node then
    return nil
  end

  while node do
    if is_non_code_node_type(node:type()) then
      return false
    end
    node = node:parent()
  end
  return true
end

local function treesitter_opener_line(lnum)
  local previous, previous_lnum = previous_non_empty_line(lnum)
  local column = previous and opener_column(previous)
  if not column then
    return nil
  end

  local is_code = treesitter_opener_is_code(previous_lnum, column)
  if is_code == nil then
    return nil
  end
  if is_code then
    return previous
  end
  return false
end

local function character_opener_line(lnum)
  local previous = previous_non_empty_line(lnum)
  if previous and opener_column(previous) then
    return previous
  end
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

local function opener_floor(lnum, opts)
  local previous
  if opts.treesitter then
    previous = treesitter_opener_line(lnum)
  end
  if previous == nil then
    previous = character_opener_line(lnum)
  end

  if previous then
    return leading_space_count(previous) + vim.fn.shiftwidth()
  end
end

local function target_column(lnum, current, opts)
  local proper = indentexpr_target(lnum)
  if proper and proper < current then
    return proper
  end

  local target = shiftwidth_target(current)
  local floor = opener_floor(lnum, opts)
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

function M.backspace_keys(opts)
  opts = opts or {}
  local lnum, col, line = current_line_context()
  local before_cursor = line:sub(1, col)

  if not is_leading_spaces(before_cursor) or contains_tab(before_cursor) then
    return "<BS>"
  end

  if is_spaces_only_line(line) then
    return keys_for_blank_line(col, #line)
  end

  local target = target_column(lnum, col, opts)
  return keys_for_delete(col - target)
end

return M
