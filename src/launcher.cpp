// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcher.h"
#include "iconresolver.h"

#include <KService>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>

KGnomeLauncher::KGnomeLauncher(QObject *parent)
    : QObject(parent)
{
}

QString KGnomeLauncher::iconPath(const QString &iconName)
{
    return IconResolver::resolve(iconName);
}

QString KGnomeLauncher::moduleVersion()
{
    return QStringLiteral("0.1.0");
}

bool KGnomeLauncher::launch(const QString &storageIdIn)
{
    QString storageId = storageIdIn.trimmed();
    if (storageId.startsWith(QLatin1String("applications:"))) {
        storageId = storageId.mid(13);
    }
    if (storageId.isEmpty()) {
        return false;
    }
    QString desktopName = storageId;
    if (desktopName.endsWith(QLatin1String(".desktop"))) {
        desktopName.chop(8);
    }

    const QString kstart = QStandardPaths::findExecutable(QStringLiteral("kstart"));
    if (!kstart.isEmpty()) {
        if (QProcess::startDetached(kstart, {QStringLiteral("--application"), desktopName})) {
            return true;
        }
    }

    const QString gtkLaunch = QStandardPaths::findExecutable(QStringLiteral("gtk-launch"));
    if (!gtkLaunch.isEmpty()) {
        if (QProcess::startDetached(gtkLaunch, {desktopName})) {
            return true;
        }
    }

    const KService::Ptr service = KService::serviceByStorageId(storageId);
    const QString gio = QStandardPaths::findExecutable(QStringLiteral("gio"));
    if (service && !gio.isEmpty()) {
        return QProcess::startDetached(gio, {QStringLiteral("launch"), service->entryPath()});
    }
    qWarning("kgnome-overview: unable to launch %s", qPrintable(storageId));
    return false;
}
