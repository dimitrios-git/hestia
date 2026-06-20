" Neovim entry point — symlinked to ~/.config/nvim/init.vim.
"
" Reuse the shared Vim config instead of duplicating it: plug.vim lives in
" ~/.vim/autoload and plugins in ~/.vim/plugged. Prepending ~/.vim to
" runtimepath lets Neovim find both, then we source the same ~/.vimrc.
" Neovim-only plugins (render-markdown.nvim, markdown-preview.nvim) and the
" lua/trees.lua module are guarded behind has('nvim') in .vimrc and live under
" ~/.config/nvim (already on the default runtimepath).
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
