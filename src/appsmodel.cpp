// SPDX-License-Identifier: GPL-2.0-or-later
#include "appsmodel.h"
#include "iconresolver.h"
#include "launcher.h"

#include <KApplicationTrader>
#include <KConfig>
#include <KConfigGroup>
#include <KDirWatch>
#include <KService>
#include <KSycoca>

#include <QCollator>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>

#include <algorithm>

namespace
{
const QStringList s_defaultFavorites = {
    QStringLiteral("org.mozilla.firefox.desktop"),
    QStringLiteral("firefox.desktop"),
    QStringLiteral("org.kde.dolphin.desktop"),
    QStringLiteral("org.kde.konsole.desktop"),
    QStringLiteral("org.kde.kate.desktop"),
    QStringLiteral("org.kde.discover.desktop"),
    QStringLiteral("systemsettings.desktop"),
};

QString statsrcPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kactivitymanagerd-statsrc");
}
}

KGnomeAppsModel::KGnomeAppsModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &KGnomeAppsModel::refresh);
    reload();
}

KGnomeAppsModel::~KGnomeAppsModel() = default;

int KGnomeAppsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_visible.size());
}

QVariant KGnomeAppsModel::data(const QModelIndex &index, int role) const
{
    if (!checkIndex(index, QAbstractItemModel::CheckIndexOption::IndexIsValid)) {
        return {};
    }
    const Entry &e = m_all.at(m_visible.at(index.row()));
    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
        return e.name;
    case Qt::DecorationRole:
    case IconNameRole:
        return e.iconName;
    case StorageIdRole:
        return e.storageId;
    case GenericNameRole:
        return e.genericName;
    case CommentRole:
        return e.comment;
    case KeywordsRole:
        return e.keywords;
    case EntryPathRole:
        return e.entryPath;
    case IconPathRole:
        return e.iconPath;
    }
    return {};
}

QHash<int, QByteArray> KGnomeAppsModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {IconNameRole, "iconName"},
        {StorageIdRole, "storageId"},
        {GenericNameRole, "genericName"},
        {CommentRole, "comment"},
        {KeywordsRole, "keywords"},
        {EntryPathRole, "entryPath"},
        {IconPathRole, "iconPath"},
    };
}

void KGnomeAppsModel::setFavoritesOnly(bool on)
{
    if (m_favoritesOnly == on) {
        return;
    }
    m_favoritesOnly = on;
    if (on && !m_watch) {
        m_watch = new KDirWatch(this);
        m_watch->addFile(statsrcPath());
        auto onChange = [this] {
            QTimer::singleShot(200, this, &KGnomeAppsModel::refresh);
        };
        connect(m_watch, &KDirWatch::dirty, this, onChange);
        connect(m_watch, &KDirWatch::created, this, onChange);
    }
    Q_EMIT favoritesOnlyChanged();
    reload();
}

void KGnomeAppsModel::setFavoriteIds(const QStringList &ids)
{
    if (m_favoriteIds == ids) {
        return;
    }
    m_favoriteIds = ids;
    Q_EMIT favoriteIdsChanged();
    if (m_favoritesOnly) {
        reload();
    }
}

void KGnomeAppsModel::setFilterString(const QString &filter)
{
    if (m_filter == filter) {
        return;
    }
    m_filter = filter;
    Q_EMIT filterStringChanged();
    beginResetModel();
    applyFilter();
    endResetModel();
    Q_EMIT countChanged();
}

void KGnomeAppsModel::setLimit(int limit)
{
    if (m_limit == limit) {
        return;
    }
    m_limit = limit;
    Q_EMIT limitChanged();
    beginResetModel();
    applyFilter();
    endResetModel();
    Q_EMIT countChanged();
}

bool KGnomeAppsModel::launch(const QString &storageId) const
{
    return KGnomeLauncher::launch(storageId);
}

bool KGnomeAppsModel::launchRow(int row) const
{
    if (row < 0 || row >= m_visible.size()) {
        return false;
    }
    return KGnomeLauncher::launch(m_all.at(m_visible.at(row)).storageId);
}

QVariantMap KGnomeAppsModel::get(int row) const
{
    if (row < 0 || row >= m_visible.size()) {
        return {};
    }
    const Entry &e = m_all.at(m_visible.at(row));
    return {
        {QStringLiteral("name"), e.name},
        {QStringLiteral("iconName"), e.iconName},
        {QStringLiteral("iconPath"), e.iconPath},
        {QStringLiteral("storageId"), e.storageId},
        {QStringLiteral("genericName"), e.genericName},
        {QStringLiteral("comment"), e.comment},
    };
}

void KGnomeAppsModel::refresh()
{
    IconResolver::clearCache();
    reload();
}

bool KGnomeAppsModel::entryFromId(const QString &idIn, Entry &out)
{
    QString id = idIn;
    if (id.startsWith(QLatin1String("applications:"))) {
        id = id.mid(13);
    }
    KService::Ptr s = KService::serviceByStorageId(id);
    if (!s || !s->isApplication()) {
        return false;
    }
    out.name = s->name();
    out.iconName = s->icon();
    out.storageId = s->storageId();
    out.genericName = s->genericName();
    out.comment = s->comment();
    out.keywords = s->keywords().join(QLatin1Char(' '));
    out.entryPath = s->entryPath();
    out.iconPath = IconResolver::resolve(out.iconName);
    return true;
}

