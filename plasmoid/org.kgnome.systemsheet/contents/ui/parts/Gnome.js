// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME Shell 50 dark palette and metrics (gnome-shell data/theme/
// gnome-shell-sass: _colors.scss, widgets/_quick-settings.scss). Pixel values
// are at 1x and get multiplied by the caller's scale factor.
.pragma library

const sheetBg = "#2e2e32";        // popover bg
const fg = "#ffffff";
const buttonBg = Qt.rgba(1, 1, 1, 0.10);   // transparentize($fg, .9)
const buttonHover = Qt.rgba(1, 1, 1, 0.15);
const buttonActive = Qt.rgba(1, 1, 1, 0.22);
const menuBg = Qt.rgba(1, 1, 1, 0.06);     // .quick-toggle-menu
const separator = Qt.rgba(1, 1, 1, 0.12);

const basePadding = 6;            // $base_padding
const iconSize = 16;              // $scalable_icon_size
const sheetPadding = basePadding * 3;
const sheetRadius = 12 * 2.25;    // $modal_radius * 2.25
const gridSpacing = basePadding * 2;
const toggleWidth = 176;          // 12em at 11pt
const toggleHeight = iconSize * 3;
const iconButtonPadding = basePadding * 1.75;
const menuRadius = 18;
