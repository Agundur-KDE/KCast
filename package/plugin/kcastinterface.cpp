/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

#include "kcastinterface.h"
#include <QDBusConnection>
#include <QDBusError>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QString>
#include <QStringList>
#include <QStringLiteral>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <algorithm>

using namespace Qt::StringLiterals;

void customMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    static QFile logFile(QDir::homePath() + QStringLiteral("/.local/share/kcast.log"));
    if (!logFile.isOpen()) {
        logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    }

    QTextStream out(&logFile);

    QString prefix;
    switch (type) {
    case QtDebugMsg:
        prefix = QStringLiteral("[DEBUG]");
        break;
    case QtWarningMsg:
        prefix = QStringLiteral("[WARN] ");
        break;
    case QtCriticalMsg:
        prefix = QStringLiteral("[CRIT] ");
        break;
    case QtFatalMsg:
        prefix = QStringLiteral("[FATAL]");
        break;
    case QtInfoMsg:
        prefix = QStringLiteral("[INFO] ");
        break;
    }

    out << QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd hh:mm:ss.zzz")) << " " << prefix << " " << msg << '\n';
    out.flush();
}

KCastBridge::KCastBridge(QObject *parent)
    : QObject(parent)
{
    // qInstallMessageHandler(customMessageHandler);

    // kurze Bündel-Zeit: UI darf „ausrauschen“, dann 1x senden
    m_coalesceTimer.setSingleShot(true);
    m_coalesceTimer.setInterval(90); // 80–120 ms fühlt sich snappy an
    connect(&m_coalesceTimer, &QTimer::timeout, this, &KCastBridge::flushVolumeDesired);

    // Mindestabstand zwischen zwei catt-Spawns (Python-Interpreter-Overhead!)
    m_rateLimitTimer.setSingleShot(true);
    m_rateLimitTimer.setInterval(100);
}

void KCastBridge::playMedia(const QString &device, const QString &url)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("cast") << url);
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt cast");
    }
}

void KCastBridge::pauseMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("pause"));
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt pause");
    }
    setPlaying(false);
}

void KCastBridge::resumeMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("play_toggle"));
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt play_toggle");
    }
    setPlaying(false);
}

void KCastBridge::stopMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("stop"));
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt stop");
    }
    setPlaying(false);
}

bool KCastBridge::isCattInstalled() const
{
    // QStandardPaths::findExecutable sucht in den PATH-Umgebungsvariablen
    // und gibt den absoluten Pfad zurück, oder einen leeren QString, wenn es nicht gefunden wurde.
    QString exePath = QStandardPaths::findExecutable(QLatin1String("catt"));
    if (exePath.isEmpty()) {
        qWarning() << QStringLiteral("catt executable not found)");
        return false;
    } else {
        qDebug() << QStringLiteral("catt found:") << exePath;
        return true;
    }
}

void KCastBridge::scanDevicesAsync()
{
    auto *p = new QProcess(this);
    p->setProgram(u"catt"_s);
    p->setArguments({u"scan"_s});
    p->setProcessChannelMode(QProcess::MergedChannels);

    auto *buf = new QString; // Zeilenpuffer
    auto *acc = new QStringList; // gesammelte Namen

    connect(p, &QProcess::readyReadStandardOutput, this, [this, p, acc, buf]() {
        *buf += QString::fromUtf8(p->readAllStandardOutput());

        int nl = -1;
        while ((nl = buf->indexOf(u'\n')) >= 0) { // <-- FIX: QChar, kein _s
            const QString line = buf->left(nl);
            buf->remove(0, nl + 1);

            const auto parts = line.split(u" - "_s);
            if (parts.size() >= 2) {
                const QString name = parts.at(1).trimmed();
                if (!name.isEmpty() && !acc->contains(name)) {
                    acc->append(name);
                    Q_EMIT deviceFound(name); // live ans UI
                    // optional zusätzlich: Q_EMIT devicesScanned(*acc);
                }
            }
        }
    });

    connect(p, &QProcess::finished, this, [this, p, acc, buf](int, QProcess::ExitStatus) {
        // letzte (nicht terminierte) Zeile noch verarbeiten
        if (!buf->isEmpty()) {
            const QString line = *buf;
            const auto parts = line.split(u" - "_s);
            if (parts.size() >= 2) {
                const QString name = parts.at(1).trimmed();
                if (!name.isEmpty() && !acc->contains(name)) {
                    acc->append(name);
                    Q_EMIT deviceFound(name); // optional
                }
            }
        }

        Q_EMIT devicesScanned(*acc); // final komplette Liste
        delete buf;
        delete acc;
        p->deleteLater();
    });

    p->start();
}

