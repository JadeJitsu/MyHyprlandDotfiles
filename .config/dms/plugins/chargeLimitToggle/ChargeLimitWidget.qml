import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Charge Limit Toggle — AI-generated 2026-11-23.
// Shows the TUXEDO battery charge-end threshold (from tccd); clicking the
// pill toggles it between 80% and 100% via charge-toggle.sh.
PluginComponent {
    id: root

    property string scriptPath: "/home/jlagman/.config/dms/plugins/chargeLimitToggle/charge-toggle.sh"
    property int refreshMs: 30000

    property string thresholdText: "..."

    // Click handler: toggle, then refresh the display immediately
    pillClickAction: (x, y, width, section, screen) => {
        toggleProcess.running = true;
    }

    // Read the current threshold into the label
    Process {
        id: readProcess
        command: ["sh", "-c", root.scriptPath + " get; echo"]
        running: false

        stdout: SplitParser {
            property bool captured: false
            onRead: data => {
                if (!captured) {
                    let line = data.trim();
                    if (line !== "") {
                        root.thresholdText = line + "%";
                        captured = true;
                    }
                }
            }
        }

        onRunningChanged: {
            if (!running && !stdout.captured) {
                root.thresholdText = "N/A";
            }
        }
    }

    // Run the toggle silently
    Process {
        id: toggleProcess
        command: ["sh", "-c", root.scriptPath + " toggle >/dev/null 2>&1; echo"]
        running: false

        onRunningChanged: {
            if (!running) {
                readProcess.stdout.captured = false;
                readProcess.running = true;
            }
        }
    }

    // Periodic refresh so the label tracks out-of-band changes (e.g. TCC GUI)
    Timer {
        id: refreshTimer
        interval: root.refreshMs
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!readProcess.running) {
                readProcess.stdout.captured = false;
                readProcess.running = true;
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "battery"
                size: root.iconSize
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.thresholdText
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                font.features: ({ "tnum": 1 })
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "battery"
                size: root.iconSize
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.thresholdText
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                font.features: ({ "tnum": 1 })
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
