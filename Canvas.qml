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
        z: 1 // Set z-index lower than nodes
        id: connectionShape
        property string fromNodeId: model.from
        property string toNodeId: model.to
        property real cornerRadius: 8

        // Property to hold the calculated path details
        property var pathDetails: calculateConnectionPath()

        function calculateConnectionPath() {
            var fn = canvas.nodes[fromNodeId]; // fromNode
            var tn = canvas.nodes[toNodeId];   // toNode

            if (!fn || !tn) {
                return { p0x: 0, p0y: 0, p1x: 0, p1y: 0, p2x: 0, p2y: 0, p3x: 0, p3y: 0,
                         intermediatePointX: 0, intermediatePointY: 0, isDirect: true, sweep: PathArc.ClockwiseSweep, useArc: false };
            }

            const directAlignThreshold = 15; // Max pixels off-axis for a "direct" connection attempt
            var p0 = { x: 0, y: 0 }; // Start point
            var p3 = { x: 0, y: 0 }; // End point
            var intermediatePoint = { x: 0, y: 0 };
            var isDirect = false;
            var firstSegmentHorizontal = true; // Determines how arc points p1, p2 are calculated

            // Node center differences
            const dcx = tn.cx - fn.cx;
            const dcy = tn.cy - fn.cy;

            // Try direct connection first
            // 1. Horizontal direct: FromNode Right to ToNode Left, or FromNode Left to ToNode Right
            if (Math.abs(dcy) < fn.height / 2 + tn.height / 2 + directAlignThreshold) { // Nodes are somewhat horizontally aligned
                if (dcx > 0 && fn.ptRightX <= tn.ptLeftX + directAlignThreshold && Math.abs(fn.ptRightY - tn.ptLeftY) < directAlignThreshold) { // Right to Left
                    p0 = { x: fn.ptRightX, y: fn.ptRightY };
                    p3 = { x: tn.ptLeftX, y: tn.ptLeftY };
                    isDirect = true;
                } else if (dcx < 0 && fn.ptLeftX >= tn.ptRightX - directAlignThreshold && Math.abs(fn.ptLeftY - tn.ptRightY) < directAlignThreshold) { // Left to Right
                    p0 = { x: fn.ptLeftX, y: fn.ptLeftY };
                    p3 = { x: tn.ptRightX, y: tn.ptRightY };
                    isDirect = true;
                }
            }

            // 2. Vertical direct: FromNode Bottom to ToNode Top, or FromNode Top to ToNode Bottom
            if (!isDirect && Math.abs(dcx) < fn.width / 2 + tn.width / 2 + directAlignThreshold) { // Nodes are somewhat vertically aligned
                if (dcy > 0 && fn.ptBottomY <= tn.ptTopY + directAlignThreshold && Math.abs(fn.ptBottomX - tn.ptTopX) < directAlignThreshold) { // Bottom to Top
                    p0 = { x: fn.ptBottomX, y: fn.ptBottomY };
                    p3 = { x: tn.ptTopX, y: tn.ptTopY };
                    isDirect = true;
                } else if (dcy < 0 && fn.ptTopY >= tn.ptBottomY - directAlignThreshold && Math.abs(fn.ptTopX - tn.ptBottomX) < directAlignThreshold) { // Top to Bottom
                    p0 = { x: fn.ptTopX, y: fn.ptTopY };
                    p3 = { x: tn.ptBottomX, y: tn.ptBottomY };
                    isDirect = true;
                }
            }
            
            if (isDirect) {
                intermediatePoint = p0; // No bend
            } else {
                // L-bend logic
                if (Math.abs(dcx) > Math.abs(dcy)) { // Prefer H-V
                    firstSegmentHorizontal = true;
                    if (dcx > 0) { // ToNode is Right
                        p0 = { x: fn.ptRightX, y: fn.ptRightY };
                        // If ToNode is also significantly up/down, pick vertical port on ToNode
                        if (Math.abs(dcy) > tn.height/1.5) { // Heuristic for "significant"
                             p3 = (dcy > 0) ? { x: tn.ptTopX, y: tn.ptTopY } : { x: tn.ptBottomX, y: tn.ptBottomY };
                        } else {
                             p3 = { x: tn.ptLeftX, y: tn.ptLeftY };
                        }
                    } else { // ToNode is Left
                        p0 = { x: fn.ptLeftX, y: fn.ptLeftY };
                         if (Math.abs(dcy) > tn.height/1.5) {
                             p3 = (dcy > 0) ? { x: tn.ptTopX, y: tn.ptTopY } : { x: tn.ptBottomX, y: tn.ptBottomY };
                        } else {
                            p3 = { x: tn.ptRightX, y: tn.ptRightY };
                        }
                    }
                    intermediatePoint = { x: p3.x, y: p0.y };
                } else { // Prefer V-H
                    firstSegmentHorizontal = false;
                    if (dcy > 0) { // ToNode is Below
                        p0 = { x: fn.ptBottomX, y: fn.ptBottomY };
                        if (Math.abs(dcx) > tn.width/1.5) {
                            p3 = (dcx > 0) ? { x: tn.ptLeftX, y: tn.ptLeftY } : { x: tn.ptRightX, y: tn.ptRightY };
                        } else {
                            p3 = { x: tn.ptTopX, y: tn.ptTopY };
                        }
                    } else { // ToNode is Above
                        p0 = { x: fn.ptTopX, y: fn.ptTopY };
                        if (Math.abs(dcx) > tn.width/1.5) {
                             p3 = (dcx > 0) ? { x: tn.ptLeftX, y: tn.ptLeftY } : { x: tn.ptRightX, y: tn.ptRightY };
                        } else {
                             p3 = { x: tn.ptBottomX, y: tn.ptBottomY };
                        }
                    }
                    intermediatePoint = { x: p0.x, y: p3.y };
                }
            }

            var p1, p2; // Arc points
            var useArc = !isDirect;

            if (isDirect) {
                p1 = p0;
                p2 = p3;
            } else {
                // Calculate arc points p1 and p2
                if (firstSegmentHorizontal) { // Horizontal from p0, then Vertical to p3. Corner at (p3.x, p0.y)
                    p1 = { x: intermediatePoint.x - (intermediatePoint.x > p0.x ? cornerRadius : -cornerRadius), y: p0.y };
                    p2 = { x: intermediatePoint.x, y: p0.y + (p3.y > p0.y ? cornerRadius : -cornerRadius) };
                } else { // Vertical from p0, then Horizontal to p3. Corner at (p0.x, p3.y)
                    p1 = { x: p0.x, y: intermediatePoint.y - (intermediatePoint.y > p0.y ? cornerRadius : -cornerRadius) };
                    p2 = { x: p0.x + (p3.x > p0.x ? cornerRadius : -cornerRadius), y: intermediatePoint.y };
                }

                // Sanity check: if segments are shorter than cornerRadius, don't draw arc.
                if (firstSegmentHorizontal) {
                    // Length of first (horizontal) segment: Math.abs(intermediatePoint.x - p0.x)
                    // Length of second (vertical) segment: Math.abs(p3.y - p0.y) (since intermediatePoint.y is p0.y)
                    if (Math.abs(intermediatePoint.x - p0.x) < cornerRadius || Math.abs(p3.y - p0.y) < cornerRadius) {
                        useArc = false;
                    }
                } else { // Vertical first
                    // Length of first (vertical) segment: Math.abs(intermediatePoint.y - p0.y)
                    // Length of second (horizontal) segment: Math.abs(p3.x - p0.x) (since intermediatePoint.x is p0.x)
                    if (Math.abs(intermediatePoint.y - p0.y) < cornerRadius || Math.abs(p3.x - p0.x) < cornerRadius) {
                        useArc = false;
                    }
                }
                if (!useArc) { // If arc is too small, make sharp corner
                    p1 = intermediatePoint;
                    p2 = intermediatePoint;
                }
            }
            
            // Determine sweep direction
            var sweep = PathArc.ClockwiseSweep; // Default
            if (useArc) {
                if (firstSegmentHorizontal) {
                    // p0.y == p1.y == intermediatePoint.y (before correction)
                    // p2.x == intermediatePoint.x
                    if (p1.x > p2.x) { // Moving left towards intermediate.x
                        sweep = (p0.y > p2.y) ? PathArc.ClockwiseSweep : PathArc.CounterclockwiseSweep; // Turning Up : Turning Down
                    } else { // Moving right towards intermediate.x
                        sweep = (p0.y > p2.y) ? PathArc.CounterclockwiseSweep : PathArc.ClockwiseSweep; // Turning Up : Turning Down
                    }
                } else { // Vertical first
                    // p0.x == p1.x == intermediatePoint.x (before correction)
                    // p2.y == intermediatePoint.y
                     if (p1.y > p2.y) { // Moving up towards intermediate.y
                        sweep = (p0.x > p2.x) ? PathArc.CounterclockwiseSweep : PathArc.ClockwiseSweep; // Turning Left : Turning Right
                    } else { // Moving down towards intermediate.y
                        sweep = (p0.x > p2.x) ? PathArc.ClockwiseSweep : PathArc.CounterclockwiseSweep; // Turning Left : Turning Right
                    }
                }
            }

            return {
                p0x: p0.x, p0y: p0.y, p1x: p1.x, p1y: p1.y,
                p2x: p2.x, p2y: p2.y, p3x: p3.x, p3y: p3.y,
                intermediatePointX: intermediatePoint.x, intermediatePointY: intermediatePoint.y,
                isDirect: isDirect, useArc: useArc, sweepDirection: sweep
            };
        }

        // The actual path drawing
        ShapePath {
            strokeColor: "#5f5c5c"
            strokeWidth: 2
            startX: pathDetails.p0x
            startY: pathDetails.p0y
            fillColor: "transparent"

            PathLine { x: pathDetails.p1x; y: pathDetails.p1y }
            PathArc {
                x: pathDetails.p2x
                y: pathDetails.p2y
                radiusX: pathDetails.useArc ? cornerRadius : 0
                radiusY: pathDetails.useArc ? cornerRadius : 0
                sweepDirection: pathDetails.sweepDirection
                visible: pathDetails.useArc
            }
            PathLine {
                x: pathDetails.p3x
                y: pathDetails.p3y
            }
        }
    }
}

}
