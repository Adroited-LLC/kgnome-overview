# kgnome-overview

A GNOME Shell style overview for KDE Plasma 6 (KWin, Wayland): search entry at
the top, workspace thumbnails, a window picker, a paged app grid and a dash with
your favourites, all driven by one animated state value like GNOME's
`OverviewControls`.

It runs side by side with Plasma's own Overview effect. It does not touch
Meta+W, the Meta key on its own, or the top-left screen corner.

License: GPL-2.0-or-later. The layout logic and constants are ported from GNOME
Shell (gnome-50: `overviewControls.js`, `iconGrid.js`, `workspaceThumbnail.js`,
`dash.js`). The window layout uses KWin's `ExpoLayout`.

## Triggers

| Action                    | Default        | KWin shortcut name       |
|---------------------------|----------------|--------------------------|
| Toggle overview (windows) | `Meta+O`       | `Toggle GNOME Overview`  |
| Toggle app grid           | `Meta+Shift+O` | `Toggle GNOME App Grid`  |
| Top-right screen corner   | off            | effect setting           |

You can change the shortcuts in System Settings > Keyboard > Shortcuts > KWin.
GNOME uses `Super+A` for the app grid, but on this machine `Meta+A` is already
taken by Plasma's "Walk through activities".

From a script:

```sh
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Toggle GNOME Overview"
```

### Inside the overview

- Typing starts a search. Results show matching apps first (ranked like GNOME),
  then everything else from KRunner (Milou). `Enter` runs the first result.
  `Down` or `Tab` moves into the KRunner list.
- `Esc` clears the search. With no search, it goes from the app grid back to the
  window picker, or closes the overview.
- Window picker: click a window to activate it. Middle-click or the × button
  closes it.
- Workspace thumbnails: click one to switch to that desktop.
- App grid: the mouse wheel, a touchpad scroll, dragging, `←`/`→`,
  `PgUp`/`PgDn`, `Home`/`End` or clicking a page dot changes the page. Click an
  icon to launch the app.
- Dash: click a running app to focus it. Click an app that isn't running to
  launch it. Ctrl-click or middle-click always opens a new instance. The grid
  button at the end toggles the app grid.
- Clicking an empty area closes the overview.

## Build / install / uninstall

You need `cmake`, `extra-cmake-modules`, `qt6-qtdeclarative-devel`,
`kf6-kservice-devel`, `kf6-kconfig-devel` and `kf6-kcoreaddons-devel`.
You don't need `kwin-devel`.

```sh
./install.sh            # build, install to ~/.local, enable and (re)load the effect
./install.sh --no-load  # same, but leave the running KWin alone
./uninstall.sh          # unload and remove everything install.sh added
```

`install.sh` only writes inside your home directory:

| What | Where |
|------|-------|
| QML module `org.kgnome.overview` | `~/.local/lib64/qml/org/kgnome/overview/` |
| KWin effect package `kgnomeoverview` | `~/.local/share/kwin/effects/kgnomeoverview/` (via `kpackagetool6 --type KWin/Effect`) |
| Symlink to the package | `~/.local/share/kwin-wayland/effects/kgnomeoverview` (see below) |
| Env script | `~/.config/plasma-workspace/env/kgnome-overview.sh` (adds the module dir to `QML_IMPORT_PATH` at login) |
| kwinrc | `[Plugins] kgnomeoverviewEnabled=true`, `[Effect-kgnomeoverview] ImplDir=impl-<timestamp>` |

You can also toggle the effect in System Settings > Window Management >
Desktop Effects ("GNOME-style Overview").

### Settings

Settings live in the effect's settings dialog or in kwinrc
`[Effect-kgnomeoverview]`:

- `BlurBackground` (true): blur the wallpaper behind the overview.
- `IconScale` (1.0): multiplier for the GNOME icon sizes (96 px grid, 64 px dash
  at most). Useful at scale 1 on a 4K screen.
