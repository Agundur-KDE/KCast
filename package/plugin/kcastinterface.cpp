#include "kcastinterface.h"

#include <QDBusArgument>
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
        qWarning() << "Warning:  QDBusInterface connection failed:" << iface->lastError().message();
    }
}

QStringList KCastBridge::deviceList()
{
    QStringList names;

    QDBusMessage reply = iface->call(QStringLiteral("listDevices"));

    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        const QVariant arg = reply.arguments().at(0);
        if (arg.userType() == qMetaTypeId<QDBusArgument>()) {
            const QDBusArgument dbusArg = arg.value<QDBusArgument>();
            dbusArg.beginArray();
            while (!dbusArg.atEnd()) {
                QString name;
                QString ip;
                dbusArg.beginStructure();
                dbusArg >> name >> ip;
                dbusArg.endStructure();
                names << name; // oder names << name + " (" + ip + ")" für Anzeige
            }
            dbusArg.endArray();
        } else {
            qWarning() << "❌ Unexpected D-Bus argument type:" << arg.typeName();
        }
    } else {
        qWarning() << "❌ Invalid or empty D-Bus reply";
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
