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
};

#endif // KCASTINTERFACE_H
