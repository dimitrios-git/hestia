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
set laststatus=2             " always show the statusline (white-on-violet accent
                            " bar); default 1 only shows it with 2+ windows, so a
                            " lone buffer had no status bar until NERDTree opened

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

" Colour NERDTree icons per file extension (VSCode-like). Loads BEFORE
" vim-devicons (which must be last) and decorates the glyphs it injects; its
" default per-extension palette is on, folders get hestia violet via the
" s:HestiaNerdTreeIcons override below, and unknown extensions fall back to the
" neutral grey there. Needs :PlugInstall + a vim restart to take effect.
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" Filetype/folder glyphs (Nerd Font) for NERDTree, CtrlP, etc. MUST be the LAST
" plugin loaded — it patches the others at load time, so anything it decorates
" has to already be registered.
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
" Theme variant (M7): the bootstrap symlinks ~/.vim/hestia-background.vim to
" user/vim/hestia-background-{dark,light}.vim per `theme_variant`; fall back
" to dark when the link is absent (bare checkout / pre-bootstrap).
if filereadable(expand('~/.vim/hestia-background.vim'))
  source ~/.vim/hestia-background.vim
else
  set background=dark
endif
colo hestia   " hestia's own self-contained scheme (user/vim/colors/hestia.vim)

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

" Colour NERDTree's vim-devicons icons: folders hestia accent VIOLET (#7c3aed);
" other icons are coloured per file extension by vim-nerdtree-syntax-highlight
" (VSCode-like) when it's installed, and fall back to a neutral grey otherwise —
" icon only, the name keeps its normal colour. devicons injects the glyph into
" NERDTree's [...] flag region, so ALL icons inherit `NERDTreeFlags` (which links
" to `Number` → a red — the stray red shade on file icons). Recolour that to grey
" for the default (unknown extensions), then a syntax match over the folder glyph
" overrides folders to accent violet; it wins because containedin=ALL nests it
" inside the flag region. The extension-coloured glyphs are the plugin's own
" groups, so they sit on top of the grey default. The folder match is built from
" devicons' own folder-symbol variables (no hardcoded codepoint), so it tracks
" whatever glyph the plugin uses across versions. cterm cells are exact
" (247=#9e9e9e, 99≈#7c3aed), so the colours hold with or without 'termguicolors'.
" (NERDTree colours via highlight groups, not LS_COLORS/dircolors.)
function! s:HestiaNerdTreeIcons() abort
  " neutral icon grey per variant: dark extended.ui_grey, light roles.dim
  if &background ==# 'light'
    highlight NERDTreeFlags guifg=#626262 ctermfg=241
  else
    highlight NERDTreeFlags guifg=#9e9e9e ctermfg=247
  endif
  let l:syms = get(g:, 'WebDevIconsUnicodeDecorateFolderNodesDefaultSymbol', '')
        \   . get(g:, 'DevIconsDefaultFolderOpenSymbol', '')
  if empty(l:syms) | return | endif
  execute 'syntax match hestiaDevIconFolder /[' . l:syms . ']/ containedin=ALL'
  highlight hestiaDevIconFolder guifg=#7c3aed ctermfg=99
endfunction
augroup HestiaNerdTreeFolderIcon
  autocmd!
  autocmd FileType nerdtree call s:HestiaNerdTreeIcons()
augroup END

" Per-extension NERDTree icon colours drawn from the hestia SYNTAX palette, so
" the file tree coheres with the code highlighting (chose to hestia-fy vim's file
" colours rather than chase VS Code's icon theme — VS Code file icons come from a
" separate icon-theme extension). Set per theme_variant — the syntax hues differ
" dark/light (Memphis, palette 0.10.0). vim-nerdtree-syntax-highlight takes bare
" RRGGBB; extensions not listed keep the plugin's own colour, unknown ones fall to
" the neutral grey (s:HestiaNerdTreeIcons), folders stay violet. Extend freely.
if &background ==# 'light'
  let s:ndc = {'grn':'247534','crl':'cc1800','mag':'c60777','pur':'733af4','tel':'08717a','blu':'1c65bd','ylw':'855f12'}
else
  let s:ndc = {'grn':'32a148','crl':'ff4f38','mag':'f840ac','pur':'9e77f7','tel':'0cb2c0','blu':'4a8fe4','ylw':'e0a020'}
endif
let g:NERDTreeExtensionHighlightColor = {
      \ 'py': s:ndc.ylw, 'pyi': s:ndc.ylw,
      \ 'c': s:ndc.blu, 'h': s:ndc.blu, 'cpp': s:ndc.blu, 'cc': s:ndc.blu, 'hpp': s:ndc.blu,
      \ 'ts': s:ndc.blu, 'tsx': s:ndc.blu, 'jsx': s:ndc.blu, 'lua': s:ndc.blu,
      \ 'js': s:ndc.ylw, 'mjs': s:ndc.ylw, 'cjs': s:ndc.ylw, 'json': s:ndc.ylw,
      \ 'css': s:ndc.tel, 'scss': s:ndc.tel, 'sass': s:ndc.tel, 'go': s:ndc.tel, 'sql': s:ndc.tel,
      \ 'html': s:ndc.crl, 'htm': s:ndc.crl, 'java': s:ndc.crl, 'rs': s:ndc.crl,
      \ 'sh': s:ndc.grn, 'bash': s:ndc.grn, 'zsh': s:ndc.grn, 'vim': s:ndc.grn,
      \ 'md': s:ndc.pur, 'markdown': s:ndc.pur,
      \ 'yaml': s:ndc.mag, 'yml': s:ndc.mag, 'toml': s:ndc.mag,
      \ }

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
    -- Theme headings to the hestia accent violet (#7c3aed); the heading wash
    -- follows the variant (dark extended.heading_bg, light its counterpart)
    local heading_bg = vim.o.background == 'light' and '#e9ddff' or '#150a24'
    for i = 1, 6 do
      vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i, { fg = '#7c3aed', bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i .. 'Bg', { bg = heading_bg })
    end
  end
EOF
endif
