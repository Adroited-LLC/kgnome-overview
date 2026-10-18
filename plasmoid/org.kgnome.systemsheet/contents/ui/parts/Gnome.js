// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME Shell 50 colours and metrics, computed from gnome-shell (gnome-50)
// data/theme/gnome-shell-sass: _colors.scss, _palette.scss,
// _default-colors.scss, _common.scss, _drawing.scss (button mixin),
// widgets/_quick-settings.scss, widgets/_slider.scss, widgets/_popovers.scss.
// Pixel values are at 1x (11pt) and get multiplied by the caller's scale.
.pragma library

const gnomeAccent = "#3584e4";     // $blue_3, GNOME's default accent

// $base_padding 6px, $base_border_radius 8px, $modal_radius 16px,
// $scalable_icon_size 16px (to_em at 11pt)
const basePadding = 6;
const iconSize = 16;
const sheetPadding = basePadding * 3;          // .quick-settings padding
const sheetRadius = 16 * 2.25;                 // $modal_radius * 2.25
const gridSpacing = basePadding * 2;           // .quick-settings-grid spacing
const systemRowSpacing = basePadding * 2;      // .quick-settings-system-item
const toggleWidth = 176;                       // .quick-toggle 12em at 11pt
const toggleHeight = iconSize * 3;             // min-height 3 × icon
const iconButtonPadding = basePadding * 1.75;  // .quick-settings .icon-button
const menuRadius = 8 * 3;                      // .quick-toggle-menu radius
const menuMargin = basePadding * 2;            // .quick-toggle-menu margin-top
const menuButtonPadH = basePadding * 1.75;     // .quick-toggle-menu-button
const sliderHandle = iconSize;                 // -slider-handle-radius × 2
const sliderTrough = 4;                        // -barlevel-height
const titlePt = 11;                            // %heading (bold)
const captionPt = 9;                           // %caption

function rgba(hex, a) {
    const c = Qt.color(hex);
    return Qt.rgba(c.r, c.g, c.b, a);
}

// dark: $bg_color #36363a, $fg_color #fff; light: #fafafb / #222226.
// Button = st-mix(fg, bg, 9% dark | 12% light); hover/active ±4%/9%.
function palette(dark, accent) {
    accent = accent || gnomeAccent;
    const a = Qt.color(accent);
    const mix = (c1, c2, w) => Qt.rgba(c1.r * w + c2.r * (1 - w), c1.g * w + c2.g * (1 - w), c1.b * w + c2.b * (1 - w), 1);
    const white = Qt.color("#ffffff");
    if (dark) {
        const fg = Qt.color("#ffffff");
        return {
            dark: true, accent: a, accentFg: white, fg: fg,
            sheetBg: Qt.color("#36363a"), sheetBorder: Qt.color("#434347"),
            button: Qt.color("#48484c"), buttonHover: Qt.color("#525256"), buttonActive: Qt.color("#5e5e62"),
            card: Qt.color("#48484c"),                       // lighten($bg_color, 7%)
            itemHover: rgba("#ffffff", 0.10),
            menuButton: Qt.color("#4a4a4e"),                 // lighten($bg_color, 8%)
            menuButtonChecked: mix(a, fg, 0.85),
            separator: rgba("#ffffff", 0.25),                // transparentize($fg, .75)
            separatorChecked: mix(white, a, 0.30),
            menuSeparator: rgba("#ffffff", 0.12),
            headerIcon: rgba("#ffffff", 0.20),
            trough: rgba("#ffffff", 0.10),
            handle: Qt.color("#e8e8e8")                      // darken($fg, 9%)
        };
    }
    const fg = Qt.color("#222226");
    return {
        dark: false, accent: a, accentFg: white, fg: fg,
        sheetBg: Qt.color("#fafafb"), sheetBorder: Qt.color("#e8e8ea"),
        button: Qt.color("#e0e0e1"), buttonHover: Qt.color("#d6d6d7"), buttonActive: Qt.color("#c9c9cb"),
        card: Qt.color("#ffffff"),                           // $card_bg_color
        itemHover: rgba("#222226", 0.08),
        menuButton: Qt.color("#ededee"),                     // darken($bg_color, 5%)
        menuButtonChecked: mix(a, fg, 0.92),
        separator: rgba("#222226", 0.25),
        separatorChecked: mix(white, a, 0.20),
        menuSeparator: rgba("#222226", 0.12),
        headerIcon: rgba("#222226", 0.20),
        trough: rgba("#222226", 0.10),
        handle: fg
    };
}

// lightness of a colour (0..1), to follow the Plasma theme
function isDark(color) {
    const c = Qt.color(color);
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5;
}