static QString toLocalMediaPath(const QString &in)
{
    const QUrl u(in);
    if (u.isLocalFile() || in.startsWith(u"file://"_s))
        return u.toLocalFile();
    return in;
}

void KCastBridge::probeReceiver(const QString &assetUrl)
{
    const QString dev = pickDefaultDevice();
    if (dev.isEmpty())
        return;

    // 1) Prefer: expliziten Pfad/URL aus QML verwenden (funktioniert im Dev-Tree)
    QString asset = assetUrl;

    // 2) Fallback: im installierten System suchen
    if (asset.isEmpty()) {
        asset = QStandardPaths::locate(QStandardPaths::GenericDataLocation, u"plasma/plasmoids/de.agundur.kcast/contents/ui/250-milliseconds-of-silence.mp3"_s);
        if (asset.isEmpty())
            return; // kein Outbound, einfach aufgeben
    }

    const QString local = toLocalMediaPath(asset);

    QProcess::startDetached(u"catt"_s, {u"-d"_s, dev, u"stop"_s});
    QProcess::startDetached(u"catt"_s, {u"-d"_s, dev, u"quit"_s});

    QTimer::singleShot(350, this, [dev, local]() {
        auto *p = new QProcess();
        p->setProgram(u"catt"_s);
        p->setArguments({u"-d"_s, dev, u"cast"_s, local});
        p->setProcessChannelMode(QProcess::MergedChannels);
        QObject::connect(p, &QProcess::finished, p, [dev, p] {
            const QString out = QString::fromUtf8(p->readAll());
            p->deleteLater();
            QProcess::startDetached(u"catt"_s, {u"-d"_s, dev, u"quit"_s});
            // Optional: out auf CC1AD845 prüfen und ein Signal emittieren
        });
        p->start();
    });
}

// ---- DBUS Helper ----

bool KCastBridge::registerDBus()
{
    auto bus = QDBusConnection::sessionBus();

    const bool okObj = bus.registerObject(u"/de/agundur/kcast"_s, this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals);
    if (!okObj) {
        qWarning() << "[KCast] DBus: registerObject failed:" << bus.lastError().message();
        setDbusReady(false);
        // Retry – manchmal ist der Bus/Objektbaum noch nicht so weit
        scheduleDbusRetry();
        return false;
    }

    if (!bus.registerService(u"de.agundur.kcast"_s)) {
        // Kann beim Plasma-Start vorkommen (Race mit zweiter Instanz / Bus init)
        qWarning() << "[KCast] DBus: registerService failed:" << bus.lastError().message();
        setDbusReady(false);
        scheduleDbusRetry();
        return false;
    }

    qInfo() << "[KCast] DBus ready on de.agundur.kcast /de/agundur/kcast";
    setDbusReady(true);
    return true;
}

void KCastBridge::setMediaUrl(const QString &url)
{
    if (m_mediaUrl == url)
        return;
    m_mediaUrl = url;
    Q_EMIT mediaUrlChanged();
}

QString KCastBridge::pickDefaultDevice() const
{
    if (!m_defaultDevice.isEmpty())
        return m_defaultDevice;

    qWarning() << u"[KCast] No default device set – refusing to scan on UI path."_s;
    return {};
}

QString KCastBridge::normalizeUrlForCasting(const QString &in) const
{
    QUrl u = QUrl::fromUserInput(in);
    if (u.isLocalFile()) {
        return u.toLocalFile(); // kein file:// → vermeidet yt-dlp-Block
    }
    if (u.isRelative() && QFileInfo(in).exists()) {
        return QFileInfo(in).absoluteFilePath();
    }
    return u.toString(); // http/https o.ä.
}

// ---- QML-Setter ----
void KCastBridge::setDefaultDevice(const QString &device)
{
    m_defaultDevice = device;
    qInfo() << u"[KCast] Default device set to:"_s << m_defaultDevice;
}

