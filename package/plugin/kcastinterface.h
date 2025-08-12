#ifndef KCASTINTERFACE_H
#define KCASTINTERFACE_H

#include <QObject>
#include <QQmlEngine>
#include <QStringList>

class KCastBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_CLASSINFO("D-Bus Interface", "de.agundur.kcast")

public:
    explicit KCastBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList scanDevicesWithCatt();
    Q_INVOKABLE void playMedia(const QString &device, const QString &url);
    Q_INVOKABLE void pauseMedia(const QString &device);
    Q_INVOKABLE void resumeMedia(const QString &device);
    Q_INVOKABLE void stopMedia(const QString &device);
    Q_INVOKABLE bool isCattInstalled() const;

    Q_INVOKABLE void setDefaultDevice(const QString &device);

public Q_SLOTS: // —> per D-Bus aufrufbar
    void CastFile(const QString &url);
    void CastFiles(const QStringList &urls);

private:
    QString m_defaultDevice;
    QString pickDefaultDevice() const;
    QString normalizeUrlForCasting(const QString &in) const;
};

#endif // KCASTINTERFACE_H
