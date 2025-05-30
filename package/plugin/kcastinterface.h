#ifndef KCASTINTERFACE_H
#define KCASTINTERFACE_H

#include <QObject>
#include <QStringList>

class KCastBridge : public QObject
{
    Q_OBJECT
public:
    explicit KCastBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList scanDevicesWithCatt();
};

#endif // KCASTINTERFACE_H
