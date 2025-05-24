import sys
import os
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QObject # QObject might not be needed directly here but good for general PySide6 development

# Sample data for nodes
nodesData = [
    {"id": "node1", "text": "Start", "x": 50, "y": 50, "type": "start", "status": 0},
    {"id": "node2", "text": "Process 1", "x": 250, "y": 50, "type": "process", "status": 0},
    {"id": "node3", "text": "Decision", "x": 250, "y": 150, "type": "decision", "status": 0},
    {"id": "node4", "text": "Process 2A", "x": 50, "y": 250, "type": "process", "status": 0},
    {"id": "node5", "text": "Process 2B", "x": 450, "y": 150, "type": "process", "status": 0},
    {"id": "node6", "text": "End", "x": 250, "y": 350, "type": "end", "status": 0}
]

# Sample data for connections
connectionsData = [
    {"from": "node1", "to": "node2"},
    {"from": "node2", "to": "node3"},
    {"from": "node3", "to": "node4"}, # Yes branch
    {"from": "node3", "to": "node5"}, # No branch
    {"from": "node4", "to": "node6"},
    {"from": "node5", "to": "node6"}
]

if __name__ == "__main__":
    # Create the Qt Application
    app = QGuiApplication(sys.argv)

    # Create the QML engine
    engine = QQmlApplicationEngine()

    # Expose Python data to QML
    engine.rootContext().setContextProperty("nodesData", nodesData)
    engine.rootContext().setContextProperty("connectionsData", connectionsData)
    engine.rootContext().setContextProperty("editable", True) # Set editable to True

    # Construct the path to Canvas.qml
    # Assuming main.py is in the root and Canvas.qml is in view/graph/
    # Get the directory where main.py is located
    current_dir = os.path.dirname(os.path.abspath(__file__))
    qml_file_path = os.path.join(current_dir, "view", "graph", "Canvas.qml")
    
    # Convert the path to a QUrl
    qml_file_url = QUrl.fromLocalFile(qml_file_path)

    # Load the QML file
    engine.load(qml_file_url)

    # Check if loading was successful
    if not engine.rootObjects():
        print(f"Error: Could not load QML file: {qml_file_path}")
        sys.exit(-1)

    # Execute the application and exit
    sys.exit(app.exec())
