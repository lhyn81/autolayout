import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15

Rectangle {
    id: node
    width: 100
    height: 20
    color: bgColor
    border.color: "black"

    // Node identification and styling properties
    property string nodeId: ""
    property string text: ""
    property string textColor: "black"
    property string bgColor: hovering ? "cyan" : "lightblue"

    // Connection points
    property real cx: x + width/2
    property real cy: y + height/2
    // property real topY: y
    // property real bottomY: y + height
    // property real leftX: x
    // property real rightX: x + width
    
    // property real bothY: y + height/2
    // property real bothX: x + width/2

    // Interaction properties
    property bool dragging: false
    property bool hovering: false // New property for hover state

    signal evtAddChild(string nodeId)
    signal evtDelSelf(string nodeId)
    signal evtSetChild(string nodeId)
    signal evtDoubleClick(string nodeId)
    signal evtMove(string nodeId, real x, real y) // New signal for move event

    Text {
        anchors.centerIn: parent
        text: node.text
        color: textColor
        font.pixelSize: 12
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        property real startX
        property real startY

        onEntered: hovering = true // Set hover state to true
        onExited: hovering = false // Set hover state to false

        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                node.evtDoubleClick(node.nodeId); // Emit signal on double-click
            }
        }

        onPressed: function(mouse) {
            if (editable) {
                if (mouse.button === Qt.LeftButton) {
                    var mousePos = mapToItem(node.parent, mouse.x, mouse.y); // Map mouse coordinates to node's parent
                    startX = mousePos.x;
                    startY = mousePos.y;
                    dragging = true;
                }

            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                dragging = false;
                evtMove(node.nodeId, node.x, node.y); // Emit move event with new position
            } else if (mouse.button === Qt.RightButton) {
                node.Clicked(nodeId); // Emit signal on right-click
            }
        }

        onPositionChanged: function(mouse) {
            if (dragging) {
                var mousePos = mapToItem(node.parent, mouse.x, mouse.y); // Map mouse coordinates to node's parent
                var dx = mousePos.x - startX;
                var dy = mousePos.y - startY;
                node.x += dx;
                node.y += dy;
                startX = mousePos.x;
                startY = mousePos.y;
            }
        }
        
    }

    Menu {
        id: contextMenu
        MenuItem {
            text: "添加下一指令"
            onTriggered: evtAddChild(node.nodeId)
        }
        MenuItem {
            text: "删除本指令"
            onTriggered: evtDelSelf(node.nodeId)
        }
        MenuItem {
            text: "重置下级指令"
            onTriggered: evtSetChild(node.nodeId)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.open(); // Open context menu on right-click
            }
        }
    }
}
