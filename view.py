# -*- coding: utf-8 -*-
import logging, sys, json, datetime, uuid
from view.graph._view import Ui_Form
from PySide6.QtWidgets import (QComboBox, QVBoxLayout, QLabel, QPushButton, QWidget, QDialog, QMessageBox, QPlainTextEdit)
from PySide6.QtQuickWidgets import QQuickWidget
from PySide6.QtCore import Slot, QUrl, QObject, QAbstractListModel, QAbstractTableModel, Qt, QSize, QMimeData, QModelIndex
from PySide6.QtQml import QJSValue
from libs.task import Task

_top = sys.modules['__main__']

class TaskTableModel(QAbstractTableModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.tasks = []
        self.headers = ["任务ID", "操作员", "车型", "流程", "状态"]

    def rowCount(self, parent=QModelIndex()):
        return len(self.tasks)

    def columnCount(self, parent=QModelIndex()):
        return len(self.headers)

    def data(self, index, role=Qt.DisplayRole):

        if not index.isValid() or not (0 <= index.row() < len(self.tasks)):
            return None

        task = self.tasks[index.row()]
        col = index.column()

        if role == Qt.DisplayRole:
            if col == 0:
                return task.taskId
            elif col == 1:
                return task.workerId
            elif col == 2:
                return task.carType
            elif col == 3:
                # Check if theCmdManager exists and has meta attribute
                if hasattr(task, 'theCmdManager') and task.theCmdManager and hasattr(task.theCmdManager, 'meta'):
                    return task.theCmdManager.meta.get('name', "未知")
                return "未知"
            elif col == 4:
                status_map = {
                    0: "未开始",
                    1: "运行中",
                    2: "已完成",
                    3: "已停止",
                    4: "错误"
                }
                return status_map.get(task.status, "未知")

        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role == Qt.DisplayRole and orientation == Qt.Horizontal:
            return self.headers[section]
        return None

    def addTask(self, task):
        self.beginInsertRows(QModelIndex(), len(self.tasks), len(self.tasks))
        self.tasks.append(task)
        self.endInsertRows()
        return True

    def updateTask(self, task):
        index = self.tasks.index(task)
        self.dataChanged.emit(self.index(index, 0), self.index(index, self.columnCount() - 1))

    def getTask(self, index):
        if 0 <= index < len(self.tasks):
            return self.tasks[index]
        return None

class Window(QWidget):

    def __init__(self):

        super().__init__()
        self.ui = Ui_Form()
        self.ui.setupUi(self)
        self.ui.retranslateUi(self)

        # 设置本页面的CmdManager代理
        self.CmdManagerAgent = None

        # 设置下拉菜单
        # flownames = list(map(lambda cmdkey: _top.CmdManager[cmdkey].meta['name'], list(_top.CmdManager.keys())))
        flownames = list(_top.CmdManager.keys())

        self.ui.cmb_flow.addItems(flownames)
        self.ui.cmb_flow.currentIndexChanged.connect(self.onSelectFlow)

        # 初始化QML控件
        self.qml_flow = QQuickWidget()
        self.qml_flow.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView)
        self.layout_qml = QVBoxLayout(self.ui.wgt_flow)
        self.layout_qml.addWidget(self.qml_flow)
        self.qml_flow.setStyleSheet('margin:0px;\npadding:0px;')

        # 初始化qml根对象
        self.qml_root = None

        # 初始化任务表格模型
        self.task_model = TaskTableModel(self)
        self.ui.tb_tasks.setModel(self.task_model)

        # 设置表格列宽
        header = self.ui.tb_tasks.horizontalHeader()
        header.setSectionResizeMode(0, header.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, header.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(2, header.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(3, header.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(4, header.ResizeMode.ResizeToContents)

        # 连接表格选择信号
        self.ui.tb_tasks.selectionModel().selectionChanged.connect(self.onTaskSelected)

        # 当前选中的任务
        _top.curTask = None

        # 绑定事件
        self.ui.btn_newtask.clicked.connect(self.onNewTask)
        self.ui.btn_start.clicked.connect(self.onStart)
        self.ui.btn_stop.clicked.connect(self.onStop)
        self.ui.btn_reset.clicked.connect(self.onReset)

        self.SetGraph("测试流程")

        _top.popper.evtBegin.connect(self.onPopup)

    def SetGraph(self, flowname):

        for k, _  in _top.CmdManager.items():
            if k==flowname:
                self.CmdManagerAgent = _top.CmdManager.get(flowname)
                break

        if not self.CmdManagerAgent:
            logging.error(f"无法获取CmdManager:{flowname}")
            return

        nodes_model, connections_model = self.CmdManagerAgent.genQmlModel()
        self.qml_flow.rootContext().setContextProperty("editable", _top.User=="admin")
        self.qml_flow.rootContext().setContextProperty("nodesData", nodes_model)
        self.qml_flow.rootContext().setContextProperty("connectionsData", connections_model)

        self.qml_flow.setSource(QUrl.fromLocalFile('view/graph/Canvas.qml'))
        self.qml_root = self.qml_flow.rootObject()
        self.qml_root.evtAny.disconnect()
        self.qml_root.evtAny.connect(self.onAny)

        self.CmdManagerAgent.evtCmdChanged.connect(self.onChildStatusChanged)
        for _, cmdobj in self.CmdManagerAgent.cmdObjs.items():
            self.qml_root.updateNodeStatus(cmdobj.id, cmdobj.cmdStatus)

        self.ui.lb_flow_desc.setText(self.CmdManagerAgent.meta['desc'])

    # Force a complete refresh of the QML widget by recreating it
    def reloadGraph(self):
        self.qml_flow.deleteLater()
        self.qml_flow = QQuickWidget()
        self.qml_flow.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView)
        self.layout_qml.replaceWidget(self.layout_qml.itemAt(0).widget(), self.qml_flow)
        self.qml_flow.setStyleSheet('margin:0px;\npadding:0px;')
        flowname = self.ui.cmb_flow.currentText()
        self.SetGraph(flowname)


    @Slot()
    def onSelectFlow(self):
        flowname = self.ui.cmb_flow.currentText()
        self.SetGraph(flowname)

    @Slot()
    def onStart(self):
        if _top.curTask:
            # Start the selected task
            _top.curTask.startTask()
            # Update the task status in the model
            self.task_model.layoutChanged.emit()
        else:
            QMessageBox.warning(self, "错误", "未选择任务!")


    @Slot()
    def onStop(self):
        if _top.curTask:
            # Stop the selected task
            _top.curTask.theCmdManager.stop()
            # Update the task status in the model
            _top.curTask.status = 3  # Set status to stopped
            self.task_model.layoutChanged.emit()
            QMessageBox.information(self, "成功", f"已停止任务: {_top.curTask.taskId}")
        else:
            QMessageBox.warning(self, "错误", "未选择任务!")

    def onReset(self):
        if _top.curTask:
            # Reset the selected task
            _top.curTask.theCmdManager.reset()
            # Update the task status in the model
            _top.curTask.status = 0  # Set status to idle
            _top.curTask.reseted = True
            self.task_model.layoutChanged.emit()
            QMessageBox.information(self, "成功", f"已重置任务: {_top.curTask.taskId}")
        else:
            QMessageBox.warning(self, "错误", "未选择任务!")

    @Slot(dict)
    def onAny(self, response):
        response = response.toVariant()

        if response["code"] == -2:
            QMessageBox.critical(None, "错误", response["msg"])

        elif response["code"] == -1:
            QMessageBox.warning(None, "警告", response["msg"])

        else:
            # 移动不需要重新加载配置
            if response["type"] == "move":
                self.CmdManagerAgent.nodes[response["data"]["id"]]['x'] = response["data"]["x"]
                self.CmdManagerAgent.nodes[response["data"]["id"]]['y'] = response["data"]["y"]
                self.CmdManagerAgent.saveFlow()

            # 其余需要重新加载配置
            else:
                nodeId = response["data"]

                if response["type"] == "edit_self":
                    if nodeId == "head" or nodeId == "end": return
                    cmd_data = self.CmdManagerAgent.cmds[nodeId]

                    # Create dialog with text editor
                    dialog = QDialog(self)
                    dialog.setWindowTitle("编辑指令")
                    dialog.setMinimumSize(QSize(200, 200))

                    layout = QVBoxLayout(dialog)

                    # Add text editor
                    text_editor = QPlainTextEdit(dialog)
                    text_editor.setPlainText(json.dumps(cmd_data, indent=4, ensure_ascii=False))
                    layout.addWidget(text_editor)

                    # Add OK button
                    ok_button = QPushButton("确认", dialog)
                    ok_button.clicked.connect(dialog.accept)
                    layout.addWidget(ok_button)

                    # Show dialog
                    if dialog.exec() == QDialog.Accepted:
                        try:
                            # Parse JSON and update command
                            new_cmd_data = json.loads(text_editor.toPlainText())
                            self.CmdManagerAgent.cmds[nodeId] = new_cmd_data
                            self.CmdManagerAgent.saveFlow()
                            self.CmdManagerAgent.loadFlow()
                            self.CmdManagerAgent.loadCmds()
                        except json.JSONDecodeError:
                            QMessageBox.critical(None, "错误", "JSON格式错误，请检查输入")

                elif response["type"] == "add_child":
                    if nodeId == "end": return
                    self.CmdManagerAgent.addCmd(nodeId)
                    self.reloadGraph()

                elif response["type"] == "del_self":
                    if nodeId == "head" or nodeId == "end": return
                    confirm = QMessageBox.question(
                        self,
                        "确认删除",
                        f"确定要删除指令 '{self.CmdManagerAgent.cmds[nodeId]['name']}' 吗？",
                        QMessageBox.Yes | QMessageBox.No
                    )

                    if confirm == QMessageBox.Yes:
                        # Remove the node from flow connections
                        for parent_id, children in self.CmdManagerAgent.flow.items():
                            if nodeId in children:
                                children.remove(nodeId)

                        # Remove the node's own flow entry
                        if nodeId in self.CmdManagerAgent.flow:
                            del self.CmdManagerAgent.flow[nodeId]

                        # Remove from nodes dictionary
                        if nodeId in self.CmdManagerAgent.nodes:
                            del self.CmdManagerAgent.nodes[nodeId]

                        # Remove from cmds dictionary
                        if nodeId in self.CmdManagerAgent.cmds:
                            del self.CmdManagerAgent.cmds[nodeId]

                        # Remove from cmdObjs dictionary
                        if nodeId in self.CmdManagerAgent.cmdObjs:
                            del self.CmdManagerAgent.cmdObjs[nodeId]

                        # Save changes
                        self.CmdManagerAgent.saveFlow()
                        self.reloadGraph()

                elif response["type"] == "set_child":
                    if nodeId == "end": return
                    cmd_items = [f"{id}:{cmd.name}" for id, cmd in self.CmdManagerAgent.cmdObjs.items()]

                    dialog_args = {
                        "next_cmds": cmd_items
                    }

                    _top.popper.pop("dialogPath", dialog_args)
                    if _top.popper.done and _top.popper.result:
                        print(_top.popper.result)
                        selected_cmd_id = _top.popper.result.split(":")[0]
                        addflag = _top.popper.result.split(":")[2]=="True"
                        _top.popper.done = True
                        self.CmdManagerAgent.setCmd(nodeId, selected_cmd_id, addflag)

                else:
                    pass

                self.reloadGraph()

    @Slot(str, int)
    def onChildStatusChanged(self, cmd_id, status):
        self.qml_root.updateNodeStatus(cmd_id, status)

    @Slot()
    def onNewTask(self):
        # Get selected flow and car type
        flowname = self.ui.cmb_flow.currentText()
        cartype = self.ui.cmb_cartypes.currentText()

        if not flowname:
            QMessageBox.warning(self, "警告", "请选择测试流程")
            return

        # Create a new task
        try:
            # Clone the CmdManager for this task
            cmd_manager = _top.CmdManager.get(flowname)
            if not cmd_manager:
                QMessageBox.warning(self, "警告", f"无法获取流程: {flowname}")
                return

            # Create a new task with a worker ID (using current user or admin as default)
            worker_id = getattr(_top, 'User')
            print(f"Creating task for worker: {worker_id}")

            # Create the task
            task = Task(carType=cartype, workerId=worker_id, theCmdManager=cmd_manager)
                    # Register a callback to update task status when flow completes
            def update_status(status):
                if status in [2, 3, 4]:  # If completed, stopped, or error
                    task.endTime = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    self.task_model.updateTask(task)

            task.theCmdManager.evtFlowStatusChanged.connect(update_status)


            # Add the task to the model
            if self.task_model.addTask(task):
                QMessageBox.information(self, "成功", f"已创建任务: {task.taskId}")
            else:
                QMessageBox.warning(self, "警告", "创建任务失败")

        except Exception as e:
            logging.error(f"创建任务出错: {e}")
            QMessageBox.critical(self, "错误", f"创建任务出错: {e}")

    @Slot()
    def onTaskSelected(self, selected, _):
        # Get the selected task
        indexes = selected.indexes()
        if not indexes:
            return

        # Get the task from the model
        task_index = indexes[0].row()
        task = self.task_model.getTask(task_index)

        if task:
            # Set the current task
            _top.curTask = task

            # Update the UI to show the selected task's flow
            flowname = task.theCmdManager.meta['name']
            self.ui.cmb_flow.setCurrentText(flowname)
            self.SetGraph(flowname)

            # Update the car type combobox
            index = self.ui.cmb_cartypes.findText(task.carType)
            if index >= 0:
                self.ui.cmb_cartypes.setCurrentIndex(index)

            # Update button states based on task status
            self.ui.btn_start.setEnabled(task.status in [0, 3])  # Enable if idle or stopped
            self.ui.btn_stop.setEnabled(task.status == 1)  # Enable if running
            self.ui.btn_reset.setEnabled(task.status in [2, 3, 4])  # Enable if done, stopped, or error

    @Slot(str, dict)
    def onPopup(self, funcID, args, input):
        _top.popper.pop(funcID, args, input)

