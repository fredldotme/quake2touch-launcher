#include <QGuiApplication>
#include <QCoreApplication>
#include <QUrl>
#include <QString>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication *app = new QGuiApplication(argc, (char**)argv);
    app->setApplicationName("quake2touch.fredldotme");
    app->setOrganizationName("quake2touch.fredldotme");

    qDebug() << "Starting app from main.cpp";

    QQmlApplicationEngine engine("qrc:/Main.qml");

    return app->exec();
}
