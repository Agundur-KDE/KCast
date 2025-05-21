#include "kcastinterface.h"

#include <QDBusReply>
#include <QDebug>
#include <QVariant>
#include <QVariantList>

KCastBridge::KCastBridge(QObject *parent)
    : QObject(parent)
{
    iface = new QDBusInterface(QStringLiteral("org.kcast.Controller"),
                               QStringLiteral("/org/kcast/Player"),
                               QStringLiteral("org.kcast.Player"),
                               QDBusConnection::sessionBus(),
                               this);

    if (!iface->isValid()) {
        qWarning() << "❌ QDBusInterface connection failed:" << iface->lastError().message();
    }
}

QStringList KCastBridge::deviceList()
{
    QDBusReply<QList<QVariant>> reply = iface->call(QStringLiteral("listDevices"));

    QStringList names;

    if (reply.isValid()) {
        for (const QVariant &item : reply.value()) {
            const QVariantList pair = item.toList(); // (name, ip)
            if (!pair.isEmpty()) {
                names << pair[0].toString();
            }
        }
    } else {
        qWarning() << "❌ D-Bus call failed: " << reply.error().message();
    }

    return names;
}

void KCastBridge::setSelectedDeviceIndex(int index)
{
    selectedIndex = index;
    iface->call(QStringLiteral("setSelectedDeviceIndex"), QVariant::fromValue(index));
}

void KCastBridge::play(const QString &url)
{
    iface->call(QStringLiteral("play"), QVariant::fromValue(url));
}

void KCastBridge::pause()
{
    iface->call(QStringLiteral("pause"));
}

void KCastBridge::stop()
{
    iface->call(QStringLiteral("stop"));
}
