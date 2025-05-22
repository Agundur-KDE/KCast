#include "backendlauncher.h"
#include <QDebug>
#include <QFileInfo>
#include <QUrl>

BackendLauncher::BackendLauncher(QObject *parent)
    : QObject(parent)
{
    process = new QProcess(this);
}

void BackendLauncher::startBackend()
{
    if (process->state() != QProcess::NotRunning) {
        qDebug() << "🔁 Backend already running.";
        return;
    }

    QString path = QStringLiteral("/usr/share/plasma/plasmoids/de.agundur.kcast/contents/code/kcastd.py");

    if (!QFileInfo::exists(path)) {
        qWarning() << "❌ Backend script not found at:" << path;
        return;
    }

    process->setProgram(QStringLiteral("python3"));
    process->setArguments({path});
    process->setProcessChannelMode(QProcess::MergedChannels);
    process->start();

    connect(process, &QProcess::readyRead, this, [this]() {
        const QString output = QString::fromUtf8(process->readAll());
        qDebug() << "🪵 Python:" << process->readAll();

        if (output.contains("org.kcast.Controller", Qt::CaseInsensitive)) {
            emit backendReady();
        }
    });

    connect(process, &QProcess::errorOccurred, this, [](QProcess::ProcessError err) {
        qWarning() << "❌ Python process error:" << err;
    });
}
