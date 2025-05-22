import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15


Rectangle {
    id: canvas
    visible: true
    width: 800
    height: 600
    anchors.fill: parent
    anchors.margins: 5

    property var nodes: ({})

    signal evtAny(var response)

    function updateNodeStatus(nodeId, status) {
        var node = canvas.nodes[nodeId]
        if (node) {
            node.textColor = status === 1 ? "white" : "black"
            node.bgColor = status === 1 ? "orange" : status === 2 ? "green" : status === 3 ? "red" : "white"
        } else {
            console.log("Node not found:", nodeId)
        }
    }

    ListModel {
        id: nodesModel
    }

    ListModel {
        id: connectionsModel
    }

    Component.onCompleted: {
        for (var i = 0; i < nodesData.length; i++) {
            nodesModel.append(nodesData[i])
        }
        for (var j = 0; j < connectionsData.length; j++) {
            connectionsModel.append(connectionsData[j])
        }
    }

    Repeater {
        model: nodesModel
        delegate: FlowNode {
            z:2
            nodeId: model.id
            text: model.text
            x: model.x
            y: model.y
            textColor: model.status === 1 ? "white" : "black"
            bgColor: model.status === 1 ? "orange" : model.status === 2 ? "green" : model.status === 3 ? "red" : "white"
            radius: model.type === "plc" ? 0 :20

            // 这是最神奇的隐式绑定!!!!!!!!
            // 子节点的Signal名称为 evtAddChild
            // 在这里的调用名称改为 onEvtAddChild
            onEvtAddChild :{
                if (!editable) {
                    evtAny({code: -1, type:"add_child", msg: "非管理员无法编辑流程!",data: null})
                } else {
                    evtAny({code: 0, type:"add_child", msg: "接受请求",data: model.id})
                }
            }

            onEvtDelSelf :{
                if (!editable) {
                    evtAny({code: -1, type:"del_self", msg: "非管理员无法编辑流程!",data: null})
                } else {
                    evtAny({code: 0, type:"del_self", msg: "接受请求",data: model.id})
                }
            }

            onEvtSetChild :{
                if (!editable) {
                    evtAny({code: -1, type:"set_child", msg: "非管理员无法编辑流程!",data: null})
                } else {
                    evtAny({code: 0, type:"set_child", msg: "接受请求",data: model.id})
                }
            }

            onEvtDoubleClick:{
                if (!editable) {
                    evtAny({code: -1, type:"edit_self", msg: "非管理员无法编辑流程!",data: null})
                } else {
                    evtAny({code: 0, type:"edit_self", msg: "接受请求",data: model.id})
                }
            }

            onEvtMove: {
                if (editable) {
                    evtAny({code: 0, type: "move", msg: "接受请求", data: {id: nodeId, x: x, y: y}})
                }
            }
            
            Component.onCompleted: {
                canvas.nodes[nodeId] = this
                // console.log("Node added:", nodeId, this)
            }
        }
    }

Repeater {
    model: connectionsModel
    delegate: Shape {
        z: 1  // Set z-index lower than nodes (which have z:1)
        id: connectionShape
        property string from: model.from
        property string to: model.to
        
        // Get center points of nodes
        property real fromX: canvas.nodes[from].cx
        property real fromY: canvas.nodes[from].cy
        property real toX: canvas.nodes[to].cx
        property real toY: canvas.nodes[to].cy
        
        // Determine if horizontal or vertical routing is better
        property bool useHorizontalFirst: Math.abs(toX - fromX) > Math.abs(toY - fromY)
        
        // First segment
        ShapePath {
            strokeColor: "#5f5c5c"
            strokeWidth: 2
            startX: fromX
            startY: fromY
            
            PathLine {
                x: useHorizontalFirst ? toX : fromX
                y: useHorizontalFirst ? fromY : toY
            }
        }
        
        // Second segment
        ShapePath {
            strokeColor: "#5f5c5c"
            strokeWidth: 2
            startX: useHorizontalFirst ? toX : fromX
            startY: useHorizontalFirst ? fromY : toY
            
            PathLine {
                x: toX
                y: toY
            }
        }
    }
}

}
