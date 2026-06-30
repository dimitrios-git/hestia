" ~/.vimrc

" --- Basic Settings ---
set nocompatible
filetype plugin indent on
syntax on

" --- UI Settings ---
set number
set relativenumber
set nowrap
set scrolloff=10
set colorcolumn=80,120,160
set textwidth=160
set showcmd
set showmode
set showmatch
set cursorline

" --- Indentation and Tabs ---
set shiftwidth=2
set tabstop=2
set expandtab

" --- Search Settings ---
set ignorecase
set smartcase                " Override ignorecase if uppercase in search
set incsearch
set hlsearch

" --- System Integration ---
set clipboard=unnamedplus
set wildmenu
set wildmode=list:longest    " Complete longest common string, list options
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

" --- Performance ---
set history=1000
set updatetime=300           " Faster update time (good for CoC)
set signcolumn=yes
set nobackup nowritebackup

" --- Plugin Manager ---
" Install plug.vim if missing:
"   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
"        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
call plug#begin('~/.vim/plugged')

" Historic Vim themes
Plug 'vim/colorschemes'

" Code completion
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" JavaScript / TypeScript / Web
Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'
Plug 'styled-components/vim-styled-components'
Plug 'jparise/vim-graphql'
Plug 'yuezk/vim-js'
Plug 'HerringtonDarkholme/yats.vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'prisma/vim-prisma'
Plug 'github/copilot.vim' " requires Vim version 9.0.0185

" Snippets
Plug 'dsznajder/vscode-es7-javascript-react-snippets', { 'do': 'yarn install --frozen-lockfile && yarn compile' }

" Productivity
Plug 'tpope/vim-commentary'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'tpope/vim-fugitive'
Plug 'inkarkat/vim-SyntaxRange'

" Markdown
if !has('nvim')
  Plug 'preservim/vim-markdown', { 'for': 'markdown' }
endif

if has('nvim')
  Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && npm install' }
  " Live in-buffer rendering (Neovim only — needs treesitter/Lua, absent in plain Vim)
  Plug 'MeanderingProgrammer/render-markdown.nvim'
endif

Plug 'plasticboy/vim-markdown'
Plug 'dhruvasagar/vim-table-mode'
Plug 'godlygeek/tabular'
Plug 'tyru/open-browser.vim'
" Pin master: the new default 'main' branch dropped the nvim-treesitter.configs API
Plug 'nvim-treesitter/nvim-treesitter', {'branch': 'master', 'do': ':TSUpdate'}

" File explorer
Plug 'preservim/nerdtree'

call plug#end()

" --- Theme ---
set background=dark
colo hestia   " wildcharm + hestia's near-black bg (user/vim/colors/hestia.vim)

" --- CoC.nvim Configuration ---
" Use Tab for completion and navigation
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent><expr> <CR> pumvisible() ? "\<C-y>" : "\<CR>"

" Trigger completion manually
inoremap <silent><expr> <C-Space> coc#refresh()

" Navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gy <Plug>(coc-type-definition)

" Diagnostics navigation
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Actions
nmap <leader>rn <Plug>(coc-rename)
nmap <leader>f <Plug>(coc-format-selected)
vmap <leader>f <Plug>(coc-format-selected)
nmap <leader>a <Plug>(coc-codeaction-selected)
vmap <leader>a <Plug>(coc-codeaction-selected)
nmap <leader>qf <Plug>(coc-fix-current)

" Show documentation
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

" Highlight references on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

" Commands
command! -nargs=0 Format :call CocActionAsync('format')
command! -nargs=0 OR :call CocActionAsync('runCommand', 'editor.action.organizeImport')

let g:coc_global_extensions = [
  \ 'coc-sh', 'coc-json', 'coc-tsserver', 'coc-html', 'coc-css', 'coc-emmet',
  \ 'coc-lists', 'coc-pairs', 'coc-yaml', 'coc-python', 'coc-eslint',
  \ 'coc-prettier', 'coc-snippets', 'coc-highlight', 'coc-xml', 'coc-yank',
  \ 'coc-git', '@yaegassy/coc-tailwindcss3'
\ ]

" --- CtrlP Configuration ---
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_custom_ignore = {
  \ 'dir': '\v[\/]\.(git|hg|svn)$',
  \ 'file': '\v\.(exe|so|dll)$',
  \ }
" Use git ls-files when inside git repo
let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -co --exclude-standard']

" --- Markdown Configuration ---
" Avoid double Markdown highlighting
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal = 0
let g:vim_markdown_conceal_code_blocks = 0

" Preview: render the current file in glow as a full-screen pager in the SAME
" terminal (like vifm), suspending Vim until you quit glow with `q`. glow gets
" a real TTY so it picks up the themed style from ~/.config/glow/glow.yml.
" Works in both Vim and Neovim, unlike the in-buffer renderer below.
" -w "$(tput cols)" wraps at the actual terminal width: glow's built-in default
" caps word-wrap at 80 cols regardless of terminal size, which on a wide window
" adds spurious mid-paragraph breaks. Match the viewport instead.
function! GlowPreview() abort
  execute '!glow -w "$(tput cols)" -p ' . shellescape(expand('%:p'))
endfunction
command! Glow call GlowPreview()
autocmd FileType markdown nnoremap <buffer> <silent> <leader>md :call GlowPreview()<CR>

" --- Tree-sitter Configuration ---
if has('nvim')
  lua require('trees')
endif

" --- render-markdown.nvim (Neovim only: live in-buffer rendering) ---
if has('nvim')
lua << EOF
  local ok, rm = pcall(require, 'render-markdown')
  if ok then
    rm.setup({
      heading = { sign = false },
      code = { sign = false, width = 'block' },
    })
    -- Theme headings to the wildcharm accent red (#d7005f)
    for i = 1, 6 do
      vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i, { fg = '#d7005f', bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i .. 'Bg', { bg = '#1a0a12' })
    end
  end
EOF
endif