QStringList KGnomeAppsModel::plasmaFavorites() const
{
    // Find the first Kickoff/Kicker applet so we pick its favourites ordering.
    QStringList instanceIds;
    {
        KConfig applets(QStringLiteral("plasma-org.kde.plasma.desktop-appletsrc"), KConfig::SimpleConfig);
        const auto containments = applets.group(QStringLiteral("Containments"));
        for (const QString &c : containments.groupList()) {
            const auto appletsGroup = containments.group(c).group(QStringLiteral("Applets"));
            for (const QString &a : appletsGroup.groupList()) {
                const QString plugin = appletsGroup.group(a).readEntry("plugin", QString());
                if (plugin == QLatin1String("org.kde.plasma.kickoff") || plugin == QLatin1String("org.kde.plasma.kicker")
                    || plugin == QLatin1String("org.kde.plasma.kickerdash")) {
                    const QString client = plugin == QLatin1String("org.kde.plasma.kickoff") ? QStringLiteral("kickoff") : QStringLiteral("kicker");
                    instanceIds << QStringLiteral("Favorites-org.kde.plasma.%1.favorites.instance-%2-global").arg(client, a);
                }
            }
        }
    }

    KConfig stats(QStringLiteral("kactivitymanagerd-statsrc"), KConfig::SimpleConfig);
    QStringList candidates = instanceIds;
    for (const QString &g : stats.groupList()) {
        if (g.startsWith(QLatin1String("Favorites-")) && g.endsWith(QLatin1String("-global")) && !candidates.contains(g)) {
            candidates << g;
        }
    }
    for (const QString &g : std::as_const(candidates)) {
        const QStringList ordering = stats.group(g).readEntry("ordering", QStringList());
        if (!ordering.isEmpty()) {
            return ordering;
        }
    }
    return {};
}

void KGnomeAppsModel::reload()
{
    QVector<Entry> entries;

    if (m_favoritesOnly) {
        QStringList ids = m_favoriteIds;
        if (ids.isEmpty()) {
            ids = plasmaFavorites();
        }
        if (ids.isEmpty()) {
            ids = s_defaultFavorites;
        }
        QSet<QString> seen;
        for (const QString &id : std::as_const(ids)) {
            Entry e;
            if (entryFromId(id, e) && !seen.contains(e.storageId)) {
                seen.insert(e.storageId);
                entries << e;
            }
        }
    } else {
        const KService::List services = KApplicationTrader::query([](const KService::Ptr &s) {
            return s->isApplication() && !s->noDisplay() && s->showInCurrentDesktop() && s->showOnCurrentPlatform();
        });
        QSet<QString> seen;
        entries.reserve(services.size());
        for (const KService::Ptr &s : services) {
            if (seen.contains(s->storageId())) {
                continue;
            }
            seen.insert(s->storageId());
            Entry e;
            e.name = s->name();
            e.iconName = s->icon();
            e.storageId = s->storageId();
            e.genericName = s->genericName();
            e.comment = s->comment();
            e.keywords = s->keywords().join(QLatin1Char(' '));
            e.entryPath = s->entryPath();
            e.iconPath = IconResolver::resolve(e.iconName);
            entries << e;
        }
        QCollator collator;
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        collator.setNumericMode(true);
        std::sort(entries.begin(), entries.end(), [&collator](const Entry &a, const Entry &b) {
            return collator.compare(a.name, b.name) < 0;
        });
    }

    beginResetModel();
    m_all = entries;
    applyFilter();
    endResetModel();
    Q_EMIT countChanged();
}

void KGnomeAppsModel::applyFilter()
{
    m_visible.clear();
    const QString f = m_filter.trimmed();
    if (f.isEmpty()) {
        for (int i = 0; i < m_all.size(); ++i) {
            m_visible << i;
        }
    } else {
        // GNOME-like ranking: prefix of name > prefix of a word > substring > other fields.
        QVector<QPair<int, int>> scored;
        for (int i = 0; i < m_all.size(); ++i) {
            const Entry &e = m_all.at(i);
            int score = 0;
            if (e.name.startsWith(f, Qt::CaseInsensitive)) {
                score = 4;
            } else if (e.name.contains(QLatin1Char(' ') + f, Qt::CaseInsensitive)) {
                score = 3;
            } else if (e.name.contains(f, Qt::CaseInsensitive)) {
                score = 2;
            } else if (e.genericName.contains(f, Qt::CaseInsensitive) || e.keywords.contains(f, Qt::CaseInsensitive)
                       || e.storageId.contains(f, Qt::CaseInsensitive)) {
                score = 1;
            }
            if (score > 0) {
                scored.append({score, i});
            }
        }
        std::stable_sort(scored.begin(), scored.end(), [](const auto &a, const auto &b) {
            return a.first > b.first;
        });
        for (const auto &p : std::as_const(scored)) {
            m_visible << p.second;
        }
    }
    if (m_limit >= 0 && m_visible.size() > m_limit) {
        m_visible.resize(m_limit);
    }
}
