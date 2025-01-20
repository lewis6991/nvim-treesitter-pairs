local api = vim.api

local ns = api.nvim_create_namespace('nvim-treesitter-pairs')

--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @return [TSNode, vim.treesitter.Query][]
local function get_hl_ctx(bufnr, row, col)
  local parser = vim.treesitter.get_parser(bufnr)

  if not parser then
    return {}
  end

  --- @type [TSNode, vim.treesitter.Query][]
  local ret = {}

  parser:for_each_tree(function(tstree, tree)
    if not tstree or not vim.treesitter.is_in_node_range(tstree:root(), row, col) then
      return
    end

    --- @type boolean, vim.treesitter.Query
    local ok, query = pcall(function()
      return vim.treesitter.query.get(tree:lang(), 'highlights')
    end)

    if ok then
      ret[#ret+1] = { tstree:root(), query }
    end
  end)

  return ret
end

--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @param ctx? [TSNode, vim.treesitter.Query][]
--- @param pred fun(capture: string): boolean?
--- @return TSNode?, vim.treesitter.Query?
local function get_node_at_pos(bufnr, row, col, ctx, pred)
  ctx = ctx or get_hl_ctx(bufnr, row, col)

  for _, t in ipairs(ctx) do
    local root, query = t[1], t[2]
    for capture, node in query:iter_captures(root, bufnr, row, row + 1) do
      if vim.treesitter.is_in_node_range(node, row, col) then
        local c = query.captures[capture] -- name of the capture in the query
        if c and pred(c) then
          return node, query
        end
      end
    end
  end
end

--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @param ctx? [TSNode, vim.treesitter.Query][]
--- @return TSNode?, vim.treesitter.Query?
local function get_pairnode_at_pos(bufnr, row, col, ctx)
  return get_node_at_pos(bufnr, row, col, ctx, function(c)
    if c:match('^keyword%.?') or c:match('^punctuation%.bracket%.?') then
      return true
    end
  end)
end

local M = {}

--- @param node TSNode
--- @param hl_group string
local function highlight_node(node, hl_group)
  local srow, scol, erow, ecol = node:range(false)
  api.nvim_buf_set_extmark(0, ns, srow, scol, {
    end_row = erow,
    end_col = ecol,
    hl_group = hl_group
  })
end

function M.match()
  api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local crow, ccol = cursor[1] - 1, cursor[2]

  local w1node, query = get_pairnode_at_pos(bufnr, crow, ccol)
  if not w1node then
    return
  end

  local container_node = w1node:parent()

  while container_node do
    local w1srow, w1scol, w1erow, w1ecol = w1node:range(false)
    local srow, scol, erow, ecol = container_node:range(false)

    --- @type integer?, integer?
    local prow, pcol
    if w1srow == srow and w1scol == scol then
      prow, pcol = erow, ecol - 1
    elseif w1erow == erow and w1ecol == ecol then
      prow, pcol = srow, scol
    else
      return
    end

    -- Refine the context to just `container_node`
    local ctx = { { container_node, query } }
    local w2node = get_pairnode_at_pos(bufnr, prow, pcol, ctx)

    if not w2node or w1node == w2node then
      -- Nothing else to do
      return
    end

    highlight_node(w2node, 'MatchParen')
    container_node = container_node:parent()
  end
end

return M
