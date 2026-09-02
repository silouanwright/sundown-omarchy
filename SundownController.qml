import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "PrerequisiteAdapter.js" as PrerequisiteAdapter

Item {
  id: root

  property bool panelOpen: false
  property string sundownCommand: "/usr/bin/sundown"
  property string evercountCommand: "/usr/bin/sundown-adapter-evercount"
  property bool statusKnown: false
  property bool reportKnown: false
  property bool adapterStatusKnown: false
  property bool available: false
  property bool everLoaded: false
  property var status: Model.emptyStatus()
  property var report: Model.emptyReport()
  property var adapterStatus: PrerequisiteAdapter.emptyStatus()
  property string statusError: ""
  property string reportError: ""
  property string adapterStatusError: ""
  property string statusCompatibility: ""
  property string reportCompatibility: ""
  property bool flexBusy: false
  property string flexMessage: ""
  property string flexError: ""
  property bool evercountSyncBusy: false
  property string evercountSyncMessage: ""
  property string evercountSyncError: ""
  readonly property var prerequisiteProviders: PrerequisiteAdapter.providers(adapterStatus)
  readonly property var adapterPrerequisites: PrerequisiteAdapter.prerequisites(adapterStatus)
  readonly property list<string> adapterStatusCommand: [
    root.sundownCommand, "adapters", "status", "--json"
  ]
  property string _statusOutput: ""
  property string _statusStderr: ""
  property string _reportOutput: ""
  property string _reportStderr: ""
  property string _flexOutput: ""
  property string _flexStderr: ""
  property string _evercountSyncOutput: ""
  property string _evercountSyncStderr: ""
  property string _adapterStatusStderr: ""
  property var _adapterStatusParsed: null
  property string _adapterStatusParseError: ""
  property bool _statusCompleted: false
  property bool _reportCompleted: false
  property bool _adapterStatusCompleted: false

  visible: false
  width: 0
  height: 0

  function refreshStatus() {
    if (statusProcess.running) return
    _statusOutput = ""
    _statusStderr = ""
    _statusCompleted = false
    statusProcess.running = true
  }

  function refreshReport() {
    if (reportProcess.running) return
    _reportOutput = ""
    _reportStderr = ""
    _reportCompleted = false
    reportProcess.running = true
  }

  function refreshAll() {
    refreshStatus()
    refreshReport()
  }

  function refreshProviderStatuses() {
    if (adapterStatusProcess.running) return
    _adapterStatusStderr = ""
    _adapterStatusParsed = null
    _adapterStatusParseError = ""
    _adapterStatusCompleted = false
    adapterStatusProcess.running = true
  }

  function redeemFlex(target) {
    if (flexProcess.running || !target) return
    flexBusy = true
    flexMessage = ""
    flexError = ""
    _flexOutput = ""
    _flexStderr = ""
    flexProcess.command = [root.sundownCommand, "flex", "redeem", String(target)]
    flexProcess.running = true
  }

  function syncEvercount() {
    if (evercountSyncProcess.running
        || !PrerequisiteAdapter.providerManualSync(adapterStatus, "evercount")) return
    evercountSyncBusy = true
    evercountSyncMessage = ""
    evercountSyncError = ""
    _evercountSyncOutput = ""
    _evercountSyncStderr = ""
    evercountSyncProcess.running = true
  }

  function compatibilityMessage(issue, fallback) {
    if (issue === "core-too-old") return qsTr("Update the Sundown core to use this panel")
    if (issue === "plugin-too-old") return qsTr("Update the Sundown Omarchy plugin")
    return fallback
  }

  function adapterStatusFailure(stderr) {
    const message = String(stderr || "")
    if (message.indexOf("unknown command \"adapters\"") >= 0)
      return qsTr("Update Sundown to load prerequisite provider status")
    return qsTr("Could not load prerequisite provider status")
  }

  Process {
    id: statusProcess
    command: [root.sundownCommand, "status", "--json"]
    onRunningChanged: {
      if (!running && !root._statusCompleted) {
        root._statusCompleted = true
        root.statusKnown = true
        if (!root.everLoaded) root.available = false
        root.statusError = root.everLoaded
          ? qsTr("Could not refresh status; showing the last update")
          : qsTr("Sundown is not available")
      }
    }
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
          root.refreshProviderStatuses()
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
      root._statusCompleted = true
      root.statusKnown = true
      if (exitCode === 0 && root._statusOutput !== "") return
      if (!root.everLoaded) root.available = false
      root.statusError = root._statusStderr || (root.everLoaded
        ? qsTr("Could not refresh status; showing the last update")
        : qsTr("Sundown is not available"))
    }
  }

  Process {
    id: adapterStatusProcess
    command: root.adapterStatusCommand
    onRunningChanged: {
      if (!running && !root._adapterStatusCompleted) {
        root._adapterStatusCompleted = true
        root.adapterStatusKnown = true
        root.adapterStatusError = qsTr("Could not load prerequisite provider status")
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const parsed = PrerequisiteAdapter.parseAggregateStatus(text)
        root._adapterStatusParsed = parsed.ok ? parsed.data : null
        root._adapterStatusParseError = parsed.ok ? "" : parsed.error
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._adapterStatusStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root._adapterStatusCompleted = true
      root.adapterStatusKnown = true
      if (exitCode === 0 && root._adapterStatusParsed !== null) {
        root.adapterStatus = root._adapterStatusParsed
        root.adapterStatusError = ""
        return
      }
      root.adapterStatusError = exitCode === 0 && root._adapterStatusParseError !== ""
        ? root._adapterStatusParseError
        : root.adapterStatusFailure(root._adapterStatusStderr)
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
    id: evercountSyncProcess
    command: [root.evercountCommand, "sync"]
    onRunningChanged: {
      if (!running && root.evercountSyncBusy) {
        root.evercountSyncBusy = false
        root.evercountSyncError = qsTr("Could not start the Evercount adapter")
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._evercountSyncOutput = String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._evercountSyncStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.evercountSyncBusy = false
      if (exitCode === 0) {
        root.evercountSyncMessage = qsTr("Evercount synced")
        root.refreshAll()
        root.refreshProviderStatuses()
      } else {
        root.evercountSyncError = root._evercountSyncStderr
          || qsTr("Could not sync Evercount")
      }
    }
  }

  Process {
    id: reportProcess
    command: [root.sundownCommand, "report", "week", "--json"]
    onRunningChanged: {
      if (!running && !root._reportCompleted) {
        root._reportCompleted = true
        root.reportKnown = true
        root.reportError = qsTr("Could not load Screen Time history")
      }
    }
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
      root._reportCompleted = true
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
