local M = {}

local providers = {
  lua = {
    block_nodes = {
      if_statement = true,
      do_statement = true,
      while_statement = true,
      for_statement = true,
      repeat_statement = true,
      function_declaration = true,
      function_definition = true,
    },
  },
}

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

local function parser_for(opts)
  if not opts or not opts.enabled or not vim.treesitter or not vim.treesitter.get_parser then
    return nil
  end

  local language_api = vim.treesitter.language
  if not language_api or not language_api.get_lang then
    return nil
  end

  local lang = language_api.get_lang(vim.bo.filetype)
  if not lang or not providers[lang] or not contains(opts.languages, lang) then
    return nil
  end

  local ok, parser = pcall(vim.treesitter.get_parser, 0, lang)
  if not ok or not parser then
    return nil
  end

  return parser, providers[lang]
end

local function parse(parser)
  local ok, trees = pcall(parser.parse, parser)
  if not ok then
    return nil
  end
  return trees
end

local function find_block(node, provider, predicate)
  if not node then
    return nil
  end

  local found
  if provider.block_nodes[node:type()] and predicate(node) then
    found = node
  end

  for index = 0, node:child_count() - 1 do
    local child = find_block(node:child(index), provider, predicate)
    if child then
      found = child
    end
  end

  return found
end

local function find_supported_block(opts, predicate)
  local parser, provider = parser_for(opts)
  if not parser then
    return nil
  end

  local trees = parse(parser)
  if not trees then
    return nil
  end

  for _, tree in ipairs(trees) do
    local block = find_block(tree:root(), provider, predicate)
    if block then
      return block
    end
  end
end

function M.block_after_previous_line(opts, current_row, previous_row)
  return find_supported_block(opts, function(node)
    local start_row, _, end_row = node:range()
    local current_zero = current_row - 1
    local previous_zero = previous_row - 1
    return start_row == previous_zero and start_row < current_zero and current_zero <= end_row
  end) ~= nil
end

function M.block_ends_after_current_line(opts, current_row, previous_row)
  return find_supported_block(opts, function(node)
    local start_row, _, end_row = node:range()
    local current_zero = current_row - 1
    local previous_zero = previous_row - 1
    return start_row == previous_zero and end_row == current_zero + 1
  end) ~= nil
end

function M.empty_block(opts, current_row)
  return find_supported_block(opts, function(node)
    local start_row, _, end_row = node:range()
    local current_zero = current_row - 1
    return current_zero == start_row + 1 and end_row == start_row + 2
  end) ~= nil
end

return M