- `TopRightCorner` (false): toggle the overview from the top-right corner.
- `FavoriteApps` (empty): comma-separated desktop ids for the dash. If empty,
  the dash uses the Plasma launcher (Kickoff) favourites from
  `kactivitymanagerd-statsrc`.
- `Backend` (auto): `module`, `local` or `kicker`, to force an app backend.

Example:

```sh
kwriteconfig6 --file kwinrc --group Effect-kgnomeoverview --key IconScale 1.5
qdbus org.kde.KWin /KWin reconfigure
```

## How KWin finds the C++ module

KWin reads its environment, including `QML_IMPORT_PATH`, once at session start,
and `~/.local/lib64/qml` is not on Qt's default import path. The effect picks
the first app backend that loads:

1. `module`: `import org.kgnome.overview`. This works once the env script has
   been sourced, so after the next log out/in.
2. `local`: an absolute directory import of the installed module
   (`import "file:///home/…/org/kgnome/overview"`). `install.sh` generates this
   file. It works in a running session without a relogin.
3. `kicker`: a pure-QML fallback built on Plasma's private Kicker models
   (`RootModel`/`SimpleFavoritesModel`). Icons load synchronously here, and the
   dash uses the configured or default favourites.

The C++ module provides the following:

- `AppsModel`: visible applications from `KApplicationTrader`, sorted
  alphabetically, refreshed when KSycoca changes. It can also list favourites
  (`favoritesOnly`) or filter results (`filterString`).
- `Launcher.launch(id)`: runs `kstart --application <id>` (falling back to
  `gtk-launch`, then `gio launch`) through `QProcess::startDetached`, so apps
  are not children of KWin.
- Icon path resolution: theme lookup in C++, so QML can decode icons with
  `Image { asynchronous: true }`.

### Why `impl-<timestamp>` and the kwin-wayland symlink?

KWin compiles all declarative effects in one QML engine that lives as long as
the session and caches compiled QML by URL. A reinstalled effect would keep
running the old QML until you log out. To avoid that:

- `contents/ui/main.qml` is a small bootstrap that should never need to change.
- All real code lives in `contents/ui/impl-<timestamp>/`. The bootstrap reads the
  directory name from kwinrc (`ImplDir`), so every install gets fresh URLs.
- KWin looks in `kwin-wayland/effects/` before `kwin/effects/`. The symlink
  gave the bootstrap a URL that wasn't cached yet when the effect was first
  installed into the running session.

The C++ plugin cannot be unloaded from a running KWin. Changes to `src/` only
take effect after a log out/in.

## Layout (ported from GNOME)

- `spacing = 2% of height`. The search entry is at the top.
- The dash sits at the bottom, at most 16% of the height.
- Workspace thumbnails sit under the search entry, at most 5% of the height.
- `WINDOW_PICKER`: the workspace fills the space between thumbnails and dash.
- `APP_GRID`: the workspace shrinks to a strip (15% of the height) under the
  search entry, and the app grid fills the space below it.
- Each region has a box per state. The boxes are blended by `stateValue`
  (0 hidden, 1 window picker, 2 app grid), animated over 250 ms with OutQuad
  easing.
- App grid: the best mode among 8×3 / 6×4 / 4×6 / 3×8 (rows × columns) is
  picked by aspect ratio. Icons are the largest of 96/64/48/32/24/16 px that
  fit. Spacing is FILL, capped like GNOME's `max-row/column-spacing`.

## Known limits

- Keyboard focus/selection of individual windows and app icons is not
  implemented. The arrow keys change app-grid pages.
- No drag and drop: windows can't be dragged to workspaces, the dash can't be
  reordered, and there are no app folders.
- Only the current workspace's windows are shown. Neighbouring workspaces don't
  peek in from the sides as they do in GNOME.
- Panels are covered by the overview (they fade out, as in KWin's Overview).
- KRunner (Milou) results can repeat apps that are already in the Applications
  row. While focus is in the KRunner list, typing does not go back to the
  search entry.
- Multi-monitor: one overview per screen with a shared search text. Only tested
  on a single 4K monitor.
- No touchpad gestures yet.
