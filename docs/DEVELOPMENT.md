# Developer notes

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
- Colours: background `#222226`, solid, or with blur as a tint over the
  blurred wallpaper at `BackgroundTint` % (default 30), dash/folder dialog `#38383b`, search entry `#2e2e33`, accent from
  the Plasma colour scheme.


## Dynamic workspaces vs. GNOME

Ported from gnome-shell `gnome-50`:

- `js/ui/windowManager.js` `WorkspaceTracker._checkWorkspaces` →
  `impl/DynamicWorkspaces.qml`: a workspace is in use if a window that isn't
  on all workspaces is on it, if a dialog/splash left it less than 1 s ago
  (`LAST_WINDOW_GRACE_TIME`) or if it is kept alive for a launch; append one
  if the last is in use; remove empty ones from the end except the active one
  and the first empty one after the last used; at least 2
  (`MIN_NUM_WORKSPACES`). Checked after window added/removed/moved, desktop
  switch and desktop list changes.
- `js/ui/workspaceThumbnail.js` `ThumbnailsBox.handleDragOver`/`acceptDrop`,
  `_getPlaceholderTarget`, `_withinWorkspace`: placeholder zones
  (`WORKSPACE_CUT_SIZE` 10 px, 18 px placeholder), `Main.wm.insertWorkspace`
  then move the window / launch the app, `keepWorkspaceAlive`.
- `js/ui/workspace.js` `Workspace.acceptDrop`: dropping on a workspace (peek
  or strip) moves the window / launches the app there.

Differences:

- KWin can insert a desktop at an index, so nothing has to shift windows
  between workspaces the way `insertWorkspace` does.
- GNOME keeps a new workspace alive while the app's startup sequence runs;
  the effect can't see startup notifications, so it keeps it for 15 s.
- Dropping an app on a workspace switches to it and closes the overview (KWin
  puts new windows on the current desktop); GNOME launches it there and stays
  in the overview.
- GNOME hides the thumbnails with only 2 workspaces (one used + the empty
  one); here they show whenever there's more than one desktop, so there is
  always a "top bar" to drop on.
- Windows hidden from the taskbar, pager and switcher (e.g.
  xwaylandvideobridge) don't keep a desktop alive.
- No removals for 10 s after the effect loads (session start, other scripts
  placing windows), and the tracker pauses itself (journal: "dynamic
  workspaces paused") if another party keeps undoing its changes (more than
  24 automatic changes and at least 12 outside desktop changes in 10 s, e.g.
  a script that enforces a fixed count); it resumes after a minute without
  outside changes. Settings changes, reloads and your own drops/closes can't
  trip it, and the check re-runs on load, when the overview opens, after a
  settings change and every 30 s. Windows on all desktops (how
  the virtualdesktopsonlyonprimary script parks other screens) never keep a
  desktop alive, and a desktop is only removed when no window at all is on
  it, so tilers like Krohnkite don't lose windows.
- Default desktop names ("Desktop N") are renumbered after a change.
- The × to close a desktop and the "+" on the trailing empty thumbnail are
  not in GNOME.


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


### plasmashell caches applet QML too

plasmashell caches an applet's QML by URL for the whole session, like KWin
does for effects: after `kpackagetool6 --upgrade` a running plasmashell keeps
the old `main.qml` until the next login. (That's why the Show Apps plasmoid's
id changed from `org.kgnome.overview.launcher` to
`org.kgnome.overview.showapps` once.) `dev/sheet-test.sh` shows the installed
System Menu in a separate `plasmawindowed` process (fresh QML engine) and
takes a screenshot; writing `expandRequest` in the applet config opens it
from a script.

## Development helpers

- `dev/cycle.sh`: reinstall and reload the effect, show its journal lines.
- `dev/shot.sh NAME`: open the overview, take a screenshot, close it.
- `dev/desktops.sh`: list the desktops and the windows on each.
- `dev/drive.sh 'JS'`: with `DevHooks=true` in `[Effect-kgnomeoverview]`, run
  JS inside the effect (`effect`, `view`, `workspace` in scope), e.g. to
  simulate drags: `view.beginWindowDrag(w, p)`, `view.moveWindowDrag(p)`,
  `view.endWindowDrag(p)`, `view.iconDragBegin(...)`.
