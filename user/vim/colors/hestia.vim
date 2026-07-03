" hestia.vim — hestia's editor colorscheme: the `wildcharm` scheme (Maxim Kim,
" vim/colorschemes) with hestia's deviations layered on top, per &background
" (upstream wildcharm branches on it natively, so both variants come designed):
"   dark  — the hestia ground #1a1a1a in place of wildcharm's pure #000000
"           (the bg-lift, promoted 2026-07, palette 0.5.0) and primary text
"           lifted to roles.text #e0e0e0 (matches kitty/waybar/vifm).
"   light — the light desktop ground #f5f5f5 in place of upstream's pure
"           #ffffff (the mirror of the dark softening, palette 0.6.0 / M7)
"           and text #1a1a1a (light roles.text).
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
else
  " light desktop ground + text (M7). cterm fallback: 255 = #eeeeee,
  " 234 = #1c1c1c — nearest steps; truecolor terminals are exact.
  hi Normal      guifg=#1a1a1a guibg=#f5f5f5 ctermfg=234 ctermbg=255
  hi TabLineFill guibg=#f5f5f5 ctermbg=255
endif
