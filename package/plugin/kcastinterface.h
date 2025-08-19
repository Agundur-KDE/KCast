#ifndef KCASTINTERFACE_H
#define KCASTINTERFACE_H

#include <QByteArray>
#include <QObject>
#include <QProcess>
#include <QQmlEngine>
#include <QSet>
#include <QStringList>
#include <QTimer>

class KCastBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit KCastBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList scanDevicesWithCatt();
    Q_INVOKABLE void playMedia(const QString &device, const QString &url);
    Q_INVOKABLE void pauseMedia(const QString &device);
    Q_INVOKABLE void resumeMedia(const QString &device);
    Q_INVOKABLE void stopMedia(const QString &device);
    Q_INVOKABLE bool isCattInstalled() const;

private:
    QVariantList m_devices;
};

#endif // KCASTINTERFACE_H
