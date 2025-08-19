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
}

void KCastBridge::resumeMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("play_toggle"));
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt play_toggle");
    }
}

void KCastBridge::stopMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("stop"));
    if (!ok) {
        qWarning() << QString::fromUtf8("Failed to start catt stop");
    }
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