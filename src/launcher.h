// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QQmlEngine>

/**
 * Starts applications detached from the calling process (KWin), so they are
 * not children of the compositor. Prefers `kstart --application <id>`, which
 * goes through KIO's ApplicationLauncherJob and puts the app in its own
 * systemd scope; falls back to gtk-launch, then gio launch.
 */
class KGnomeLauncher : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Launcher)
    QML_SINGLETON

public:
    explicit KGnomeLauncher(QObject *parent = nullptr);

    Q_INVOKABLE static bool launch(const QString &storageId);
    Q_INVOKABLE static QString moduleVersion();
    /// Resolve an icon name to a file path (empty if not found), for async Image loading.
    Q_INVOKABLE static QString iconPath(const QString &iconName);
};
