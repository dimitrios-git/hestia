-- Tree-sitter setup (Neovim only) — required by ~/.vimrc's `lua require('trees')`.
-- Parsers are compiled on first install, so a C compiler (gcc/clang) must be
-- present. render-markdown.nvim relies on the markdown / markdown_inline parsers.
-- NOTE: requires the `master` branch of nvim-treesitter (pinned in .vimrc).
-- The newer `main` branch removed the nvim-treesitter.configs module used here.
local ok, configs = pcall(require, 'nvim-treesitter.configs')
if not ok then
  vim.notify(
    "nvim-treesitter.configs not found — run :PlugUpdate nvim-treesitter (needs the 'master' branch)",
    vim.log.levels.WARN
  )
  return
end

configs.setup({
  ensure_installed = {
    'markdown', 'markdown_inline', 'lua', 'vim', 'vimdoc',
    'bash', 'json', 'yaml', 'html', 'css',
    'javascript', 'typescript', 'tsx', 'python',
  },
  auto_install = false,
  highlight = { enable = true },
})
