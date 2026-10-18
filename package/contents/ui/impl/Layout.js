// SPDX-License-Identifier: GPL-2.0-or-later
// Geometry helpers and constants ported from GNOME Shell (gnome-50):
// js/ui/overviewControls.js (ControlsManagerLayout), js/ui/iconGrid.js,
// js/ui/workspaceThumbnail.js.
.pragma library

// overviewControls.js
var SMALL_WORKSPACE_RATIO = 0.15;
var DASH_MAX_HEIGHT_RATIO = 0.16;
var VERTICAL_SPACING_RATIO = 0.02;
var THUMBNAILS_SPACING_ADJUSTMENT_TOP = 0.6;
var THUMBNAILS_SPACING_ADJUSTMENT_BOTTOM = 0.4;
var SIDE_CONTROLS_ANIMATION_TIME = 250;

// workspaceThumbnail.js
var MAX_THUMBNAIL_SCALE = 0.05;

// iconGrid.js
var ICON_SIZES = [96, 64, 48, 32, 24, 16]; // IconSize.LARGE ... TINY
var GRID_MODES = [ // rows x columns
    {rows: 8, columns: 3},
    {rows: 6, columns: 4},
    {rows: 4, columns: 6},
    {rows: 3, columns: 8},
];
var PAGE_SWITCH_TIME = 300;

// dash.js
var DASH_ICON_SIZES = [64, 48, 32, 24, 22, 16];

// workspacesView.js
var WORKSPACE_SWITCH_TIME = 250;
var WORKSPACE_MIN_SPACING = 24;
var WORKSPACE_MAX_SPACING = 80;
var WORKSPACE_INACTIVE_SCALE = 0.94;

// workspace.js
var WINDOW_PREVIEW_MAXIMUM_SCALE = 0.95;
var BACKGROUND_CORNER_RADIUS_PIXELS = 30;

// appDisplay.js
var PAGE_PREVIEW_RATIO = 0.20;
var FOLDER_SUBICON_FRACTION = 0.4;
var FOLDER_DIALOG_ANIMATION_TIME = 200;
var APP_FOLDER_SIZE = 720;          // _app-grid.scss $app_folder_size

// pageIndicators.js
var INDICATOR_INACTIVE_OPACITY = 128 / 255;
var INDICATOR_INACTIVE_SCALE = 2 / 3;

// gnome-shell-sass/_colors.scss (dark): system_base_color, system_fg_color,
// system_overlay_bg_color = mix(base, fg, 90%), system_bg_color = lighten(base, 5%)
var SYSTEM_BASE_COLOR = "#222226";
var SYSTEM_FG_COLOR = "#fafafb";
var SYSTEM_OVERLAY_BG_COLOR = "#38383b";
var SYSTEM_BG_COLOR = "#2e2e33";

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

function rect(x, y, w, h) {
    return {x: x, y: y, width: w, height: h};
}

function lerpRect(a, b, t) {
    return rect(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.width, b.width, t), lerp(a.height, b.height, t));
}

// Largest rect with the given aspect ratio (w/h) centred inside r.
function fitAspect(r, aspect) {
    var w = r.width, h = r.height;
    if (w / h > aspect) {
        w = h * aspect;
    } else {
        h = w / aspect;
    }
    return rect(r.x + (r.width - w) / 2, r.y + (r.height - h) / 2, w, h);
}

function inset(r, dx, dy) {
    return rect(r.x + dx, r.y + dy, Math.max(0, r.width - 2 * dx), Math.max(0, r.height - 2 * dy));
}

// ControlsManagerLayout._computeWorkspacesBoxForState
// state: 0 HIDDEN, 1 WINDOW_PICKER, 2 APP_GRID
function workspacesBox(state, m) {
    switch (state) {
    case 0:
        return rect(0, 0, m.width, m.height);
    case 1: {
        var top = Math.round(m.spacing * THUMBNAILS_SPACING_ADJUSTMENT_TOP);
        var bottom = Math.round(m.spacing * THUMBNAILS_SPACING_ADJUSTMENT_BOTTOM) * m.expandFraction;
        var y = m.startY + m.searchHeight + top + m.thumbnailsHeight + bottom;
        var h = m.height - m.dashHeight - m.spacing - m.searchHeight - top - m.thumbnailsHeight - bottom;
        return rect(0, y, m.width, h);
    }
    default:
        return rect(0, m.startY + m.searchHeight + m.spacing, m.width, Math.round(m.height * SMALL_WORKSPACE_RATIO));
    }
}

// ControlsManagerLayout._getAppDisplayBoxForState
function appDisplayBox(state, m) {
    var wsGrid = workspacesBox(2, m);
    var h = m.height - m.searchHeight - m.spacing - wsGrid.height - m.spacing - m.dashHeight - m.spacing;
    if (state === 2) {
        return rect(0, m.startY + m.searchHeight + m.spacing + wsGrid.height + m.spacing, m.width, h);
    }
    return rect(0, m.height, m.width, h);
}

