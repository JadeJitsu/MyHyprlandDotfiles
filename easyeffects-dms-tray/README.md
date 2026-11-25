# EasyEffects ↔ DMS tray-icon fix (and friends)

Why this directory exists: under DMS, EasyEffects' tray icon rendered as a
generic white box because **DMS's SNI renderer cannot resolve theme-name
IconNames** (see main README, systray section). This folder holds the fix
artifacts, kept separately from the dotfiles because they are *build inputs*
for the native EasyEffects tree at `~/Projects/easyeffects-src`.

## Contents

| File | Purpose |
|---|---|
| `patches/dms-tray-icon-pixmap.patch` | **The systray fix.** TrayIcon.qml loads `file:///usr/local/share/icons/hicolor/scalable/apps/<name>.png` instead of the theme name, so Qt exports a real `IconPixmap` that DMS can render. (Bare absolute paths and qrc guesses both exported *empty* pixmaps; only the explicit `file://` URL works.) |
| `patches/remove-maxoverlayheight-null-footer.patch` | Upstream commit 350384f8aef2 (released v8.3.3): removes the `maxOverlayHeight` binding that dereferences a null footer — the crash that keeps us off the distro package. |
| `patches/disable-echo-canceller.patch` | Copied from Debian's packaging: strips the `webrtc-audio-processing-2` dependency, which Debian/TUXEDO does not package (only v1). Trade-off: no echo-canceller effect, same as the distro package. |
| `tray-icons/render.py` | Renders the two symbolic SVGs to 48×48 white-on-transparent PNGs using PyGObject + Rsvg (`get_pixbuf().scale_simple`). **Do not use ImageMagick** — it mangles these symbolic SVGs (opaque white box by default; fully transparent with `-background none`). Needs `python3-gi` + `gir1.2-rsvg-2.0`. |
| `tray-icons/*.png` | The rendered icons, installed to `/usr/local/share/icons/hicolor/scalable/apps/` by `update.sh`. |

## How it's applied

`~/Projects/easyeffects-src/update.sh` applies all three patches
conditionally (grep-gated, so re-running on a tag that already contains a fix
is safe), builds v8.3.2 with CMake/Ninja, stages via `DESTDIR`, copies the
PNGs in, and installs to `/usr/local` (shadowing `/usr/bin/easyeffects`).
Exact installed-file manifest: `~/Projects/easyeffects-src/installed-files.txt`.

## When this becomes obsolete

- DMS gains proper theme-name icon resolution → drop the tray patch.
- TUXEDO/Debian ships EasyEffects ≥ 8.3.3 *and* webrtc-audio-processing-2 →
  remove the `/usr/local` build (manifest rollback) and use the distro package.

All files here are AI-generated (Claude Code, 2026-11-25) — review before
reuse elsewhere.
