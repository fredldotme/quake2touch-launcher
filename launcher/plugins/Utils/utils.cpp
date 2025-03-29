/*
 * Copyright (C) 2022  Alfred Neumayer
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2.
 *
 * quake2touch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QGuiApplication>
#include <QStandardPaths>
#include <QTimer>

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include "utils.h"

Utils::Utils() {
    connect(&m_unzipProcess, &QProcess::errorOccurred, this, [=](QProcess::ProcessError error) {
        qDebug() << "unzip error occurred:" << error;
    });

    connect(&m_unzipProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [=](int exitCode, QProcess::ExitStatus exitStatus) {
        qDebug() << "unzip process finished with exit code:" << exitCode;

        if (exitCode != 0) {
            emit unpackFailed();
            return;
        }

        // Move the target file
        const QString cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        const QString appData = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
        const QString oldDir = cache + QStringLiteral("/Install/Data/baseq2");
        const QString newDir = appData + QStringLiteral("/Demo");

        QDir cacheDir(appData);
        cacheDir.mkpath(appData);

        if (rename(oldDir.toUtf8().data(), newDir.toUtf8().data()) == 0) {
            emit unpackSucceeded();
        } else {
            emit unpackFailed();
        }

        refreshGames();
    });
}

void Utils::startGame(const QString& gameName)
{
    char* args[] = {"./bin/quake2-gles2", NULL};
    runGame(gameName, args);
}

void Utils::hostMultiplayerGame(const QString& gameName, const QString& gameMode)
{
    char* mode = strdup(gameMode.toUtf8().data());
    char* args[] = {"./bin/quake2-gles2",
                    "+set", "port", "27910",
                    "+listen",
                    mode, "1",
                    NULL};
    runGame(gameName, args);
}

void Utils::joinMultiplayerGame(const QString& gameName, const QString& serverAddress, const QString& playerName)
{
    char* server = strdup(serverAddress.toUtf8().data());
    char* player = strdup(playerName.toUtf8().data());
    char* args[] = {"./bin/quake2-gles2",
                    "+set", "port", "27910",
                    "+connect", server,
                    "+set", "name", player,
                    NULL};
    runGame(gameName, args);
}

void Utils::runGame(const QString& gameName, char **args)
{
    // Set gamename for the engine to pick up the right .pak files
    setenv("QUAKE2_GAMENAME", gameName.toUtf8().data(), true);

    // Allow Mir connection
    //char* appId = getenv("APP_ID");
    //setenv("DESKTOP_FILE_HINT", appId, true);

    setenv("EGL_PLATFORM", "wayland", true);
    setenv("SDL_VIDEODRIVER", "wayland", true);

    QDirIterator iterator(QStringLiteral("/proc/self/fd"),
                          QStringList(), QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::NoIteratorFlags);
    while (iterator.hasNext()) {
        const auto fdPath = iterator.next();
        const auto crumbs = fdPath.split('/');
        if (crumbs.length() < 1)
            continue;
        const auto fdString = crumbs[crumbs.length() - 1];
        bool ok;
        const int fd = fdString.toInt(&ok, 10);
        if (!ok)
            continue;

        switch (fd) {
        case 0:
        case 1:
        case 2:
            continue;
        default:
            break;
        }

        close(fd);
    }

    QThread::msleep(500);

    execvp(args[0], args);
}

void Utils::deleteGame(const QString& gameName)
{
    const QString gamePath = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) +
            QStringLiteral("/") + gameName;
    QDir dir(gamePath);
    dir.removeRecursively();

    refreshGames();
}

void Utils::copyGameFiles(const QString& directory) {

}

QStringList Utils::games()
{
    QStringList ret;
    QDirIterator iterator(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation),
                          QStringList(), QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::NoIteratorFlags);

    while (iterator.hasNext()) {
        iterator.next();
        ret.push_back(iterator.fileName());
    }

    return ret;
}

void Utils::refreshGames()
{
    emit gamesChanged();
}

void Utils::unpackDemo(const QString& path)
{
    const QString cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    const QString tmpTarget = cache + QStringLiteral("/demo.zip");
    const QString unzipPath =
            QStringLiteral("/opt/click.ubuntu.com/quake2touch.fredldotme/current/lib/aarch64-linux-gnu/bin/unzip");

    QDir cacheDir(cache);
    cacheDir.mkpath(cache);

    qDebug() << "Copying" << path << "to" << tmpTarget;
    rename(path.toUtf8().data(), tmpTarget.toUtf8().data());

    QStringList args;
    args << "-o";
    args << tmpTarget;
    args << "-d";
    args << cache;

    m_unzipProcess.setProgram(unzipPath);
    m_unzipProcess.setArguments(args);
    m_unzipProcess.start();
}

