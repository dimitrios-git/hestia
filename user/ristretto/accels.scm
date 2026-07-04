; hestia ristretto accelerators (GtkAccelMap, loaded at startup over the
; built-in defaults — settings.c adds its table first, then loads this file,
; so these entries win). vim navigation to match imv: h = previous image,
; l = next image. The nav accels live on ristretto's own <Window>/ paths
; (NOT the <Actions>/RsttoWindow/ action accels — those carry space/BackSpace
; and are untouched), so h/l REPLACE Page_Up/Page_Down only; space and
; BackSpace still advance. Bonus stock vim-isms already built in: q quits,
; f/F fullscreen. Deployed by COPY (templated_configs): settings.c can
; re-save this file on finalize, which would clobber a symlink.
(gtk_accel_path "<Window>/previous-image" "h")
(gtk_accel_path "<Window>/next-image" "l")
