" ~/.vimrc

" --- Basic Settings ---
set nocompatible
set encoding=UTF-8           " required by vim-devicons (Nerd Font filetype glyphs)
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

" Filetype/folder glyphs (Nerd Font) for NERDTree, CtrlP, etc. MUST be the LAST
" plugin loaded — it patches the others at load time, so anything it decorates
" has to already be registered. Monochrome by design; colour-by-filetype would
" be a separate companion plugin (vim-nerdtree-syntax-highlight).
Plug 'ryanoasis/vim-devicons'

call plug#end()

" --- Theme ---
" Truecolor: without this vim falls back to the cterm values (ground renders
" xterm 234 #1c1c1c instead of the exact #1a1a1a — one 256-step off, spotted
" against kitty in the bg-lift promotion). kitty advertises COLORTERM; the
" t_8f/t_8b terminfo overrides cover TERMs without built-in truecolor entries.
if has('termguicolors') && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
set background=dark
colo hestia   " wildcharm + the hestia ground/text (user/vim/colors/hestia.vim)

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

" --- Find / explore ---
" Live content grep across the project — fuzzy-search by what's *inside* files,
" the gap CtrlP (<C-p>, search by filename) doesn't cover. Uses coc-lists +
" ripgrep (both already present): \g opens an interactive grep, type to filter,
" <CR> jumps to the match.
nnoremap <silent> <leader>g :CocList grep<CR>
" NERDTree file sidebar — vifm is the primary navigator, so this is just the
" occasional in-vim tree; <C-n> toggles it (overrides the rarely-used default
" normal-mode <C-n> = cursor-down).
nnoremap <silent> <C-n> :NERDTreeToggle<CR>

" Colour NERDTree's vim-devicons icons to mirror the GTK file manager: folders
" hestia accent red (#d7005f), every other icon a neutral grey — icon only, the
" name keeps its normal colour. devicons injects the glyph into NERDTree's [...]
" flag region, so ALL icons inherit `NERDTreeFlags` (which links to `Number` →
" a wildcharm red — that's the stray red shade on file icons). Recolour that to
" grey for the default, then a syntax match over the folder glyph overrides
" folders back to accent red; it wins because containedin=ALL nests it inside
" the flag region. The folder match is built from devicons' own folder-symbol
" variables (no hardcoded codepoint), so it tracks whatever glyph the plugin
" uses across versions. cterm cells are exact (247=#9e9e9e, 161=#d7005f), so the
" colours hold with or without 'termguicolors'. (NERDTree colours via highlight
" groups, not LS_COLORS/dircolors — those don't apply here.)
function! s:HestiaNerdTreeIcons() abort
  highlight NERDTreeFlags guifg=#9e9e9e ctermfg=247
  let l:syms = get(g:, 'WebDevIconsUnicodeDecorateFolderNodesDefaultSymbol', '')
        \   . get(g:, 'DevIconsDefaultFolderOpenSymbol', '')
  if empty(l:syms) | return | endif
  execute 'syntax match hestiaDevIconFolder /[' . l:syms . ']/ containedin=ALL'
  highlight hestiaDevIconFolder guifg=#d7005f ctermfg=161
endfunction
augroup HestiaNerdTreeFolderIcon
  autocmd!
  autocmd FileType nerdtree call s:HestiaNerdTreeIcons()
augroup END

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
" -w wraps at the actual terminal width: glow's built-in default caps word-wrap
" at 80 cols regardless of terminal size, which on a wide window adds spurious
" mid-paragraph breaks. Match the viewport instead. The -2 is glamour's 2-col
" document left margin: a table is sized to the wrap width and then indented by
" it, so at exactly $(tput cols) the table's right border overruns by 2 and
" wraps — subtracting the margin keeps full-width tables flush to the edge.
function! GlowPreview() abort
  execute '!glow -w "$(($(tput cols) - 2))" -p ' . shellescape(expand('%:p'))
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