// ---- D-Bus Slots ----
void KCastBridge::CastFile(const QString &url)
{
    const QString device = pickDefaultDevice();
    if (device.isEmpty()) {
        qWarning() << u"[KCast] No device available for CastFile"_s;
        return;
    }
    const QString norm = normalizeUrlForCasting(url);

    // GUI synchronisieren:
    setMediaUrl(norm);
    setPlaying(true);

    qInfo() << u"[KCast] CastFile →"_s << device << norm;
    playMedia(device, norm);
}

void KCastBridge::CastFiles(const QStringList &urls)
{
    const QString device = pickDefaultDevice();
    if (device.isEmpty()) {
        qWarning() << u"[KCast] No device available for CastFiles"_s;
        return;
    }
    bool first = true;
    for (const QString &u : urls) {
        const QString norm = normalizeUrlForCasting(u);
        if (first) {
            setMediaUrl(norm);
            setPlaying(true);
            first = false;
        } // ← AN
        playMedia(device, norm);
    }
}

void KCastBridge::scheduleDbusRetry()
{
    static int tries = 0;
    if (tries >= 5)
        return;
    ++tries;

    QTimer::singleShot(1000, this, [this]() {
        qInfo() << "[KCast] DBus retry…";
        registerDBus();
    });
}

// ---- Volume ----

bool KCastBridge::setVolume(int level)
{
    level = clampVolume(level);
    requestVolumeAbsolute(level);
    Q_EMIT volumeCommandSent(u"set"_s, level); // UI darf sofort hochzählen
    return true;
}

bool KCastBridge::volumeUp(int delta)
{
    if (delta <= 0)
        delta = 5;
    const int base = m_desiredVolume.has_value() ? *m_desiredVolume : (m_lastSentVolume >= 0 ? m_lastSentVolume : 50);
    return setVolume(base + delta);
}

bool KCastBridge::volumeDown(int delta)
{
    if (delta <= 0)
        delta = 5;
    const int base = m_desiredVolume.has_value() ? *m_desiredVolume : (m_lastSentVolume >= 0 ? m_lastSentVolume : 50);
    return setVolume(base - delta);
}

bool KCastBridge::setMuted(bool on)
{
    const bool ok = spawnCattMute(on);
    if (!ok) {
        qWarning() << u"[KCast] Failed to start catt volumemute."_s;
        return false;
    }
    Q_EMIT muteCommandSent(on);
    return true;
}

// ---- Coalescer ----

void KCastBridge::requestVolumeAbsolute(int level)
{
    m_desiredVolume = clampVolume(level);
    // jeder neue Wunsch startet die Bündelung neu (last-wins)
    m_coalesceTimer.start();
}

void KCastBridge::flushVolumeDesired()
{
    if (!m_desiredVolume.has_value())
        return;

    // Rate-Limit noch aktiv? Danach erneut versuchen.
    if (m_rateLimitTimer.isActive()) {
        m_coalesceTimer.start(m_rateLimitTimer.remainingTime() + 10);
        return;
    }

    const int target = clampVolume(*m_desiredVolume);

    if (m_lastSentVolume == target) {
        m_desiredVolume.reset();
        return; // schon dort
    }

    const bool ok = spawnCattSetVolume(target);
    if (!ok) {
        qWarning() << u"[KCast] Failed to start catt volume."_s;
        // nicht aufgeben – in 200 ms nochmal probieren
        m_coalesceTimer.start(200);
        return;
    }

    m_lastSentVolume = target;
    m_desiredVolume.reset();
    m_rateLimitTimer.start();

    // falls während des Spawns neue Wünsche kamen, direkt wieder bündeln
    if (m_desiredVolume.has_value())
        m_coalesceTimer.start();
}

// ---- Helpers: tatsächlich catt starten (absolut!) ----

bool KCastBridge::spawnCattSetVolume(int level)
{
    const QString device = pickDefaultDevice();
    if (device.isEmpty()) {
        qWarning() << u"[KCast] setVolume: default device not set."_s;
        return false; // NICHT scannen!
    }
    const QStringList args{u"-d"_s, device, u"volume"_s, QString::number(level)};
    return QProcess::startDetached(u"catt"_s, args);
}

bool KCastBridge::spawnCattMute(bool on)
{
    const QString device = pickDefaultDevice();
    if (device.isEmpty()) {
        qWarning() << u"[KCast] setMuted: no Chromecast device available."_s;
        return false;
    }
    const QStringList args{u"-d"_s, device, u"volumemute"_s, on ? u"true"_s : u"false"_s};
    return QProcess::startDetached(u"catt"_s, args);
}
