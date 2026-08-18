-- hestia video-rig nvim init (light) — NOT anyone's personal nvim config:
-- no plugins, no personal keymaps. Staged as $HOME/.config/nvim/init.lua
-- for hestia-video recordings (docs/video-capture-design.md) so a clip's
-- editor behaviour is identical no matter which real user renders it.
-- `colorscheme hestia` resolves via $HOME/.config/nvim/colors/hestia.vim
-- — hestia-video copies that file in fresh from the repo each run, not a
-- symlink to anyone's personal ~/.config/nvim.
vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.laststatus = 2
vim.o.background = "light"
vim.cmd("colorscheme hestia")

-- No filetype INDENT (see vimrc-dark's comment — the same accumulating-
-- indent conflict applies here): filetype plugin, deliberately not
-- filetype plugin indent.
vim.cmd("filetype plugin on")
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.expandtab = true
vim.o.autoindent = false  -- Neovim, UNLIKE Vim, defaults this ON

-- Two rounds of the SAME accumulating-indent bug, confirmed live
-- (2026-08-18) — a scaffolded body kept coming out at 8 then 12 spaces
-- instead of a flat 4:
-- round 1: Neovim's 'autoindent' default (fixed above) — not enough on
--   its own, this round wasn't the whole story.
-- round 2: Neovim's BUNDLED ftplugin/c.vim sets 'cindent' unconditionally
--   as part of `filetype plugin on` — NOT gated behind the separate
--   `filetype ... indent on` layer the way Vim's own indent/c.vim is, so
--   the same "skip filetype indent" fix that worked for the Vim rig does
--   NOT carry over here. `cindent`/`smartindent` get set reactively when
--   the ftplugin loads (on the FileType event), which runs BEFORE this
--   autocmd fires if registered first — so this has to re-assert `false`
--   INSIDE the FileType callback, not just once at startup, to actually
--   win.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.bo.autoindent = false
    vim.bo.cindent = false
    vim.bo.smartindent = false
  end,
})

-- Core Neovim treesitter (vim.treesitter.start — built into Neovim
-- itself, NOT the community nvim-treesitter PLUGIN, which this minimal
-- rig deliberately doesn't install) classifies tokens closer to how the
-- site's own Shiki-highlighted code blocks do than legacy regex :syntax
-- — the whole reason this rig exists (docs/video-capture-design.md §14).
-- Needs only a compiled parser (parser/<lang>.so) on the runtimepath;
-- Neovim ships the highlight queries for common languages (e.g. C)
-- built in, no extra query files needed. hestia-video stages any
-- compiled parsers it finds from the invoking user's own nvim-treesitter
-- install — this repo doesn't vendor the compiled binaries. Falls back
-- to legacy :syntax (still hestia-themed, just coarser token boundaries)
-- if no parser is available for a buffer's filetype — never a hard
-- failure, never an error visible on screen.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    local ok = pcall(vim.treesitter.start)
    if not ok then
      vim.cmd("syntax enable")
    end
  end,
})

-- Minimal auto-pairs, hand-rolled rather than installing a plugin (owner,
-- 2026-08-19: their real personal profile uses coc.nvim's coc-pairs, but
-- coc.nvim is a full LSP/completion framework — Node.js-backed, manages
-- a dozen extensions — far too heavy to pull into a rig that's
-- deliberately plugin-free). This replicates just the BEHAVIOUR: typing
-- an opener inserts its closer immediately with the cursor between them
-- (matches how a real auto-pair-equipped editor behaves, which is also
-- what a scene's own typed text already assumes — every existing scene
-- types BOTH characters of a pair explicitly); typing the closer when
-- it's already the very next character moves over it instead of
-- inserting a second one, so existing scenes need no rewriting.
-- Deliberately NOT "smart" — no backspace-deletes-empty-pair-together
-- behaviour — BackSpace always removes exactly one character, which
-- comment: 's exact-count cleanup (see emit_comment_line, hestia-video)
-- depends on.
--
-- /* */ comments are NOT handled here, and deliberately so: `a / *ptr`
-- (division then a pointer dereference) also contains the sequence "/",
-- "*" — a naive auto-pair rule on that trigger risks inserting a phantom
-- */ into real code that isn't a comment at all. hestia-video's own
-- comment: action handles /* */ immediate-closing itself instead (see
-- emit_comment_line), where the tool KNOWS it's typing a comment rather
-- than guessing from two characters in a stream.
local OPEN_CLOSE = { ["("] = ")", ["["] = "]", ["{"] = "}" }
for open, close in pairs(OPEN_CLOSE) do
  vim.keymap.set("i", open, open .. close .. "<Left>", { noremap = true, silent = true })
  vim.keymap.set("i", close, function()
    local col = vim.fn.col(".")
    local line = vim.fn.getline(".")
    if line:sub(col, col) == close then
      return "<Right>"
    end
    return close
  end, { noremap = true, expr = true, replace_keycodes = true })
end
for _, q in ipairs({ '"', "'" }) do
  vim.keymap.set("i", q, function()
    local col = vim.fn.col(".")
    local line = vim.fn.getline(".")
    if line:sub(col, col) == q then
      return "<Right>"
    end
    return q .. q .. "<Left>"
  end, { noremap = true, expr = true, replace_keycodes = true })
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("redraw")
    print("")
  end,
})
