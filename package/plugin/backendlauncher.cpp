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

    QString path = QUrl("file://../code/kcastd.py").toLocalFile();

    if (!QFileInfo::exists(path)) {
        qWarning() << "❌ Backend script not found at:" << path;
        return;
    }

    process->setProgram("python3");
    process->setArguments({path});
    process->setProcessChannelMode(QProcess::MergedChannels);
    process->start();

    connect(process, &QProcess::readyRead, this, [this]() {
        qDebug() << "🪵 Python:" << process->readAll();
    });

    connect(process, &QProcess::errorOccurred, this, [](QProcess::ProcessError err) {
        qWarning() << "❌ Python process error:" << err;
    });
}
