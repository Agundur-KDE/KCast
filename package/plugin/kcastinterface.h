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
    Q_CLASSINFO("D-Bus Interface", "de.agundur.kcast")

    Q_PROPERTY(QString mediaUrl READ mediaUrl WRITE setMediaUrl NOTIFY mediaUrlChanged FINAL)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged FINAL)

public:
    explicit KCastBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList scanDevicesWithCatt();
    Q_INVOKABLE void playMedia(const QString &device, const QString &url);
    Q_INVOKABLE void pauseMedia(const QString &device);
    Q_INVOKABLE void resumeMedia(const QString &device);
    Q_INVOKABLE void stopMedia(const QString &device);
    Q_INVOKABLE bool isCattInstalled() const;
    Q_INVOKABLE void setDefaultDevice(const QString &device);
    Q_INVOKABLE bool registerDBus();
    Q_INVOKABLE void probeReceiver(const QString &assetUrl = QString());
    Q_INVOKABLE bool setVolume(int level); // 0..100
    Q_INVOKABLE bool volumeUp(int delta = 5);
    Q_INVOKABLE bool volumeDown(int delta = 5);
    Q_INVOKABLE bool setMuted(bool on);

    bool dbusReady() const
    {
        return m_dbusReady;
    }
    // Property
    QString mediaUrl() const
    {
        return m_mediaUrl;
    }
    void setMediaUrl(const QString &url);
    bool playing() const
    {
        return m_playing;
    }

public Q_SLOTS: // —> per D-Bus aufrufbar
    void CastFile(const QString &url);
    void CastFiles(const QStringList &urls);

Q_SIGNALS:
    void mediaUrlChanged();
    void playingChanged();
    void dbusReadyChanged();
    void volumeCommandSent(QString command, int value);
    void muteCommandSent(bool muted);

private:
    QString m_defaultDevice;
    QString m_mediaUrl;
    QString pickDefaultDevice() const;
    QString normalizeUrlForCasting(const QString &in) const;
    bool m_playing = false; // ← NEU
    void setPlaying(bool on)
    { // ← NEU
        if (m_playing == on)
            return;
        m_playing = on;
        Q_EMIT playingChanged();
    }

    bool m_dbusReady = false;
    void setDbusReady(bool on)
    {
        if (m_dbusReady == on)
            return;
        m_dbusReady = on;
        Q_EMIT dbusReadyChanged();
    }

    void scheduleDbusRetry();

    QVariantList m_devices;
};

#endif // KCASTINTERFACE_H
