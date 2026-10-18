// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// The kgnome-overview effect's own settings dialog: KWin's generic config
// module for declarative effects, with the arguments the Desktop Effects
// page passes (EffectsModel::requestConfigure: [pluginId, "KWin/Effect"]).
// Falls back to System Settings > Desktop Effects.
const effectSettings =
    "kcmshell6 kwin/effects/configs/kcm_kwin4_genericscripted --args 'kgnomeoverview KWin/Effect'"
    + " --caption 'GNOME-style Overview' --icon view-app-grid-symbolic"
    + " || systemsettings kcm_kwin_effects";
