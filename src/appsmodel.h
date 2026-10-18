// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QStringList>
#include <QVector>

class KDirWatch;

/**
 * Alphabetical list of the visible desktop applications (KApplicationTrader),
 * refreshed whenever the KSycoca database changes.
 *
 * With favoritesOnly: true it instead lists Plasma's application launcher
 * favourites (kactivitymanagerd-statsrc ordering), or favoriteIds if set,
 * or a set of sensible defaults.
 */
class KGnomeAppsModel : public QAbstractListModel
{
    Q_OBJECT
    QML_NAMED_ELEMENT(AppsModel)

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool favoritesOnly READ favoritesOnly WRITE setFavoritesOnly NOTIFY favoritesOnlyChanged)
    Q_PROPERTY(QStringList favoriteIds READ favoriteIds WRITE setFavoriteIds NOTIFY favoriteIdsChanged)
    Q_PROPERTY(QString filterString READ filterString WRITE setFilterString NOTIFY filterStringChanged)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconNameRole,
        StorageIdRole,
        GenericNameRole,
        CommentRole,
        KeywordsRole,
        EntryPathRole,
        IconPathRole,
    };
    Q_ENUM(Roles)

    explicit KGnomeAppsModel(QObject *parent = nullptr);
    ~KGnomeAppsModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_visible.size()); }
    bool favoritesOnly() const { return m_favoritesOnly; }
    void setFavoritesOnly(bool on);
    QStringList favoriteIds() const { return m_favoriteIds; }
    void setFavoriteIds(const QStringList &ids);
    QString filterString() const { return m_filter; }
    void setFilterString(const QString &filter);
    int limit() const { return m_limit; }
    void setLimit(int limit);

    Q_INVOKABLE bool launch(const QString &storageId) const;
    Q_INVOKABLE bool launchRow(int row) const;
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();
    void favoritesOnlyChanged();
    void favoriteIdsChanged();
    void filterStringChanged();
    void limitChanged();

private:
    struct Entry {
        QString name;
        QString iconName;
        QString storageId;
        QString genericName;
        QString comment;
        QString keywords;
        QString entryPath;
        QString iconPath;
    };

    void reload();
    void applyFilter();
    QStringList plasmaFavorites() const;
    static bool entryFromId(const QString &id, Entry &out);

    QVector<Entry> m_all;
    QVector<int> m_visible;
    bool m_favoritesOnly = false;
    QStringList m_favoriteIds;
    QString m_filter;
    int m_limit = -1;
    KDirWatch *m_watch = nullptr;
};
