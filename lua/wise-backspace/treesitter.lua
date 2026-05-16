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
  matlab = {
    block_nodes = {
      if_statement = true,
      for_statement = true,
      while_statement = true,
      function_definition = true,
      switch_statement = true,
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

  local filetype = vim.bo.filetype
  local lang = language_api.get_lang(filetype) or filetype
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

local function inspect_block_context(node, provider, context)
  if not node then
    return
  end

  if provider.block_nodes[node:type()] then
    local start_row, _, end_row = node:range()
    if start_row == context.previous_zero and start_row < context.current_zero and context.current_zero <= end_row then
      context.after_previous_line = true
    end
    if start_row == context.previous_zero and end_row == context.current_zero + 1 then
      context.ends_after_current_line = true
    end
    if context.current_zero == start_row + 1 and end_row == start_row + 2 then
      context.empty_block = true
    end
  end

  for index = 0, node:child_count() - 1 do
    inspect_block_context(node:child(index), provider, context)
  end
end

function M.block_context(opts, current_row, previous_row)
  local context = {
    current_zero = current_row - 1,
    previous_zero = previous_row and previous_row - 1 or -1,
    after_previous_line = false,
    ends_after_current_line = false,
    empty_block = false,
  }

  local parser, provider = parser_for(opts)
  if not parser then
    return context
  end

  local trees = parse(parser)
  if not trees then
    return context
  end

  for _, tree in ipairs(trees) do
    inspect_block_context(tree:root(), provider, context)
  end

  return context
end

function M.block_after_previous_line(opts, current_row, previous_row)
  return M.block_context(opts, current_row, previous_row).after_previous_line
end

function M.block_ends_after_current_line(opts, current_row, previous_row)
  return M.block_context(opts, current_row, previous_row).ends_after_current_line
end

function M.empty_block(opts, current_row)
  return M.block_context(opts, current_row).empty_block
end

return M
