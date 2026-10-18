# kgnome-overview

A GNOME Shell style overview for KDE Plasma 6 (KWin, Wayland): search entry at
the top, workspace thumbnails, a window picker, a paged app grid and a dash with
your favourites, all driven by one animated state value like GNOME's
`OverviewControls`.

Installed with `install.sh` it runs side by side with Plasma's own Overview
effect and leaves Meta+W, the Meta key on its own and the top-left screen
corner alone. `dev/make-default.sh` makes it *the* overview, like on GNOME
(Meta, top-left corner, Meta+W, 4-finger swipes, a Show Apps button in place
of Kickoff); `dev/restore-defaults.sh` undoes that. See
[Making it the default](#making-it-the-default).

License: GPL-2.0-or-later. The layout logic and constants are ported from GNOME
Shell (gnome-50: `overviewControls.js`, `iconGrid.js`, `workspaceThumbnail.js`,
`dash.js`). The window layout uses KWin's `ExpoLayout`.

## Triggers

| Action                    | Default        | KWin shortcut name       |
|---------------------------|----------------|--------------------------|
| Toggle overview (windows) | `Meta+O`       | `Toggle GNOME Overview`  |
| Toggle app grid           | `Meta+Shift+O` | `Toggle GNOME App Grid`  |
| Hot corner                | top left       | `HotCorner` setting      |
| Touchpad swipe up / down  | 4 fingers      | `GestureFingers` setting |
| Meta on its own           | after `make-default.sh` | kwinrc `[ModifierOnlyShortcuts]` |
| `Meta+W`                  | after `make-default.sh` | second key of `Toggle GNOME Overview` |
| Panel Show Apps button / `Alt+F1` | after `make-default.sh` | plasmoid `org.kgnome.overview.showapps` |

You can change the shortcuts in System Settings > Keyboard > Shortcuts > KWin.
GNOME uses `Super+A` for the app grid, but on this machine `Meta+A` is already
taken by Plasma's "Walk through activities".

From a script:

```sh
qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "Toggle GNOME Overview"
```

### Inside the overview

- Typing starts a search. Results show matching apps first (ranked like
  GNOME), then everything else from KRunner, grouped by category, without the
  apps already in the app row. Keys follow GNOME 50 (`searchController.js`):
  with the cursor in the entry the first result is the default and `Enter`
  runs it; `↓`, `Tab`, `Shift+Tab` or `→` at the end of the text move keyboard
  focus into the results (focus ring, text cursor hidden), where the arrows and
  `Tab` move it and `Enter` runs the focused result. Typing or `Backspace`
  goes back to the entry and edits the text (the default goes back to the
  first result); `↑` from the top row returns to the entry.
  Not in GNOME: `SearchFocusReturnMs` (250 ms) after the last arrow key the
  cursor returns to the entry while the highlighted result stays selected, so
  `Enter` still runs it and `←`/`→` edit the text again.
- `Esc` closes an open folder, then clears the search, then goes from the app
  grid back to the window picker, then closes the overview.
- Touchpad (4 fingers by default, like GNOME): swipe up goes hidden → window
  picker → app grid, swipe down goes back. The overview follows the fingers and
  settles when they lift. Left/right swipes with 3 or 4 fingers stay KWin's own
  desktop switching (KWin core registers them for both counts); with another
  finger count the overview registers its own left/right swipes for
  workspaces/pages. KWin's built-in Overview also binds 4-finger up/down, so
  switch it off (`make-default.sh` does) to avoid two effects reacting.
- Window picker: click a window to activate it. Middle-click or the × button
  closes it. Drag a window onto a thumbnail, a side peek or a workspace in the
  strip to move it to that desktop. Click a side workspace to switch to it.
  Click empty space (or the current workspace's wallpaper) to close the
  overview. The scroll wheel or a two-finger touchpad scroll switches
  workspaces; `Ctrl+Alt+←/→` too.
- Workspace thumbnails: click one to switch to that desktop.
- App grid: drag empty space, scroll with two fingers, use the wheel, the side
  arrows, `←`/`→`, `PgUp`/`PgDn`, `Home`/`End` or a page dot to change the page.
  Dragging an icon moves it: drop it between icons to reorder (the others make
  room after 200 ms), on another app's centre to create a folder (named after
  the menu category both share, else "Unnamed Folder"), on a folder to add it,
  on the dash to pin it at that position, or on a workspace (thumbnail or the strip at
  the top) to launch it there. Rest at the left/right edge for 1 s to flip the
  page. In a folder, drag an app out of the dialog to take it out of the
  folder (a folder left with one app dissolves); click the folder name to
  rename it. The arrangement is saved. Click an app to launch it (a running app is focused;
  middle- or Ctrl-click opens a new window). Click a folder to open it. Click
  empty space to go back to the window picker. Clicking a workspace in the
  strip at the top activates it.
- Dash (GNOME `dash.js`): favourites, then running apps that aren't
  favourites after a separator, then the Show Apps button. Click a running
  app to focus it, an app that isn't running to launch it; Ctrl- or
  middle-click opens a new window. Drag icons to reorder (a gap opens where
  they will land); drag a favourite onto the Show Apps button (it turns into
  an "Unpin" bin while you drag), onto the app grid (where it lands at the drop
  position, like GNOME) or well away from the dash to unpin it. Drag a running
  app or a grid icon into the dash to pin it at that position. Right-click
  (dash, grid, folders): New Window, Pin to Dash / Unpin, Quit (closes its
  windows, shown while running).
- Favourites are shared two-way with Kickoff (KActivities favourites, the
  same list and order Kickoff shows). Like GNOME, favourites are not shown in
  the app grid (`HideFavoritesInGrid`).

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
| kwinrc | `[Plugins] kgnomeoverviewEnabled=true`, `[Effect-kgnomeoverview] ImplDir=impl-<timestamp>`, `FavoritesClient` |
| Panel plasmoid `org.kgnome.overview.showapps` | `~/.local/share/plasma/plasmoids/` (via `kpackagetool6 --type Plasma/Applet`); not added to a panel |

You can also toggle the effect in System Settings > Window Management >
Desktop Effects ("GNOME-style Overview").

### Settings

Settings live in the effect's settings dialog or in kwinrc
`[Effect-kgnomeoverview]`:

- `BlurBackground` (true): blur the wallpaper behind the overview.
- `IconScale` (1.0): multiplier for the GNOME icon sizes (96 px grid, 64 px dash
  at most). Useful at scale 1 on a 4K screen.
- `HotCorner` (1): screen corner that toggles the overview: `0` none, `1` top
  left (GNOME's), `2` top right, `3` bottom left, `4` bottom right. Plasma's
  built-in Overview also uses the top-left corner by default;
  `make-default.sh` frees it (`[Effect-overview] BorderActivate=9`).
- `FavoritesClient` (set by install.sh, e.g.
  `org.kde.plasma.kickoff.favorites.instance-118`): the launcher whose
  KActivities favourites the dash shares, through Plasma's
  `KAStatsFavoritesModel`. Set it to an empty value to use `FavoriteApps`.
- `FavoriteApps` (empty): comma-separated desktop ids for the dash, only used
  without `FavoritesClient`. If empty, the dash shows the Kickoff favourites
  read-only.
- `HideFavoritesInGrid` (true): like GNOME, favourites aren't in the grid or
  folders (they keep their folder and position for when they are unpinned).
- `DashIconSize` (64): largest dash icon size; GNOME's 48/32/24/22/16 are
  used if the dash doesn't fit.
- `SearchFocusReturnMs` (250): see the search keys above; `0` = GNOME's
  behaviour (focus stays on the result until you type).
- `Backend` (auto): `module`, `local` or `kicker`, to force an app backend.
- `IconSize` (112): app grid icon size in px; steps down through GNOME's
  sizes if the grid doesn't fit. `0` = GNOME's automatic 96/64/48/... sizes.
- `Columns` (10): app grid columns. `0` = GNOME's 8×3/6×4/4×6/3×8 modes.
- `Rows` (0): app grid rows; `0` picks the row count closest to the screen
  shape that fits. GNOME's spacing logic (12 px, at most 36 px) is kept.
  These apply live when saved in the settings dialog (or after
  `qdbus org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect kgnomeoverview`).
- `AppLayout` / `AppFolders`: written by the overview when you rearrange the
  grid. Delete both keys to go back to alphabetical order and the default
  folders.
- `GestureFingers` (4): fingers for the touchpad swipes, `0` turns them off.
  The swipe-up gesture is registered globally, so apps no longer get it; the
  other directions exist only while the overview is open. (KWin core keeps its
  3-finger desktop swipes in all four directions whatever this is set to.)
- `AppFolders` (empty): app folders as `Name=id1;id2;...` entries (desktop file
  ids, comma-separated entries). If empty, the built-in "Utilities" and "System"
  folders (KDE equivalents of GNOME's defaults, see `impl/Folders.js`) are used.

Example:

```sh
kwriteconfig6 --file kwinrc --group Effect-kgnomeoverview --key IconScale 1.5
qdbus org.kde.KWin /KWin reconfigure
```

## Making it the default

```sh
dev/make-default.sh                 # all steps
dev/make-default.sh meta corner     # only some: meta corner builtin gestures panel
dev/restore-defaults.sh             # undo (oldest backup = the state before any change)
dev/restore-defaults.sh backup/<timestamp>
```

Every run of `make-default.sh` first copies `kwinrc`, `kglobalshortcutsrc`,
`plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc` and
`kactivitymanagerdrc` to `backup/<timestamp>/` (git-ignored). The steps, all
live in the running session (no logout, no plasmashell or KWin restart):

- `meta`: Meta on its own toggles the overview (kwinrc
  `[ModifierOnlyShortcuts] Meta=…,invokeShortcut,Toggle GNOME Overview`).
- `corner`: frees the built-in Overview's screen edges and sets `HotCorner=1`.
- `builtin`: `[Plugins] overviewEnabled=false`, unloads Plasma's Overview, and
  moves `Meta+W` from its `Overview` shortcut to `Toggle GNOME Overview`
  (which keeps `Meta+O`).
- `gestures`: `GestureFingers=4`.
- `panel`: replaces Kickoff with the Show Apps plasmoid at the same position,
  through plasmashell's `evaluateScript`. The dash favourites are not migrated
  because nothing has to move: they belong to Kickoff's KActivities client id
  (links in kactivitymanagerd, order in `kactivitymanagerd-statsrc`), and
  `FavoritesClient` keeps pointing at it after Kickoff is gone. The script
  prints the panel layout and the favourite count before and after.

`restore-defaults.sh` copies the backed-up files back, puts Kickoff back where
the launcher is (same index, through `evaluateScript`), returns `Meta+W` to
Plasma's Overview and reloads it. `kactivitymanagerd-statsrc` (favourite
order) is only restored with `RESTORE_STATSRC=1`. The re-added Kickoff is a new
applet instance; the original one (and its favourites client) comes back from
the restored appletsrc at the next login.

### The Show Apps plasmoid

`plasmoid/org.kgnome.overview.showapps`: a panel icon (default
`view-app-grid-symbolic`, configurable) that opens the app grid, or the window
picker (setting "Opens"), through `invokeShortcut` on KWin's global shortcut
component. It provides `org.kde.plasma.launchermenu`, so Plasma's
"Activate Application Launcher" shortcut (`Alt+F1`) opens the grid too.
Add it by hand from "Add Widgets…" (Application Launchers) if you don't use
`make-default.sh`.

plasmashell caches an applet's QML by URL for the whole session, like KWin
does for effects: after `kpackagetool6 --upgrade` a running plasmashell keeps
the old `main.qml` until the next login. (That's why the plasmoid's id changed
from `org.kgnome.overview.launcher` to `org.kgnome.overview.showapps` once.)

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

## Layout (ported from GNOME 50)

Sources: gnome-shell `gnome-50` branch, `js/ui/overviewControls.js`,
`js/ui/workspacesView.js`, `js/ui/workspace.js`, `js/ui/iconGrid.js`,
`js/ui/appDisplay.js`, `js/ui/pageIndicators.js` and
`data/theme/gnome-shell-sass/widgets/*.scss`.

- `spacing = 2% of height`. The search entry (24em wide, 12px from the top)
  is at the top; the dash pill sits at the bottom, at most 16% of the height.
- Workspace thumbnails sit under the search entry, at most 5% of the height,
  only with more than one workspace.
- `WINDOW_PICKER`: `FitMode.SINGLE`. The current workspace is centred in the
  box between thumbnails and dash, the neighbours sit beside it with
  `clamp(available − 0.4·width, 24, 80)` px spacing and peek in from the sides.
  Inactive workspaces are scaled to 94%. Windows are spread out (KWin's
  ExpoLayout, at most 95% of their real size).
- `APP_GRID`: `FitMode.ALL`. All workspaces are shown side by side as small live
  previews in a strip (15% of the height) under the search entry, windows at
  their natural positions. The thumbnails fade out, scale to 50% and slide
  down. The app grid fills the space below.
- Each region has a box per state, blended by `stateValue`
  (0 hidden, 1 window picker, 2 app grid), animated over 250 ms (OutQuad);
  workspace switches animate over 250 ms (OutCubic).
- App grid: the best mode among 8×3 / 6×4 / 4×6 / 3×8 (rows × columns) is
  picked by aspect ratio; icons are the largest of 96/64/48/32/24/16 px that
  fit; spacing 12 px growing to at most 36 px; page padding 24 px top/bottom
  and 18 px plus 10% of the width per side (navigation arrows); 10 px
  horizontal page dots under the grid; pages switch in 300 ms.
- Colours: background `#222226` (optionally tinted over the blurred
  wallpaper), dash/folder dialog `#38383b`, search entry `#2e2e33`, accent from
  the Plasma colour scheme.

## Known limits

- Keyboard focus/selection of individual windows and app icons is not
  implemented. The arrow keys change app-grid pages.
- Search focus on a result is logical: Qt keyboard focus stays in the text
  field (so KRunner model resets can't swallow keys); it looks and behaves
  like GNOME's.
- The app menu has no per-window entries, "App Details" or GPU launch item.
- The physical Meta key, the hot corner and the touchpad gestures were set up
  and verified through config/DBus but not by real input on this machine.
- Touchpad swipes move one step per gesture (hidden → picker or picker → grid),
  not continuously through both like GNOME.
- Panels are covered by the overview (they fade out, as in KWin's Overview).
- Multi-monitor: one overview per screen with a shared search text. Only tested
  on a single 4K monitor.
