// hestia — Thunderbird theming prefs (symlinked into each profile by the
// dotfiles role; user.js is re-applied at every startup, pinning these).
//
// Load the profile's chrome/userChrome.css + userContent.css (the GENERATED
// hestia accent overrides — see themes/wildcharm/render.py):
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Make Gecko read the CSS AccentColor system colour from the GTK3 theme
// (hestia's #d7005f) instead of libadwaita's palette + the GNOME accent-color
// enum (default blue, ignores the GTK theme) — covers scrollbars/selection in
// content that the stylesheets don't reach:
user_pref("widget.gtk.libadwaita-colors.enabled", false);
