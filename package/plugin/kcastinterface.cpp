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
    // static QFile logFile(QDir::homePath() + QStringLiteral("/.local/share/kcast.log"));
    // if (!logFile.isOpen()) {
    //     logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    // }

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
    qInstallMessageHandler(customMessageHandler);
}

void KCastBridge::playMedia(const QString &device, const QString &url)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("cast") << url);
    if (!ok) {
        qWarning() << QString::fromUtf8("❌ Failed to start catt cast");
    }
}

void KCastBridge::pauseMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("pause"));
    if (!ok) {
        qWarning() << QString::fromUtf8("❌ Failed to start catt pause");
    }
}

void KCastBridge::resumeMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("play_toggle"));
    if (!ok) {
        qWarning() << QString::fromUtf8("❌ Failed to start catt play_toggle");
    }
}

void KCastBridge::stopMedia(const QString &device)
{
    bool ok = QProcess::startDetached(QString::fromUtf8("catt"), QStringList() << QString::fromUtf8("-d") << device << QString::fromUtf8("stop"));
    if (!ok) {
        qWarning() << QString::fromUtf8("❌ Failed to start catt stop");
    }
}

bool KCastBridge::isCattInstalled() const
{
    // QStandardPaths::findExecutable sucht in den PATH-Umgebungsvariablen
    // und gibt den absoluten Pfad zurück, oder einen leeren QString, wenn es nicht gefunden wurde.
    QString exePath = QStandardPaths::findExecutable(QLatin1String("catt"));
    if (exePath.isEmpty()) {
        qWarning() << QStringLiteral("⚠ catt nicht gefunden (findExecutable liefert leerer String)");
        return false;
    } else {
        qDebug() << QStringLiteral("✅ catt gefunden unter:") << exePath;
        return true;
    }
}

QStringList KCastBridge::scanDevicesWithCatt()
{
    QStringList devices;
    QProcess process;
    process.setProgram(QLatin1String("catt"));
    process.setArguments(QStringList() << QLatin1String("scan"));

    process.start();
    if (!process.waitForStarted(3000)) {
        qWarning() << "❌ catt process did not start properly" << devices;
        return devices;
    }

    if (!process.waitForFinished(8000)) {
        qWarning() << "❌ catt process did not finish in time" << devices;
        return devices;
    }

    QString output = QString::fromUtf8(process.readAllStandardOutput());
    qDebug() << "📥 catt output:" << output;

    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        if (line.contains(QLatin1Char('-'))) {
            QString name = line.section(QLatin1Char('-'), 1, 1).trimmed();
            devices << name;
        }
    }

    qDebug() << "📡 Gefundene Geräte:" << devices;
    return devices;
}
