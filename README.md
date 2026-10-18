# kgnome-overview

GNOME Shell's overview, app grid and Quick Settings menu for KDE Plasma 6
(KWin, Wayland).

- **Overview**: a KWin effect ("GNOME-style Overview") with the search entry
  at the top, workspace thumbnails, the window picker with side workspaces,
  a paged app grid with folders and a dash with your favourites, animated
  like GNOME's `OverviewControls`. Dynamic workspaces, drag and drop of
  windows and apps onto workspaces, touchpad gestures, hot corner.
- **Show Apps** panel button (`org.kgnome.overview.showapps`): opens the app
  grid (or the window picker), also on `Alt+F1`.
- **System Menu** panel/tray widget (`org.kgnome.systemsheet`, "GNOME-style
  System Menu"): GNOME 50's Quick Settings sheet with screenshot, settings,
  lock and an inline power menu (Suspend, Restart, Power Off, Log Out,
  Switch User), volume/microphone/brightness sliders and quick toggles for
  Wired, Wi-Fi, VPN, Bluetooth, Power Mode, Night Light, Dark Style, Do Not
  Disturb, keyboard backlight and Airplane Mode.

Everything installs into your home directory; no root needed except for the
build dependencies. By default it runs side by side with Plasma's own
Overview and Application Launcher; one command (or a prompt in the
installer) makes it the default, another undoes that.

![System Menu](docs/screenshots/system-menu.png)

## Requirements

Plasma 6 on Wayland (developed and tested on Plasma 6.7; older 6.x releases
may lack some System Menu controls, which are then hidden). To build: CMake, a C++20
compiler, extra-cmake-modules, Qt 6 (Base, Declarative) and KF6 Service,
Config and CoreAddons development files. `kwin-devel` is not needed.

| Distribution | Command |
|---|---|
| Fedora | `sudo dnf install cmake gcc-c++ extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel` |
| Arch / Manjaro / EndeavourOS | `sudo pacman -S --needed base-devel cmake extra-cmake-modules qt6-base qt6-declarative kservice kconfig kcoreaddons` |
| openSUSE Tumbleweed | `sudo zypper install cmake gcc-c++ kf6-extra-cmake-modules qt6-base-devel qt6-declarative-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel` |
| Kubuntu / Debian (Plasma 6: Kubuntu 25.04+, Debian 13+) | `sudo apt install cmake g++ extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6service-dev libkf6config-dev libkf6coreaddons-dev` |

`install.sh` checks for the tools it needs and prints the matching command
if something is missing. At runtime the System Menu uses what Plasma
already ships (plasma-workspace, plasma-pa, plasma-nm, bluedevil,
powerdevil, spectacle); controls whose service is missing are hidden.

## Install

```sh
git clone https://github.com/Adroited-LLC/kgnome-overview.git
cd kgnome-overview
./install.sh                    # build, install to ~/.local, load the effect; asks
                                # whether to make it the default
./install.sh --make-default     # same, and make it the default without asking
./install.sh --no-make-default  # never ask
./install.sh --no-load          # install only, leave the running session alone
```

The effect works right away in the running session. Log out and back in
once after the first install anyway: the environment script that lets KWin
import the C++ module the normal way is read at login. Running
`./install.sh` again updates everything; KWin reloads the effect at once,
while plasmashell only shows an updated Show Apps or System Menu widget
after a re-login or `systemctl --user restart plasma-plasmashell`, and
changes to the C++ module (`src/`) need a re-login.

### Making it the default

`./install.sh --make-default` (or `scripts/make-default.sh`) makes it *the*
overview, like on GNOME: Meta on its own, the top-left corner, `Meta+W`,
4-finger swipes, and a Show Apps button plus the System Menu on the panel
in place of the Application Launcher. All live, no re-login.

```sh
scripts/make-default.sh                 # all steps
scripts/make-default.sh meta corner     # only some: meta corner builtin gestures panel
scripts/restore-defaults.sh             # undo (oldest make-default backup = the state before)
scripts/restore-defaults.sh <timestamp> # restore backup/<timestamp>
```

Every run of `make-default.sh` first copies `kwinrc`, `kglobalshortcutsrc`,
`plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc` and
`kactivitymanagerdrc` to `backup/<timestamp>/` (git-ignored). The steps, all
live in the running session (no logout, no plasmashell or KWin restart):

- `meta`: Meta on its own opens the overview (kwinrc
  `[ModifierOnlyShortcuts] Meta=…,invokeShortcut,Cycle GNOME Overview`).
- `corner`: frees the built-in Overview's screen edges and sets `HotCorner=1`.
- `builtin`: `[Plugins] overviewEnabled=false`, unloads Plasma's Overview, and
  moves `Meta+W` from its `Overview` shortcut to `Toggle GNOME Overview`
  (which keeps `Meta+O`).
- `gestures`: `GestureFingers=4`.
- `panel`: replaces Kickoff with the Show Apps plasmoid at the same position,
  through plasmashell's `evaluateScript`, and makes sure the System Menu sits
  before the system tray (Kickoff was the Log Out / Power Off entry point). The dash favourites are not migrated
  because nothing has to move: they belong to Kickoff's KActivities client id
  (links in kactivitymanagerd, order in `kactivitymanagerd-statsrc`), and
  `FavoritesClient` keeps pointing at it after Kickoff is gone. The script
  prints the panel layout and the favourite count before and after.

`restore-defaults.sh` removes the System Menu, copies the backed-up files back, puts Kickoff back where
the launcher is (same index, through `evaluateScript`), returns `Meta+W` to
Plasma's Overview and reloads it. `kactivitymanagerd-statsrc` (favourite
order) is only restored with `RESTORE_STATSRC=1`. The re-added Kickoff is a new
applet instance; the original one (and its favourites client) comes back from
the restored appletsrc at the next login.