// Search results area (searchController allocation)
function searchBox(m) {
    var available = m.height - m.searchHeight - m.spacing - m.dashHeight - m.spacing;
    return rect(0, m.startY + m.searchHeight + m.spacing, m.width, available);
}

// stateValue in [0, 2] -> interpolated box, like getStateTransitionParams()
function blend(fn, stateValue, m) {
    var from = Math.floor(Math.min(stateValue, 1.999));
    var t = stateValue - from;
    return lerpRect(fn(from, m), fn(from + 1, m), t);
}

// IconGrid._findBestModeForSize
function bestGridMode(width, height) {
    var sizeRatio = width / height;
    var closestRatio = Infinity;
    var best = GRID_MODES[0];
    for (var i = 0; i < GRID_MODES.length; ++i) {
        var mode = GRID_MODES[i];
        var modeRatio = mode.columns / mode.rows;
        if (Math.abs(sizeRatio - modeRatio) < Math.abs(sizeRatio - closestRatio)) {
            closestRatio = modeRatio;
            best = mode;
        }
    }
    return best;
}

// IconGridLayout._findBestIconSize + _calculateSpacing (FILL alignment).
// tileFor(iconSize) returns the square tile size for an icon size.
function gridGeometry(pageWidth, pageHeight, padding, mode, spacing, maxSpacing, iconScale, tileFor) {
    var cols = mode.columns, rows = mode.rows;
    var iconSize = ICON_SIZES[ICON_SIZES.length - 1];
    for (var i = 0; i < ICON_SIZES.length; ++i) {
        var size = Math.round(ICON_SIZES[i] * iconScale);
        var tile = tileFor(size);
        var emptyH = pageWidth - tile * cols - spacing * (cols - 1) - 2 * padding.h;
        var emptyV = pageHeight - tile * rows - spacing * (rows - 1) - 2 * padding.v;
        if (emptyH >= 0 && emptyV > 0) {
            iconSize = size;
            break;
        }
    }
    var tileSize = tileFor(iconSize);
    var emptyHSpace = pageWidth - tileSize * cols - spacing * (cols - 1) - 2 * padding.h;
    var emptyVSpace = pageHeight - tileSize * rows - spacing * (rows - 1) - 2 * padding.v;
    var left = padding.h, top = padding.v;
    var hSpacing = spacing + (cols > 1 ? emptyHSpace / (cols - 1) : 0);
    if (maxSpacing >= 0 && hSpacing > maxSpacing) {
        left += Math.max((emptyHSpace - (maxSpacing - spacing) * (cols - 1)) / 2, 0);
        hSpacing = maxSpacing;
    }
    var vSpacing = spacing + (rows > 1 ? emptyVSpace / (rows - 1) : 0);
    if (maxSpacing >= 0 && vSpacing > maxSpacing) {
        top += Math.max((emptyVSpace - (maxSpacing - spacing) * (rows - 1)) / 2, 0);
        vSpacing = maxSpacing;
    }
    return {
        rows: rows, columns: cols, perPage: rows * cols,
        iconSize: iconSize, tileSize: tileSize,
        left: left, top: top, hSpacing: hSpacing, vSpacing: vSpacing,
    };
}

// WorkspacesView._getSpacing (horizontal layout). fitMode: 0 SINGLE, 1 ALL.
function workspaceSpacing(box, aspect, fitMode, s) {
    var wsWidth = Math.min(box.width, box.height * aspect);
    var available = (box.width - wsWidth) / 2;
    var spacing = (available - wsWidth * 0.4) * (1 - fitMode);
    return clamp(spacing, WORKSPACE_MIN_SPACING * s, WORKSPACE_MAX_SPACING * s);
}

// WorkspacesView._getFirstFitSingleWorkspaceBox: the current workspace
// (fractional index `pos`) centred, the others beside it.
function fitSingleRect(box, aspect, index, pos, s) {
    var spacing = workspaceSpacing(box, aspect, 0, s);
    var w = box.height * aspect, h = box.height;
    if (w > box.width) {
        w = box.width;
        h = w / aspect;
    }
    var x = box.x + (box.width - w) / 2 + (index - pos) * (w + spacing);
    return rect(x, box.y + (box.height - h) / 2, w, h);
}

// WorkspacesView._getFirstFitAllWorkspaceBox: all workspaces side by side,
// with spacing before the first and after the last.
function fitAllRect(box, aspect, index, n, s) {
    var spacing = workspaceSpacing(box, aspect, 1, s);
    var availableWidth = box.width - spacing * (n + 1);
    var w = availableWidth / n;
    var h = w / aspect;
    var x1 = box.x + spacing;
    if (h > box.height) {
        h = box.height;
        w = h * aspect;
        x1 += Math.max((availableWidth - w * n) / 2, 0);
    }
    return rect(x1 + index * (w + spacing), box.y + (box.height - h) / 2, w, h);
}

// scale a rect around its centre
function scaleRect(r, f) {
    var w = r.width * f, h = r.height * f;
    return rect(r.x + (r.width - w) / 2, r.y + (r.height - h) / 2, w, h);
}
