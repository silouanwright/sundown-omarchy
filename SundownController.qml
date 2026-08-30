import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property bool panelOpen: false
  property bool statusKnown: false
  property bool reportKnown: false
  property bool available: false
  property bool everLoaded: false
  property var status: Model.emptyStatus()
  property var report: Model.emptyReport()
  property string statusError: ""
  property string reportError: ""
  property string statusCompatibility: ""
  property string reportCompatibility: ""
  property bool flexBusy: false
  property string flexMessage: ""
  property string flexError: ""
  property string _statusOutput: ""
  property string _statusStderr: ""
  property string _reportOutput: ""
  property string _reportStderr: ""
  property string _flexOutput: ""
  property string _flexStderr: ""

  visible: false
  width: 0
  height: 0

  function refreshStatus() {
    if (statusProcess.running) return
    _statusOutput = ""
    _statusStderr = ""
    statusProcess.running = true
  }

  function refreshReport() {
    if (reportProcess.running) return
    _reportOutput = ""
    _reportStderr = ""
    reportProcess.running = true
  }

  function refreshAll() {
    refreshStatus()
    refreshReport()
  }

  function redeemFlex(target) {
    if (flexProcess.running || !target) return
    flexBusy = true
    flexMessage = ""
    flexError = ""
    _flexOutput = ""
    _flexStderr = ""
    flexProcess.command = ["/usr/bin/sundown", "flex", "redeem", String(target)]
    flexProcess.running = true
  }

  function compatibilityMessage(issue, fallback) {
    if (issue === "core-too-old") return qsTr("Update the Sundown core to use this panel")
    if (issue === "plugin-too-old") return qsTr("Update the Sundown Omarchy plugin")
    return fallback
  }

  Process {
    id: statusProcess
    command: ["/usr/bin/sundown", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root._statusOutput = text
        const parsed = Model.parseStatus(text)
        if (parsed.ok) {
          root.status = parsed.data
          root.statusKnown = true
          root.available = true
          root.everLoaded = true
          root.statusCompatibility = ""
          root.statusError = ""
        } else {
          root.statusCompatibility = parsed.compatibility || ""
          root.statusError = root.compatibilityMessage(root.statusCompatibility, parsed.error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._statusStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.statusKnown = true
      if (exitCode === 0 && root._statusOutput !== "") return
      if (!root.everLoaded) root.available = false
      root.statusError = root._statusStderr || (root.everLoaded
        ? qsTr("Could not refresh status; showing the last update")
        : qsTr("Sundown is not available"))
    }
  }

  Process {
    id: flexProcess
    onRunningChanged: {
      if (!running && root.flexBusy) {
        root.flexBusy = false
        root.flexError = qsTr("Could not start the Sundown command")
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._flexOutput = String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._flexStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.flexBusy = false
      if (exitCode === 0) {
        root.flexMessage = root._flexOutput || qsTr("Flex pass redeemed")
        root.refreshAll()
      } else {
        root.flexError = root._flexStderr || qsTr("Could not redeem the flex pass")
      }
    }
  }

  Process {
    id: reportProcess
    command: ["/usr/bin/sundown", "report", "week", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root._reportOutput = text
        const parsed = Model.parseReport(text)
        if (parsed.ok) {
          root.report = parsed.data
          root.reportKnown = true
          root.reportCompatibility = ""
          root.reportError = ""
        } else {
          root.reportCompatibility = parsed.compatibility || ""
          root.reportError = root.compatibilityMessage(root.reportCompatibility, parsed.error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._reportStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.reportKnown = true
      if (exitCode === 0 && root._reportOutput !== "") return
      root.reportError = root._reportStderr || qsTr("Could not load Screen Time history")
    }
  }

  Timer {
    interval: root.panelOpen ? 5000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: 60000
    running: root.panelOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshReport()
  }
}
