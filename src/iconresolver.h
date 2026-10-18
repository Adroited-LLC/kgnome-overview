// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>

/**
 * Minimal freedesktop icon-theme lookup for application icons.
 *
 * Resolves an icon name to a file path (preferring scalable, then the largest
 * fixed size) in the configured Plasma icon theme, its parents and hicolor.
 * The result can be fed to an asynchronous QML Image, so decoding happens off
 * the GUI thread (QIcon itself is not safe to use from loader threads).
 */
namespace IconResolver
{
QString resolve(const QString &iconName);
void clearCache();
}
