# Contributing

Bug reports and pull requests are welcome.

- **Bugs**: include your distribution, Plasma version
  (`plasmashell --version`), whether you ran `--make-default`, and the
  relevant journal lines:
  `journalctl --user -b | grep -E 'kgnome|kwin_wayland|plasmashell'`.
- **Building and testing**: `./install.sh --no-make-default` reinstalls and
  reloads the effect; see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the
  helpers in `dev/` and for why plasmashell and KWin cache QML.
- **Behaviour**: the goal is to match GNOME Shell (currently gnome-50). When
  something deliberately differs from GNOME, say so in the README.
- **Licensing**: contributions are accepted under GPL-2.0-or-later. New files
  carry an `SPDX-FileCopyrightText` and `SPDX-License-Identifier` header.
- One logical change per commit.
