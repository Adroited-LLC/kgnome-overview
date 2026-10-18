// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "iconresolver.h"

#include <KConfig>
#include <KConfigGroup>

#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>

namespace
{
struct ThemeDir {
    QString path; // absolute
    int size = 0;
    bool scalable = false;
};

QHash<QString, QString> s_cache;
QVector<ThemeDir> s_dirs;
QStringList s_pixmapDirs;
bool s_initialized = false;

QStringList iconBaseDirs()
{
    QStringList bases;
    bases << QDir::homePath() + QStringLiteral("/.icons");
    const QStringList dataDirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("icons"), QStandardPaths::LocateDirectory);
    for (const QString &d : dataDirs) {
        if (!bases.contains(d)) {
            bases << d;
        }
    }
    return bases;
}

void addTheme(const QString &theme, const QStringList &bases, QStringList &visited, QVector<ThemeDir> &out)
{
    if (theme.isEmpty() || visited.contains(theme)) {
        return;
    }
    visited << theme;

    QStringList parents;
    QVector<ThemeDir> dirs;
    for (const QString &base : bases) {
        const QString themeDir = base + QLatin1Char('/') + theme;
        const QString index = themeDir + QStringLiteral("/index.theme");
        if (!QFileInfo::exists(index)) {
            continue;
        }
        QSettings ini(index, QSettings::IniFormat);
        ini.beginGroup(QStringLiteral("Icon Theme"));
        if (parents.isEmpty()) {
            parents = ini.value(QStringLiteral("Inherits")).toStringList();
        }
        QStringList subdirs = ini.value(QStringLiteral("Directories")).toStringList();
        subdirs += ini.value(QStringLiteral("ScaledDirectories")).toStringList();
        ini.endGroup();
        for (const QString &sub : std::as_const(subdirs)) {
            ini.beginGroup(sub);
            const QString context = ini.value(QStringLiteral("Context")).toString();
            const int scale = ini.value(QStringLiteral("Scale"), 1).toInt();
            if ((context == QLatin1String("Applications") || sub.contains(QLatin1String("apps"))) && scale == 1) {
                ThemeDir td;
                td.path = themeDir + QLatin1Char('/') + sub;
                td.size = ini.value(QStringLiteral("Size"), 0).toInt();
                td.scalable = ini.value(QStringLiteral("Type")).toString() == QLatin1String("Scalable");
                if (QFileInfo(td.path).isDir()) {
                    dirs << td;
                }
            }
            ini.endGroup();
        }
    }
    // Scalable first, then bigger fixed sizes first.
    std::stable_sort(dirs.begin(), dirs.end(), [](const ThemeDir &a, const ThemeDir &b) {
        if (a.scalable != b.scalable) {
            return a.scalable;
        }
        return a.size > b.size;
    });
    out += dirs;
    for (const QString &p : std::as_const(parents)) {
        addTheme(p, bases, visited, out);
    }
}

void init()
{
    if (s_initialized) {
        return;
    }
    s_initialized = true;
    KConfig globals(QStringLiteral("kdeglobals"));
    const QString theme = globals.group(QStringLiteral("Icons")).readEntry("Theme", QStringLiteral("breeze"));
    const QStringList bases = iconBaseDirs();
    QStringList visited;
    addTheme(theme, bases, visited, s_dirs);
    addTheme(QStringLiteral("breeze"), bases, visited, s_dirs);
    addTheme(QStringLiteral("hicolor"), bases, visited, s_dirs);
    s_pixmapDirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("pixmaps"), QStandardPaths::LocateDirectory);
}
}

QString IconResolver::resolve(const QString &iconName)
{
    if (iconName.isEmpty()) {
        return {};
    }
    if (QDir::isAbsolutePath(iconName)) {
        return QFileInfo::exists(iconName) ? iconName : QString();
    }
    auto it = s_cache.constFind(iconName);
    if (it != s_cache.constEnd()) {
        return *it;
    }
    init();
    static const QStringList exts = {QStringLiteral(".svg"), QStringLiteral(".png"), QStringLiteral(".svgz")};
    QString found;
    for (const ThemeDir &d : std::as_const(s_dirs)) {
        for (const QString &ext : exts) {
            const QString candidate = d.path + QLatin1Char('/') + iconName + ext;
            if (QFileInfo::exists(candidate)) {
                found = candidate;
                break;
            }
        }
        if (!found.isEmpty()) {
            break;
        }
    }
    if (found.isEmpty()) {
        for (const QString &d : std::as_const(s_pixmapDirs)) {
            for (const QString &ext : {QStringLiteral(".svg"), QStringLiteral(".png")}) {
                const QString candidate = d + QLatin1Char('/') + iconName + ext;
                if (QFileInfo::exists(candidate)) {
                    found = candidate;
                    break;
                }
            }
            if (!found.isEmpty()) {
                break;
            }
        }
    }
    s_cache.insert(iconName, found);
    return found;
}

void IconResolver::clearCache()
{
    s_cache.clear();
    s_dirs.clear();
    s_pixmapDirs.clear();
    s_initialized = false;
}
