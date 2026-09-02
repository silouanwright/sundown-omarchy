import QtQuick
import Quickshell
import qs.Commons
import "Plugin" as Plugin

ShellRoot {
  id: shell

  readonly property string previewState: Quickshell.env("SUNDOWN_HISTORY_PREVIEW_STATE")
  readonly property string outputPath: Quickshell.env("SUNDOWN_HISTORY_PREVIEW_OUTPUT")
  readonly property bool light: Quickshell.env("SUNDOWN_HISTORY_PREVIEW_THEME") === "catppuccin-latte"
  readonly property color previewBackground: shell.light ? "#eff1f5" : Color.popups.background
  readonly property color previewForeground: shell.light ? "#4c4f69" : Color.popups.text
  readonly property color previewUrgent: shell.light ? "#d20f39" : Color.urgent
  readonly property bool stale: shell.previewState === "stale"
  readonly property bool failed: shell.previewState === "error"

  QtObject {
    id: controller
    property bool reportKnown: true
    property bool reportBusy: false
    property bool reportEverLoaded: !shell.failed
    property string reportError: shell.stale ? qsTr("Could not refresh history")
      : (shell.failed ? qsTr("Could not load Screen Time history") : "")
    property var report: ({
      end_date: "2026-09-02",
      recorded_days: shell.stale ? 2 : 0,
      days: [],
      totals: {
        steam_seconds: shell.stale ? 4200 : 0,
        web_seconds: shell.stale ? { social: 1800 } : {},
        app_seconds: {}
      }
    })
  }

  FloatingWindow {
    implicitWidth: preview.width
    implicitHeight: preview.height
    visible: true
    color: shell.previewBackground

    Rectangle {
      id: preview
      width: Style.space(420)
      height: history.implicitHeight + Style.space(40)
      color: shell.previewBackground

      Plugin.HistoryView {
        id: history
        anchors.centerIn: parent
        width: Style.space(380)
        controller: controller
        foreground: shell.previewForeground
        urgent: shell.previewUrgent
        weekRows: shell.stale ? [
          { date: "2026-08-27", label: "T", seconds: 0, recorded: false },
          { date: "2026-08-28", label: "F", seconds: 0, recorded: false },
          { date: "2026-08-29", label: "S", seconds: 0, recorded: false },
          { date: "2026-08-30", label: "S", seconds: 3600, recorded: true },
          { date: "2026-08-31", label: "M", seconds: 0, recorded: false },
          { date: "2026-09-01", label: "T", seconds: 0, recorded: false },
          { date: "2026-09-02", label: "W", seconds: 2400, recorded: true }
        ] : []
        categories: shell.stale ? [
          { label: qsTr("Gaming"), seconds: 4200 },
          { label: qsTr("Social"), seconds: 1800 }
        ] : []
        flexAuditRows: []
        weekMaximum: 3600
      }

      Timer {
        interval: 700
        running: true
        onTriggered: preview.grabToImage(function(result) {
          if (!result.saveToFile(shell.outputPath)) Qt.exit(2)
          else Qt.quit()
        }, Qt.size(preview.width * 2, preview.height * 2))
      }
    }
  }
}