### Uninstall

```sh
scripts/restore-defaults.sh   # if you made it the default
./uninstall.sh                # unload and remove everything install.sh added
```

`install.sh` only writes inside your home directory:

| What | Where |
|------|-------|
| QML module `org.kgnome.overview` | `~/.local/lib64/qml/org/kgnome/overview/` (or `lib/`) |
| KWin effect package `kgnomeoverview` | `~/.local/share/kwin/effects/kgnomeoverview/` (via `kpackagetool6 --type KWin/Effect`) |
| Symlink to the package | `~/.local/share/kwin-wayland/effects/kgnomeoverview` |
| Env script | `~/.config/plasma-workspace/env/kgnome-overview.sh` (adds the module dir to `QML_IMPORT_PATH` at login) |
| kwinrc | `[Plugins] kgnomeoverviewEnabled=true`, `[Effect-kgnomeoverview] ImplDir=impl-<timestamp>`, `FavoritesClient` |
| Show Apps plasmoid `org.kgnome.overview.showapps` | `~/.local/share/plasma/plasmoids/`; put on the panel by `make-default` |
| System Menu plasmoid `org.kgnome.systemsheet` | `~/.local/share/plasma/plasmoids/`; added before the system tray of every panel that has the Show Apps button, if there is no System Menu anywhere yet (appletsrc backed up to `backup/<timestamp>-install/` first) |

## Using it

| Action                    | Default        | KWin shortcut name       |
|---------------------------|----------------|--------------------------|
| Toggle overview (windows) | `Meta+O`       | `Toggle GNOME Overview`  |
| Toggle app grid           | `Meta+Shift+O` | `Toggle GNOME App Grid`  |
| Hot corner                | top left       | `HotCorner` setting      |
| Touchpad swipe up / down  | 4 fingers      | `GestureFingers` setting |
| Meta on its own           | after make-default | `Cycle GNOME Overview` (kwinrc `[ModifierOnlyShortcuts]`) |
| `Meta+W`                  | after make-default | second key of `Toggle GNOME Overview` |
| Panel Show Apps button / `Alt+F1` | after make-default | plasmoid `org.kgnome.overview.showapps` |

Meta on its own cycles: the first press opens the window picker, the second
goes on to the app grid, the third closes the overview (`MetaCycle=cycle`,
default). GNOME closes on the second press; set "Meta key" to "Toggle" in the
effect settings (`MetaCycle=toggle`) for that. `Meta+O`, `Meta+W`, the hot
corner and the panel button always toggle.

