# yaru_icons role

Installs the prebuilt **Yaru-hestia** icon theme (Debian-red `#ce0056` accent) into
`~/.local/share/icons` — a sha256-verified **download + extract**, no root and no
build toolchain on the target (same pull pattern as `localbin`/`fonts`). Opt-in:
`enable_yaru_icons` (default off). The active theme is `Yaru-hestia`, selected via
`gtk-icon-theme-name` in both `user/gtk/*/settings.ini` and a guarded sway `gsettings`
exec.

## Why a prebuilt artifact (not build-on-deploy)

Yaru ships its accented folder icons as **rasterised PNGs**, so a custom accent must be
**rendered** from source — which needs `meson`/`ninja`/`sassc`/**inkscape**+`xvfb`. Doing
that on every machine is heavy and fragile, and unlike the rest of the repo's pull-pinned
pattern. So the **`claude` agent builds the theme once on demand** and publishes it as a
hestia GitHub **release asset**; this role just pulls it.

## The deliverable

- **Release:** `yaru-hestia-v1` (tag) on `dimitrios-git/hestia`, asset
  `Yaru-hestia-icons.tar.gz` (~27 MB).
- **Contents:** `Yaru/` (base, inherited) + `Yaru-hestia/` (accent overlay;
  `Inherits=Yaru,hicolor`). Self-contained — no apt `yaru-theme-icon` needed.
- Pinned in `defaults/main.yml` (`yaru_icons_release` + `yaru_icons_sha256`).

## Rebuild / maintenance recipe (claude, on a Yaru version bump)

The build host needs the toolchain once (system-wide; `claude` can then build in its home):

```sh
sudo apt install libgtk-3-dev meson ninja-build sassc inkscape optipng xvfb dbus-x11 libgtk-3-bin
```

Then, as `claude`:

```sh
ver=26.10.1                                   # pin to the desired Yaru tag
curl -fsSL -o yaru.tar.gz https://github.com/ubuntu/yaru/archive/refs/tags/$ver.tar.gz
tar xf yaru.tar.gz && cd yaru-$ver

# 1) Add a `hestia` accent flavour. The icon accent is #c60039 (NOT #ce0056): Yaru
#    paints the folder front through a ~15% white overlay that lightens it, so a flat
#    #ce0056 renders pink (#d5266f). #c60039 pre-compensates so the rendered front lands
#    on true #ce0056 (≈ #ce2657 — R/B exact; green floors at ~38 from the overlay).
sed -i "s/^    } @else if \$accent_color == 'bark' {/    } @else if \$accent_color == 'hestia' {\n        \$color: #c60039;\n    } @else if \$accent_color == 'bark' {/" common/accent-colors.scss.in
sed -i "s/^        'bark',/        'hestia',\n        'bark',/" meson_options.txt

# 2) A very dark/saturated accent makes optimize-contrast() unable to self-contrast
#    accent-color-on-accent-color and HARD-ERROR. Make it best-effort instead (the
#    folders don't use that value):
perl -0pi -e 's/\@error "Cannot reach contrast target " \+ \$target \+ " for " \+\n            \$fg \+ " on " \+ \$bg;/\@return \$boundary-fg;/' common/sass-utils.scss

# 3) Two-pass build (meson asserts the flavour dir exists; first render creates it).
#    -Dgtk=true is mandatory (icon colouriser reuses the GTK accent CSS). Light only
#    (-Ddark=false): the dark variant lightens the accent to a pink, defeating the point.
meson setup build --prefix="$PWD/inst" -Dgtk=true -Dicons=true -Ddefault=true -Ddark=false \
  -Dgnome-shell=false -Dgtksourceview=false -Dmetacity=false -Dsounds=false -Dsessions=false \
  -Daccent-colors=hestia
ninja -j1 -C build render-icons-hestia      # -j1: parallel inkscape races on dbus activation
meson setup build --prefix="$PWD/inst" ... --reconfigure   # pass 2: dir now exists -> install-ready
ninja -C build install                       # -> inst/share/icons/{Yaru,Yaru-hestia}

# 4) Package + publish
tar czf Yaru-hestia-icons.tar.gz -C inst/share/icons Yaru Yaru-hestia
sha256sum Yaru-hestia-icons.tar.gz
gh release create yaru-hestia-v2 Yaru-hestia-icons.tar.gz --repo dimitrios-git/hestia --title ... --notes ...
```

Then bump `yaru_icons_release` + `yaru_icons_sha256` in `defaults/main.yml`.

**Verify the accent on-target** (the render can't be eyeballed headless): sample a folder
PNG — `python3 -c "from PIL import Image,…"` — the front should read `#ce2657`-ish.

## Gotchas (all learned the hard way)

- `ansible_env` is undefined here (`gather_facts: false`) — use `target_home`.
- The accent is `#c60039`, deliberately darker than `#ce0056` (overlay compensation).
- `render-icons` needs `-j1` or inkscape instances race on dbus and a few icons fail.
- Yaru's dark icon flavour lightens the folder accent — we ship the **light** `Yaru-hestia`
  and use it even on the dark desktop (folders are bg-independent; symbolics recolour via GTK).
