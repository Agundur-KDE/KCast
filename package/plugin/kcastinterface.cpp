#include "kcastinterface.h"
#include <QDebug>
#include <QProcess>
#include <QString>
#include <QStringList>

KCastBridge::KCastBridge(QObject *parent)
    : QObject(parent)
{
}

QStringList KCastBridge::scanDevicesWithCatt()
{
    QProcess process;
    process.start(QStringLiteral("catt"), QStringList() << QStringLiteral("scan"));
    if (!process.waitForFinished(5000)) {
        qWarning() << "❌ catt process did not finish in time";
        return {};
    }

    QString output = QString::fromUtf8(process.readAllStandardOutput());
    if (output.trimmed().isEmpty()) {
        qWarning() << "⚠ catt returned empty output";
        return {};
    }
    QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    QStringList result;

    for (const QString &line : lines) {
        if (line.contains(QStringLiteral("|"))) {
            QString name = line.section(QStringLiteral("|"), 0, 0).trimmed();
            result << name;
        }
    }

    return result;
}