Change the shortcuts in System Settings > Keyboard > Shortcuts > KWin.
GNOME uses `Super+A` for the app grid, but in Plasma `Meta+A` is already
taken by "Walk through activities". From a script:

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
- Dynamic workspaces (GNOME's default, `DynamicWorkspaces`): there is always
  one empty desktop at the end, and empty desktops go away (on window close,
  window moves and desktop switches, also while the overview is closed; the
  current desktop stays until you leave it). Drag a window, or an app from the
  grid, a folder or the dash, onto the empty last thumbnail to put it on a new
  desktop, or between two thumbnails: they slide apart, a placeholder bar
  shows, and the drop creates a desktop at that spot. In the app grid the gaps
  between the workspaces of the strip at the top work the same way.
- Hover a workspace (thumbnail, side peek in the window picker, strip in the
  app grid) for an × that closes the desktop. Its windows move to the
  neighbouring desktop (the previous one; the next one for the first desktop);
  nothing is closed. The last desktop, and the empty trailing one, have no ×.
  GNOME has no such button.
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

### Show Apps

`plasmoid/org.kgnome.overview.showapps`: a panel icon (default
`view-app-grid-symbolic`, configurable) that opens the app grid, or the window
picker (setting "Opens"), through `invokeShortcut` on KWin's global shortcut
component. It provides `org.kde.plasma.launchermenu`, so Plasma's
"Activate Application Launcher" shortcut (`Alt+F1`) opens the grid too.
Add it by hand from "Add Widgets…" (Application Launchers) if you don't use
`make-default.sh`. Its settings page and right-click menu have
"Overview Settings…", which opens the effect's settings dialog directly:

```sh
kcmshell6 kwin/effects/configs/kcm_kwin4_genericscripted --args 'kgnomeoverview KWin/Effect'
```

### System Menu

`install.sh` puts it on the Show Apps panel, before the tray. Elsewhere:
"Add Widgets…" → "GNOME-style System Menu" (any panel or the desktop), or
inside the system tray: tray settings → Entries → "GNOME-style System Menu"
→ Always shown (it is a System Services tray entry).
`scripts/system-menu.sh ensure|remove` adds/removes it on the Show Apps panel.

Layout, top to bottom, as in gnome-shell 50 (`js/ui/panel.js`
`QuickSettings._setupIndicators`, `js/ui/status/*.js`):

- System row (`status/system.js`): battery percentage (only with a battery;
  opens the power settings), Take Screenshot (`spectacle -r`), Settings
  (System Settings), Lock, and the power button whose "Power Off" menu slides
  open inline: Suspend, Restart…, Power Off…, Log Out…, Switch User…. These
  go through Plasma's SessionManagement; Restart, Power Off and Log Out always
  show KDE's own confirmation screen. Items the system can't do are hidden.
- Output volume (plasma-pa, the icon mutes; with more than one output an
  arrow opens "Sound Output" to pick the device), microphone volume only
  while an app is recording, and screen brightness per display PowerDevil can
  control (laptop backlight or DDC/CI monitors).
- Two-column toggles; ones whose hardware or service is missing are hidden:
  Wired, Wi-Fi (network list, password asked inline), VPN (list), Bluetooth
  (paired devices), Power Mode (power-profiles-daemon / tuned-ppd via
  PowerDevil), Night Light (pauses/resumes; opens its settings if Night
  Light is off), Dark Style (switches between the default light and dark
  Global Themes, i.e. `plasma-apply-lookandfeel`, which also resets that
  theme's colours and icons), Do Not Disturb, Keyboard backlight, Airplane
  Mode.

Settings (right-click → Configure): panel icon (single power/battery icon or
GNOME's network/volume/battery icons; the tray always uses one icon), style
(follow the Plasma theme, GNOME dark, GNOME light), accent (GNOME blue
`#3584e4` or the Plasma accent), sheet corner radius (0 = square like other
Plasma popups, GNOME uses 36), user name and picture header (not in GNOME
50), quick toggles on/off, Dark Style toggle on/off.

Differences from GNOME: GNOME 50 opens this from the top bar's status area
and shows no user name or avatar in it (the name only appears in the Log Out
dialog); Plasma always draws its popup frame, so the card fills it; the
Wi-Fi/Bluetooth lists don't offer hidden networks or pairing (those are in
System Settings, linked from each menu); Log Out is always offered (GNOME
hides it on single-user machines).

## Settings

### Overview

In System Settings > Window Management > Desktop Effects > "GNOME-style
Overview" (configure button), from the Show Apps button's "Overview
Settings…", or in kwinrc `[Effect-kgnomeoverview]`:

`[Effect-kgnomeoverview]`:

- `BlurBackground` (true): blur the wallpaper behind the overview.
- `IconScale` (1.0): multiplier for the GNOME icon sizes (96 px grid, 64 px dash
  at most). Useful at scale 1 on a 4K screen.
- `HotCorner` (1): screen corner that toggles the overview: `0` none, `1` top
  left (GNOME's), `2` top right, `3` bottom left, `4` bottom right. Plasma's
  built-in Overview also uses the top-left corner by default;
  `make-default.sh` frees it (`[Effect-overview] BorderActivate=9`).
- `FavoritesClient` (set by install.sh, e.g.
  `org.kde.plasma.kickoff.favorites.instance-<N>`, N = Kickoff's applet id): the launcher whose
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
- `MetaCycle` (cycle): Meta alone cycles picker → app grid → closed; `toggle`
  = GNOME (second press closes).
- `DynamicWorkspaces` (true): GNOME dynamic workspaces, see above. Off: the
  desktop count is left alone and no placeholder appears (thumbnail drops and
  the × still work).
- `GestureFingers` (4): fingers for the touchpad swipes, `0` turns them off.
  The swipe-up gesture is registered globally, so apps no longer get it; the
  other directions exist only while the overview is open. (KWin core keeps its
  3-finger desktop swipes in all four directions whatever this is set to.)
- `DevHooks` / `DevScript` (off): development only, see `dev/drive.sh`.
- `AppFolders` (empty): app folders as `Name=id1;id2;...` entries (desktop file
  ids, comma-separated entries). If empty, the built-in "Utilities" and "System"
  folders (KDE equivalents of GNOME's defaults, see `impl/Folders.js`) are used.

Example:

```sh
kwriteconfig6 --file kwinrc --group Effect-kgnomeoverview --key IconScale 1.5
qdbus org.kde.KWin /KWin reconfigure
```

## Known limits

- Keyboard focus/selection of individual windows and app icons is not
  implemented. The arrow keys change app-grid pages.
- Search focus on a result is logical: Qt keyboard focus stays in the text
  field (so KRunner model resets can't swallow keys); it looks and behaves
  like GNOME's.
- The app menu has no per-window entries, "App Details" or GPU launch item.
- The Meta cycle, hot corner and touchpad gestures are tested through
  config/DBus; real-input testing has been on one machine only.
- Touchpad swipes move one step per gesture (hidden → picker or picker → grid),
  not continuously through both like GNOME.
- Panels are covered by the overview (they fade out, as in KWin's Overview).
- Multi-monitor: one overview per screen with a shared search text. Tested
  on a single 4K monitor only.
- System Menu: Wi-Fi/Bluetooth lists don't offer hidden networks,
  enterprise Wi-Fi or pairing (each menu links to System Settings); no Screen
  Recording toggle, per-app volume or background-apps list; the Wired and VPN
  menus only list profiles. Dark Style switches the whole Global Theme
  (default Breeze light/dark), which resets that theme's colours and icons.
- The Wired toggle disconnects the active wired connection, as in GNOME. If
  your network runs over a bridge or bond, that cuts the connection.
- Plasma always draws its own popup frame; the sheet fills it.
- An updated panel plasmoid is only picked up by plasmashell after a re-login
  (or `systemctl --user restart plasma-plasmashell`); KWin keeps an already
  loaded C++ module until the next login.

## License and credits

kgnome-overview is free software under the GNU General Public License,
version 2 or (at your option) any later version (`GPL-2.0-or-later`, see
[LICENSES/GPL-2.0-or-later.txt](LICENSES/GPL-2.0-or-later.txt)).

Copyright © 2026 Matt Hoffer <matt@adroited.com>.

The overview layout, constants and behaviour, the dynamic workspaces and the
System Menu design are ported from or modelled on
[GNOME Shell](https://gitlab.gnome.org/GNOME/gnome-shell) (gnome-50,
GPL-2.0-or-later). The window layout uses
[KWin](https://invent.kde.org/plasma/kwin)'s `ExpoLayout`, and the effect,
plasmoids and System Menu are built on KWin, libplasma, Plasma Workspace,
plasma-pa, plasma-nm, BluezQt and PowerDevil. Not affiliated with or
endorsed by the GNOME Foundation or KDE e.V.

Developer notes (how it is ported, the QML caching workarounds, test
helpers): [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
