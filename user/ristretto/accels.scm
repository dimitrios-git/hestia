; hestia ristretto accelerators (GtkAccelMap dump, loaded at startup) — vim
; navigation to match imv: h = previous image, l = next image. GtkAccelMap
; carries ONE accelerator per action, so these REPLACE the stock space /
; BackSpace (j/k can't also be bound — no second nav action to hang them on).
; Deployed by COPY (templated_configs), not symlinked: ristretto re-saves this
; file on exit (gtk_accel_map_save), which would clobber a symlink.
(gtk_accel_path "<Actions>/RsttoWindow/back" "h")
(gtk_accel_path "<Actions>/RsttoWindow/forward" "l")
