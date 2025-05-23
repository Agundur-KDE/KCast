#pragma once

#include <QDBusInterface>
#include <QObject>
#include <QQmlEngine>
#include <QStringList>

class KCastBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit KCastBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList deviceList();
    Q_INVOKABLE void setSelectedDeviceIndex(int index);
    Q_INVOKABLE void play(const QString &url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void resume();

private:
    QDBusInterface *iface = nullptr;
    int selectedIndex = 0;
};
