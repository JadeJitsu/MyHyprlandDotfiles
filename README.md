# MyHyprlandDotfiles — T14s-TuxOs desktop (Hyprland lua + DMS)

Restore source for **T14s-TuxOs** (ThinkPad T14s, user `jlagman`) running
**TUXEDO OS** (Debian-based) with **Hyprland (lua config)** inside the
**DMS (Dux Modular Shell)** session.

This tree **replaces the legacy conf-based layout** (UserConfigs/, animations/,
waybar/, rofi/) that lived in earlier commits — the last conf-era state is
preserved at commit `abb03e9` if you ever need it back.

> Parts of this tree were AI-generated (Claude Code, 2026-11-25) and are
> flagged as such below. Per SUSE IT policy they require human review before
> being treated as authoritative.

## Layout (repo path → live path)

| Repo path | Live path | What it is |
|---|---|---|
| `.config/hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Main Hyprland config (lua): keybinds, exec autostarts incl. all systray fixes |
| `.config/hypr/outputs-safe.lua` | same | Output/modeset safety module (blackscreen workaround) |
| `.config/hypr/dms/*.lua` | `~/.config/hypr/dms/` | Per-module overrides: colors, cursor, input, layout, outputs, windowrules |
| `.config/hypr/scripts/` | `~/.config/hypr/scripts/` | Helper scripts (+ `tests/` with fakebin shims) |
| `.config/dms/settings.json` | `~/.config/dms/settings.json` | DMS shell settings (incl. `batteryNotifyChargeLimit: false`) |
| `.config/dms/monitors.json` | same | Monitor configuration |
| `.config/dms/firefox.css` | same | DMS firefox theming |
| `.config/dms/plugin_settings.json`, `plugins.lock.json` | same | DMS plugin state; pins third-party plugins by repo+commit |
| `.config/dms/plugins/chargeLimitToggle/` | `~/.config/dms/plugins/chargeLimitToggle/` | Custom DMS plugin (battery charge-limit toggle widget) |
| `.config/dms/themes/` | `~/.config/dms/themes/` | 8 DMS themes (gruvboxMulti, kanagawaWl, …) |
| `.config/autostart/` | `~/.config/autostart/` | koofr + Nextcloud desktop entries (note: Hyprland does NOT run these — see systray section; kept for non-Hyprland sessions) |
| `.config/systemd/user/` | `~/.config/systemd/user/` | `dms.service` (+ `dms.service.d/hyprland-only.conf` drop-in), `hypr-log-saver.service` |
| `.config/qt6ct/` | `~/.config/qt6ct/` | Qt/KDE app theming so Qt apps match the DMS theme under Hyprland (custom palette via matugen + tuxedo-breeze-dark icons) |
| `.local/share/flatpak/overrides/` | `~/.local/share/flatpak/overrides/` | Flatpak session-bus policies — **Joplin's StatusNotifierWatcher talk-name is a required systray fix** |
| `easyeffects-dms-tray/` | (build inputs for `~/Projects/easyeffects-src`) | EasyEffects DMS tray-icon fix: patches, PNG renders, render script |
| `.zshrc` | `~/.zshrc` | Shell config |

## Restore procedure (reinstall / rebuild)

1. **Base system**: install TUXEDO OS, create user `jlagman`, pick the
   Hyprland session at SDDM login.
2. **Packages** (minimum the configs reference):
   ```
   sudo apt-get install hyprland hyprlock swww wl-clipboard ghostty \
     flatpak glab gh python3-gi librsvg2-bin cmake ninja-build git
   ```
   plus the Qt6 build deps needed by the EasyEffects native build (see
   `easyeffects-dms-tray/README.md`).
3. **DMS**: install DMS per its upstream instructions (lands in
   `~/.local/bin/dms`; note it auto-updates itself).
4. **Copy the tree back** (from a clone of this repo):
   ```
   rsync -a .config/ ~/.config/
   cp .zshrc ~/
   mkdir -p ~/.local/share/flatpak/overrides
   rsync -a .local/share/flatpak/overrides/ ~/.local/share/flatpak/overrides/
   ```
5. **Systemd user units**:
   ```
   systemctl --user daemon-reload
   systemctl --user enable dms.service hypr-log-saver.service
   ```
   (`dms.service` is `PartOf=graphical-session.target`, `Restart=on-failure`.)
6. **Third-party DMS plugin** (excluded from this repo on purpose — it is a
   git clone with its own `.git`): re-clone the pinned version from
   `plugins.lock.json`:
   ```
   git clone https://github.com/corcoran/dms-interval-command \
     ~/.config/dms/plugins/intervalCommand
   git -C ~/.config/dms/plugins/intervalCommand checkout \
     6d071ad7795a0fbf5304cc760ef98083780fd1f5
   ```
7. **EasyEffects**: native build required (distro 8.3.2 has a fatal QML bug) —
   follow `easyeffects-dms-tray/README.md`. The autostart line in
   `hyprland.lua` expects `/usr/local/bin/easyeffects`.
8. **Log out/in**, then re-establish accounts/auth (not restorable from files):
   `glab auth login`, `gh auth login`, Nextcloud account, Koofr app data
   (`~/.koofr-dist`), Signal (fresh instance + phone link), KWallet password
   (the old wallet was empty anyway).

### Not covered by this repo (redo elsewhere)

- `~/Projects/*` repos — each has its own GitLab home (itpe-fs / JadeJitsu):
  chief-of-staff, scripts (digest/coach/MCP servers), coach diary,
  claude-memory-mcp, qwen-reviewer-mcp, easyeffects-src, protonvpn-native, …
- `~/.config/opencode`, `~/.vibe`, `~/.claudia` (AI CLI setups)
- Ollama models (re-pull; remember the `-32k` derived models, see opencode notes)
- Browser profiles, TUXEDO Control Center (fresh install; EPP profiles are
  GUI-managed — tccd re-applies the active profile continuously)

## Systray icon fixes (all included in this tree)

Tray under Hyprland+DMS has four distinct root causes; every fix is in this
tree:

1. **Hyprland does not run `~/.config/autostart/*.desktop`.** Tray-only apps
   must be started from `hl.exec_cmd(...)` lines in `hyprland.lua`.
2. **Koofr startup race.** Go systray registers *once* and never retries; if
   storagegui starts before DMS's StatusNotifierWatcher exists, the icon is
   gone forever for that session. Fix (in `hyprland.lua`): wait-for-watcher
   loop (`busctl --user list | grep org.kde.StatusNotifierWatcher`, up to 60 s)
   before launching. Same guard is used for the EasyEffects autostart line.
3. **DMS cannot resolve theme-name IconNames at all.** Items that only provide
   an `IconName` like `com.github.wwmm.easyeffects-symbolic` render as a
   generic/white-box icon ("Unable to create pixmap for tray icon" in
   `journalctl --user -u dms.service`) even with the SVG + index.theme present
   in both `/usr/local/share/icons/hicolor` and `~/.local/share/icons/hicolor`
   (the DMS process also lacks `XDG_DATA_HOME`). Items providing `IconPixmap`
   or a file-path IconName render fine. Fix: the EasyEffects patch in
   `easyeffects-dms-tray/patches/dms-tray-icon-pixmap.patch` loads a
   pre-rendered PNG via explicit `file://` URL so Qt exports an IconPixmap.
4. **Flatpak sandbox blocks DBus.** Joplin needs
   `org.kde.StatusNotifierWatcher=talk` — stored in
   `.local/share/flatpak/overrides/net.cozic.joplin_desktop` (copy-back in
   step 4 restores it).

Also in `settings.json`: `batteryNotifyChargeLimit: false` (suppresses the
"charge limit reached" notification; limit itself stays at 80 %).

### Debug one-liners

```
# registered SNI items
busctl --user get-property org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
# what an item actually advertises (anonymous bus name :1.NNN from the above)
busctl --user get-property :1.NNN /StatusNotifierItem \
  org.kde.StatusNotifierItem IconName IconPixmap
# DMS renderer warnings, live
journalctl --user -u dms.service -f | grep -iE 'sni|pixmap'
```

### DMS quirks to remember

- Its watcher is **non-spec**: exposes `IsStatusNotifierHostRegistered` as a
  *property*, not the spec *method* (and `ProtocolVersion=0`). Spec-probing
  clients (libayatana) may fall back to XEmbed; direct
  `RegisterStatusNotifierItem` callers work fine.
- The DMS binary **auto-updates** (`~/.local/bin/dms`) — re-check tray
  behavior after updates.
- The DMS process environment lacks `XDG_DATA_HOME`.

## EasyEffects (native build)

See `easyeffects-dms-tray/README.md`. Short version: distro 8.3.2 crashes in
QML (null-footer binding); upstream fixed in v8.3.3 which hard-requires
`webrtc-audio-processing-2` (not packaged by Debian). So: native build of
v8.3.2 + 3 local patches (null-footer fix, echo-canceller disabled, DMS tray
icon) installed to `/usr/local`, managed by `~/Projects/easyeffects-src/update.sh`.

## Provenance / AI disclosure

- 2026-11-25 changes made with Claude Code (review before trusting):
  - `hyprland.lua`: koofr wait-for-watcher line, EasyEffects autostart line
  - `settings.json`: `batteryNotifyChargeLimit: false`
  - everything under `easyeffects-dms-tray/` (patches, `render.py`, PNGs)
  - this README
- Everything else is the live system state copied verbatim on 2026-11-25.
