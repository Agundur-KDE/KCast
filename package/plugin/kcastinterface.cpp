/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

#include "kcastinterface.h"
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QString>
#include <QStringList>
#include <QStringLiteral>
#include <QTextStream>

#include <QDBusConnection>
#include <QDBusError>
#include <QFileInfo>
#include <QTimer>
#include <QUrl>

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

QStringList KCastBridge::scanDevicesWithCatt()
{
    using namespace Qt::StringLiterals;

    QStringList devices;
    QProcess process;
    process.setProgram(u"catt"_s);
    process.setArguments({u"scan"_s});
    process.setProcessChannelMode(QProcess::MergedChannels);

    process.start();
    if (!process.waitForStarted(3000)) {
        qWarning() << "[KCast] catt process did not start properly";
        return devices; // leer
    }

    QByteArray buffer;

    auto drainOutput = [&]() {
        buffer += process.readAllStandardOutput();

        int nl = -1;
        while ((nl = buffer.indexOf('\n')) >= 0) {
            const QByteArray lineBa = buffer.left(nl);
            buffer.remove(0, nl + 1);

            const QString line = QString::fromUtf8(lineBa).trimmed();
            if (line.isEmpty())
                continue;
            if (line.startsWith(u"Scanning Chromecasts"_s, Qt::CaseInsensitive))
                continue;

            // Erwartetes Format: "IP - Name - Type"
            const QStringList parts = line.split(u" - "_s);
            if (parts.size() < 2) {
                qWarning() << "[KCast] Unexpected catt output line:" << line;
                continue;
            }

            const QString name = parts.at(1).trimmed();
            if (!devices.contains(name))
                devices.append(name);
        }
    };

    // Bis zu 25s warten; zwischendurch stdout regelmäßig "drainen"
    const qint64 deadlineMs = QDateTime::currentMSecsSinceEpoch() + 25000;

    while (process.state() != QProcess::NotRunning) {
        // Bis zu 200 ms auf neue Daten warten, dann drainen
        process.waitForReadyRead(200);
        drainOutput();

        // Prozess evtl. fertig?
        if (process.state() == QProcess::Running)
            process.waitForFinished(50);

        // Globales Timeout?
        if (QDateTime::currentMSecsSinceEpoch() > deadlineMs) {
            qWarning() << "[KCast] catt scan timed out — returning partial results";
            process.kill();
            break;
        }
    }

    // Rest (evtl. letzte Zeile ohne \n) noch einsammeln
    drainOutput();

    return devices;

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

    // Fallback: nimm das erste gefundene Gerät (pragmatisch, bis die Config angebunden ist)
    const QStringList devs = const_cast<KCastBridge *>(this)->scanDevicesWithCatt();
    if (!devs.isEmpty())
        return devs.first();
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