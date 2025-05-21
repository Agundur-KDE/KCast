#pragma once

#include <QDBusInterface>
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

class KCastBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit KCastBridge(QObject* parent = nullptr);

    Q_INVOKABLE QStringList deviceList();
    Q_INVOKABLE void setSelectedDeviceIndex(int index);
    Q_INVOKABLE void play(const QString& url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();

private:
    QDBusInterface* iface;
    int selectedIndex = 0;
};
