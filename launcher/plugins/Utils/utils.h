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

#ifndef UTILS_H
#define UTILS_H

#include <QObject>
#include <QByteArray>
#include <QProcess>
#include <QThread>

class Utils: public QObject {
    Q_OBJECT

    Q_PROPERTY(QStringList games READ games NOTIFY gamesChanged)

public:
    Utils();
    ~Utils() = default;

    Q_INVOKABLE void startGame(const QString& gameName);
    Q_INVOKABLE void hostMultiplayerGame(const QString& gameName, const QString& gameMode);
    Q_INVOKABLE void joinMultiplayerGame(const QString& gameName, const QString& serverAddress, const QString& playerName);
    Q_INVOKABLE void deleteGame(const QString& gameName);
    Q_INVOKABLE void copyGameFiles(const QString& directory);
    Q_INVOKABLE void refreshGames();
    Q_INVOKABLE void unpackDemo(const QString& path);

private:
    QStringList games();

    void runGame(const QString& gameName, char ** args);

    void unpack();

    QProcess m_unzipProcess;

signals:
    void gamesChanged();
    void unpackSucceeded();
    void unpackFailed();
};

#endif
