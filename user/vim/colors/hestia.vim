" hestia.vim — hestia's editor colorscheme: the `wildcharm` scheme (Maxim Kim,
" vim/colorschemes) with hestia's deviations layered on top: the hestia ground
" #1a1a1a in place of wildcharm's pure #000000 (the bg-lift, promoted 2026-07,
" palette 0.5.0 — it was near-black #0a0a0a before), and primary text lifted to
" roles.text #e0e0e0 (wildcharm's #d0d0d0; matches kitty/waybar/vifm).
" wildcharm's syntax palette and accent (#d7005f / ANSI color01) are kept
" as-is. Add future hestia tweaks as `hi` overrides after the runtime load.
"
" A thin wrapper, not a fork: it loads whichever `wildcharm` is first on the
" runtimepath (the `vim/colorschemes` plugin, else the built-in $VIMRUNTIME copy)
" so it auto-tracks upstream, then restates only our changes. Shared by Vim and
" Neovim (nvim sources ~/.vimrc and has ~/.vim on its runtimepath).

runtime colors/wildcharm.vim
let g:colors_name = 'hestia'

if &background ==# 'dark'
  " hestia ground + text; most groups use guibg=NONE and inherit Normal, so
  " this carries the whole UI. cterm values are the 256-colour fallback (234 =
  " #1c1c1c, 254 = #e4e4e4 — nearest steps; truecolor terminals are exact,
  " see the termguicolors block in .vimrc).
  hi Normal      guifg=#e0e0e0 guibg=#1a1a1a ctermfg=254 ctermbg=234
  hi TabLineFill guibg=#1a1a1a ctermbg=234
endif
