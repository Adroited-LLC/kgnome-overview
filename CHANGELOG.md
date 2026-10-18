# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `BackgroundTint` setting ("Background tint" in the settings dialog,
  0-100 %, default 30): strength of the dark overlay over the blurred
  wallpaper; only used with `BlurBackground`.
- Unpinning an app in the dash also removes it from the panel task
  manager's pinned launchers (live, through plasmashell's `evaluateScript`;
  `UnpinFromTaskManager`, default on). Pinning only adds to the favourites.
- Like GNOME, a dragged window (or app icon) shrinks as it approaches the
  workspace thumbnails or the app grid's workspace strip, down to about its
  size in a thumbnail, and grows back when moved away or dropped.
- `dev/sheet-anim.sh`: frame-by-frame check of the System Menu animations.

### Changed
- The trailing empty desktop thumbnail no longer shows a "+" badge (like
  GNOME); dropping on it still puts the window/app on a new desktop.
- The dash keeps using KDE's Favorites, shared with Kickoff/Kicker (pin,
  unpin and reorder show there live); the short-lived separate dash list
  (`FavoriteApps`/`FavoritesSeeded`, never released) was dropped. Leftover
  `FavoritesSeeded` keys are ignored.
- Lighter overview background over the blur (tint 30 % instead of 88 %),
  and `Esc` in the app grid closes the overview directly instead of going
  back to the window picker (differs from GNOME). PR #1 by @HUSTLRX.

### Fixed
- System Menu: expanding and collapsing an inline menu (Wi-Fi, Bluetooth,
  Power Mode, Wired, VPN, Power Off, Sound Output) glitched the area below
  the sliders: while a toggle menu closed, its card jumped to the first
  toggle row and squashed it, and the menus' gaps appeared/disappeared in one
  step. All inline menus now share one eased expand/collapse (Expander).
- The app menu's Pin to Dash, Unpin, New Window and Quit did nothing (grid,
  folders and dash): the menu closed before the action ran and the action
  then used an empty app id (Pin/Unpin could add a bogus
  `applications:.desktop` favourite). Empty ids are now ignored.
- App search results have the app menu too (right-click), so they can be
  pinned.
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
