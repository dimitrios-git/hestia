" hestia.vim — hestia's editor colorscheme: the `wildcharm` scheme (Maxim Kim,
" vim/colorschemes) with hestia's deviations layered on top. Today that is just
" the signature near-black background (#0a0a0a) in place of wildcharm's pure
" #000000; wildcharm's syntax palette and accent (#d7005f / ANSI color01) are
" kept as-is. Add future hestia tweaks as `hi` overrides after the runtime load.
"
" A thin wrapper, not a fork: it loads whichever `wildcharm` is first on the
" runtimepath (the `vim/colorschemes` plugin, else the built-in $VIMRUNTIME copy)
" so it auto-tracks upstream, then restates only our changes. Shared by Vim and
" Neovim (nvim sources ~/.vimrc and has ~/.vim on its runtimepath).

runtime colors/wildcharm.vim
let g:colors_name = 'hestia'

if &background ==# 'dark'
  " hestia bg; most groups use guibg=NONE and inherit Normal, so this carries
  " the whole UI. The cterm value is the 256-colour fallback (only used on
  " non-truecolor terminals; kitty is truecolor and uses the gui value).
  " EXPERIMENT(bg-lift): trying roles.surface_alt #1a1a1a as the ground (roles.bg
  " is the near-black #0a0a0a), prompted by how the tci code blocks read. Revert
  " or promote to palette 0.3.0 — see PR / docs/theme-roadmap.md backlog.
  hi Normal      guibg=#1a1a1a ctermbg=234
  hi TabLineFill guibg=#1a1a1a ctermbg=234
endif
