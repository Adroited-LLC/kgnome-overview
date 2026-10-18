// SPDX-License-Identifier: GPL-2.0-or-later
// Default app folders. GNOME ships "Utilities" and "System" folders
// (js/ui/appDisplay.js DEFAULT_FOLDERS with Config.UTILITIES_FOLDER_APPS /
// SYSTEM_FOLDER_APPS); these are the KDE/Fedora equivalents. Override with
// the AppFolders setting: entries "Name=id1;id2;..." (desktop file ids).
.pragma library

var DEFAULT_FOLDERS = [
    "Utilities=org.kde.ark;org.kde.kcalc;org.kde.kcharselect;org.kde.filelight;org.kde.kfind;"
        + "org.kde.spectacle;org.kde.kwrite;org.kde.kfontview;org.kde.kleopatra;org.kde.kwalletmanager;"
        + "org.kde.klipper;org.kde.kmouth;org.kde.qrca;org.kde.skanpage;org.kde.plasma.emojier;"
        + "org.kde.kdeconnect.app;org.kde.kcolorschemeeditor;org.kde.keditbookmarks;org.kde.kdialog;"
        + "org.gnome.Zenity;org.gnome.Tecla;gtk3-demo;gtk3-icon-browser;gtk3-widget-factory;"
        + "qt6-designer;qt6-linguist;org.kde.kwatchgnupg;org.kde.ktnef;org.kde.plasma-interactiveconsole",
    "System=org.kde.plasma-systemmonitor;org.kde.kinfocenter;org.kde.partitionmanager;"
        + "org.kde.kjournaldbrowser;org.kde.kmenuedit;org.kde.kdebugsettings;org.kde.drkonqi.coredump.gui;"
        + "org.kde.ksystemlog;org.kde.plasma.printqueue;gparted;btrfs-assistant;timeshift-gtk;"
        + "firewall-config;setroubleshoot;system-config-printer;hardinfo2;nvtop;"
        + "io.missioncenter.MissionCenter;io.github.plrigaux.sysd-manager;org.fedoraproject.MediaWriter;"
        + "org.freedesktop.GnomeAbrt;org.gnome.Firmware;im-chooser;org.freedesktop.IBus.Setup;"
        + "org.kde.knetattach;org.kde.kfontinst;nm-connection-editor;org.kde.plasma-welcome;org.kde.khelpcenter",
];

function normalizeId(id) {
    if (!id) {
        return "";
    }
    id = String(id);
    if (id.indexOf("applications:") === 0) {
        id = id.substring(13);
    }
    if (id.length > 8 && id.substring(id.length - 8) === ".desktop") {
        id = id.substring(0, id.length - 8);
    }
    return id;
}

// -> [{name, ids: [id, ...]}] (ordered). An AppFolders list without any
// "Name=" entry (e.g. ["none"]) means "no folders", not "defaults".
function parse(specs) {
    var list = (specs && specs.length > 0) ? specs : DEFAULT_FOLDERS;
    var out = [];
    for (var i = 0; i < list.length; ++i) {
        var eq = list[i].indexOf("=");
        if (eq <= 0) {
            continue;
        }
        var ids = [];
        var parts = list[i].substring(eq + 1).split(";");
        for (var j = 0; j < parts.length; ++j) {
            var id = normalizeId(parts[j].trim());
            if (id.length > 0 && ids.indexOf(id) < 0) {
                ids.push(id);
            }
        }
        out.push({name: list[i].substring(0, eq).trim(), ids: ids});
    }
    return out;
}

function serialize(folders) {
    var out = [];
    for (var i = 0; i < folders.length; ++i) {
        out.push(folders[i].name + "=" + folders[i].ids.join(";"));
    }
    return out.length > 0 ? out : ["none"];
}

function uniqueName(folders, name, ignore) {
    var taken = function (n) {
        for (var i = 0; i < folders.length; ++i) {
            if (folders[i].name === n && folders[i].name !== ignore) {
                return true;
            }
        }
        return false;
    };
    if (!taken(name)) {
        return name;
    }
    for (var k = 2; ; ++k) {
        if (!taken(name + " " + k)) {
            return name + " " + k;
        }
    }
}
