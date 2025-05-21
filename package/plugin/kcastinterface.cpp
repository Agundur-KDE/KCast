#include "kcastplugin.h"

#include <QDBusConnection>
#include <QDBusReply>
#include <QDebug>

KCastBridge::KCastBridge(QObject* parent)
    : QObject(parent)
{
    iface = new QDBusInterface(
        "org.kcast.Controller",
        "/org/kcast/Player",
        "org.kcast.Player",
        QDBusConnection::sessionBus(),
        this);
}

QStringList KCastBridge::deviceList()
{
    QDBusReply<QList<QVariant>> reply = iface->call("listDevices");

    QStringList names;

    if (reply.isValid()) {
        for (const QVariant& item : reply.value()) {
            const auto pair = item.toList(); // (name, ip)
            if (pair.size() > 0)
                names << pair[0].toString();
        }
    } else {
        qWarning() << "DBus error:" << reply.error().message();
    }

    return names;
}

void KCastBridge::setSelectedDeviceIndex(int index)
{
    selectedIndex = index;
    iface->call("setSelectedDeviceIndex", index);
}

void KCastBridge::play(const QString& url)
{
    iface->call("play", url);
}

void KCastBridge::pause()
{
    iface->call("pause");
}

void KCastBridge::stop()
{
    iface->call("stop");
}
