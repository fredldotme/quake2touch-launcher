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

import QtQuick 2.7
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Ubuntu.Content 0.1
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0

import Utils 1.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'quake2touch.fredldotme'
    automaticOrientation: false
    anchorToKeyboard: true

    width: units.gu(45)
    height: units.gu(75)

    property string selectedGameName : ""

    Settings {
        id: userSettings
        property string playerName: "Player"
    }

    Item {
        id: gameImportRoot
        property list<ContentItem> importItems
        property var activeTransfer
        property var fileUrls : new Array

        onImportItemsChanged: {
            if (importItems.length > 0) {
                fileUrls = new Array

                for (var i = 0; i < importItems.length; i++) {
                    const url = importItems[i].url
                    console.log("URL: " + url)
                    if (fileUrls.indexOf(url) == -1) {
                        fileUrls.push(url)
                    }
                }

                gameImportRoot.accepted()
            }
        }

        signal accepted()

        function open() {
            var peer = null
            for (var i = 0; i < model.peers.length; ++i) {
                var p = model.peers[i]
                if (p.appId.indexOf("com.ubuntu.filemanager_") === 0) {
                    peer = p
                }
            }

            activeTransfer = peer.request()
        }

        ContentPeerModel {
            id: model
            contentType: ContentType.Documents
            handler: ContentHandler.Source
        }
        ContentTransferHint {
            id: importHint
            anchors.fill: parent
            activeTransfer: gameImportRoot.activeTransfer
        }
        Connections {
            target: gameImportRoot.activeTransfer
            onStateChanged: {
                if (gameImportRoot.activeTransfer.state === ContentTransfer.Charged) {
                    importItems = gameImportRoot.activeTransfer.items;
                }
            }
        }
    }

    Page {
        anchors.fill: parent

        header: PageHeader {
            id: header
            title: i18n.tr('Quake II Touch')
            trailingActionBar {
                numberOfSlots: 1
                actions: [
                    Action {
                        iconName: "document-save"
                        text: "Download demo"
                        onTriggered: {
                            PopupUtils.open(downloadGameDialog)
                        }
                    },
                    /*Action {
                        iconName: "add"
                        text: "Import game"
                        onTriggered: {
                        }
                    },*/
                    Action {
                        iconName: "preferences-desktop-accounts-symbolic"
                        text: "Player name"
                        onTriggered: {
                            PopupUtils.open(userSettingsDialog)
                        }
                    },
                    Action {
                        iconName: "info"
                        text: "Info"
                        onTriggered: {
                            PopupUtils.open(infoDialog)
                        }
                    }
                ]
            }

        }

        UbuntuListView {
            id: gamesListView
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            model: Utils.games

            pullToRefresh {
                enabled: false
            }
            delegate: ListItem {
                property string gameName : modelData

                leadingActions: ListItemActions {
                    actions: [
                        Action {
                            iconName: "delete"
                            onTriggered: {
                                Utils.deleteGame(gameName)
                                Utils.refreshGames()
                            }
                        }
                    ]
                }

                ListItemLayout {
                    title.text: gameName
                }
                onClicked: {
                    selectedGameName = gameName;
                    PopupUtils.open(startGameDialog)
                }
            }
        }

        Label {
            text: qsTr("No games found. Download the demo to proceed.")
            visible: Utils.games.length <= 0
            anchors.centerIn: parent
            width: parent.width
            textSize: Label.Large
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: startGameDialog

        Dialog {
            id: startGameDialogue
            title: qsTr("Start")
            text: qsTr("How would you like to start this game?")
            Button {
                text: qsTr("Singleplayer")
                color: theme.palette.normal.positive
                onClicked: {
                    Utils.startGame(selectedGameName)
                }
            }
            Button {
                text: qsTr("Join multiplayer")
                color: theme.palette.normal.positive
                onClicked: {
                    PopupUtils.close(startGameDialogue)
                    PopupUtils.open(joinMultiplayerDialog)
                }
            }
            /*
            Button {
                text: qsTr("Host multiplayer")
                color: theme.palette.normal.positive
                onClicked: {
                    PopupUtils.close(startGameDialogue)
                    PopupUtils.open(hostMultiplayerDialog)
                }
            }
            */
            Button {
                text: qsTr("Cancel")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(startGameDialogue)
                }
            }
        }
    }

    Component {
        id: downloadGameDialog

        Dialog {
            id: downloadGameDialogue
            title: qsTr("Demo download")
            text: qsTr("Would you like to download the Quake II demo?")
            ProgressBar {
                id: progressBar
                visible: false
                minimumValue: 0.0
                maximumValue: 1.0
                value: Utils.progress
            }
            Button {
                id: downloadGameOkButton
                text: qsTr("Ok")
                color: theme.palette.normal.positive
                onClicked: {
                    downloadGameOkButton.enabled = false
                    downloadGameCancelButton.enabled = false
                    progressBar.visible = true
                    Utils.getDemo()
                }
            }
            Button {
                id: downloadGameCancelButton
                text: qsTr("Cancel")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(downloadGameDialogue)
                }
            }
            Connections {
                target: Utils
                onDownloadSucceeded: {
                    PopupUtils.close(downloadGameDialogue)
                }
                onDownloadFailed: {
                    PopupUtils.close(downloadGameDialogue)
                    PopupUtils.open(downloadFailedDialog)
                }
            }
        }
    }

    Component {
        id: userSettingsDialog

        Dialog {
            id: userSettingsDialogue
            title: qsTr("Player name")

            Component.onCompleted: {
                playerNameField.text = userSettings.playerName
            }

            TextField {
                id: playerNameField
                width: parent.width
            }

            Button {
                text: qsTr("Ok")
                color: theme.palette.normal.positive
                enabled: playerNameField.length > 0
                onClicked: {
                    userSettings.playerName = playerNameField.text
                    PopupUtils.close(userSettingsDialogue)
                }
            }
        }
    }

    Component {
        id: downloadFailedDialog

        Dialog {
            id: downloadFailedDialogue
            title: qsTr("Download failed")
            text: qsTr("Downloading the demo game failed, please try again later.")
            Button {
                text: qsTr("Ok")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(downloadFailedDialogue)
                }
            }
        }
    }

    Component {
        id: joinMultiplayerDialog

        Dialog {
            id: joinMultiplayerDialogue
            title: qsTr("Join multiplayer game")
            text: qsTr("Enter the server address to connect:")
            TextField {
                id: serverAddress
                width: parent.width
            }
            Button {
                text: qsTr("Connect")
                color: theme.palette.normal.positive
                enabled: serverAddress.length > 0
                onClicked: {
                    Utils.joinMultiplayerGame(selectedGameName, serverAddress.text, userSettings.playerName)
                }
            }
            Button {
                text: qsTr("Cancel")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(joinMultiplayerDialogue)
                }
            }
        }
    }

    Component {
        id: hostMultiplayerDialog

        Dialog {
            id: hostMultiplayerDialogue
            title: qsTr("Host multiplayer game")
            text: qsTr("Start a multiplayer session?")

            readonly property var gameModes : ["Deathmatch", "Co-Operative"]
            readonly property var gameModesValues : ["+deathmatch", "+coop"]

            OptionSelector {
                id: gameModeSelector
                text: qsTr("Game type:")
                model: gameModes
                width: parent.width
            }
            Button {
                text: qsTr("Ok")
                color: theme.palette.normal.positive
                onClicked: {
                    Utils.hostMultiplayerGame(selectedGameName, gameModesValues[gameModeSelector.selectedIndex])
                }
            }
            Button {
                text: qsTr("Cancel")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(hostMultiplayerDialogue)
                }
            }
        }
    }

    Component {
        id: infoDialog

        Dialog {
            id: infoDialogue
            title: qsTr("About Quake II Touch")

            Column {
                id: aboutMainColumn
                width: parent.width
                spacing: units.gu(4)
                anchors.topMargin: typicalMargin

                UbuntuShape {
                    width: Math.min(parent.width, parent.height) / 2
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: Image {
                        source: "qrc:/assets/logo.jpg"
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Quake II for Ubuntu Touch")
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    horizontalAlignment: Text.AlignHCenter
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: typicalMargin
                        rightMargin: typicalMargin
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: typicalMargin

                    Label {
                        text: qsTr("Donate via PayPal")
                        font.underline: true
                        textSize: Label.Large
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Qt.openUrlExternally("https://paypal.me/beidl")
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Licensed under GPL v2")
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    horizontalAlignment: Text.AlignHCenter
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: typicalMargin
                        rightMargin: typicalMargin
                    }
                }

                Label {
                    text: qsTr("Source code on GitHub")
                    font.underline: true
                    textSize: Label.Small
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Qt.openUrlExternally("https://github.com/fredldotme/quake2touch-launcher")
                        }
                    }
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: typicalMargin
                        rightMargin: typicalMargin
                    }
                }
            }

            Button {
                text: qsTr("Close")
                color: theme.palette.normal.positive
                onClicked: {
                    PopupUtils.close(infoDialogue)
                }
            }
        }
    }
}
