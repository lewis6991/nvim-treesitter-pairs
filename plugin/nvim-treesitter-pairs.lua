if vim.g.loaded_matchparen == 1 then
  pcall(vim.api.nvim_clear_autocmds, { group = 'matchparen' })
end

vim.g.loaded_matchparen = 1

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
  group = vim.api.nvim_create_augroup('nvim-treesitter-pairs', {}),
  callback = function()
    require('nvim-treesitter-pairs').match()
  end
})
