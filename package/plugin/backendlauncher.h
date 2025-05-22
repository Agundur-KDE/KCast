#pragma once

#include <QObject>
#include <QProcess>
#include <QQmlEngine>

class BackendLauncher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit BackendLauncher(QObject *parent = nullptr);

    Q_INVOKABLE void startBackend();

Q_SIGNALS:
    void backendReady();

private:
    QProcess *process;
};
