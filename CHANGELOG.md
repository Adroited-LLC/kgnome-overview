# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- A single Meta press opened the app grid instead of the window picker.
  Plasma 6 sends Meta alone to plasmashell's "Activate Application
  Launcher" (kglobalaccel), which the Show Apps button answers with the app
  grid; the kwinrc `[ModifierOnlyShortcuts]` entry written by 0.1.0 is not
  read by KWin 6. `make-default` now binds `Meta` to `Cycle GNOME Overview`
  and keeps `Alt+F1` on the launcher; restore/uninstall undo it. Run
  `scripts/make-default.sh meta` once after updating.
- Overview triggers arriving within 150 ms of each other (one key press
  reaching the effect twice) count once; triggers are logged to the journal.

## [0.1.0] - 2026-10-18

First public release.

### Overview (KWin effect "GNOME-style Overview")
- GNOME 50 overview layout: search entry, workspace thumbnails, window
  picker with peeking side workspaces, paged app grid, dash, one animated
  state value (hidden / window picker / app grid).
- Search across apps (GNOME ranking) and KRunner results, with GNOME's
  keyboard navigation.
- App grid with drag-and-drop reordering, folders (create, rename, dissolve),
  pinning to the dash and launching on a chosen workspace; saved layout.
- Dash sharing favourites two-way with Kickoff (KActivities).
- GNOME dynamic workspaces, drag windows/apps onto or between workspaces,
  close a desktop from its thumbnail.
- Triggers: `Meta+O`, `Meta+Shift+O`, top-left hot corner, 4-finger swipes;
  Meta on its own cycles window picker → app grid → closed
  (`MetaCycle=toggle` for GNOME's behaviour).
- Settings dialog: icon size/scale, grid columns/rows, hot corner, gesture
  fingers, blur, dynamic workspaces, Meta key behaviour and more.

### Show Apps plasmoid (`org.kgnome.overview.showapps`)
- Panel button opening the app grid or window picker, `Alt+F1`, and an
  "Overview Settings…" entry.

### System Menu plasmoid (`org.kgnome.systemsheet`)
- GNOME 50 Quick Settings sheet for the panel, desktop or system tray:
  screenshot, settings, lock, inline power menu (Suspend, Restart, Power
  Off, Log Out, Switch User), battery percentage on laptops.
- Volume slider with output device menu, microphone slider while recording,
  brightness sliders (backlight and DDC/CI).
- Quick toggles: Wired, Wi-Fi (network list, inline password), VPN,
  Bluetooth (paired devices), Power Mode, Night Light, Dark Style, Do Not
  Disturb, keyboard backlight, Airplane Mode; missing hardware is hidden.
- GNOME or Plasma accent, GNOME dark/light or Plasma-theme style, square or
  GNOME-rounded sheet.

### Installation
- `install.sh`: user-local build and install, dependency check with
  per-distribution hints, opt-in `--make-default` (Meta key, hot corner,
  `Meta+W`, gestures, panel launcher) with backups;
  `scripts/restore-defaults.sh` and `uninstall.sh` to undo.

[0.1.0]: https://github.com/Adroited-LLC/kgnome-overview/releases/tag/v0.1.0
