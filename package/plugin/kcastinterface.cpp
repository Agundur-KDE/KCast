#include "kcastinterface.h"
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
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
    qInstallMessageHandler(customMessageHandler);
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
