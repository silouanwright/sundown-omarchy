pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root

  required property var controller
  property var budgetRows: []
  property var gateRows: []
  property var providerRows: []
  property var earnedRows: []
  property bool browserAttention: false
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property bool flexVisible: flexSection.visible
  readonly property bool flexCursorActive: flexSection.cursorActive
  readonly property bool evercountSyncVisible: root.providerRows.some(function(provider) {
    return provider.id === "evercount" && provider.manualSync
  })
  readonly property bool hasProviderPrerequisites: root.gateRows.some(function(gate) {
    return String(gate.provider || "") !== ""
  })

  signal redeem(string target)
  signal syncEvercount()

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(14)

  function resetCursor() { flexSection.resetCursor() }
  function moveCursor(delta) { if (flexSection.visible) flexSection.moveCursor(delta) }
  function activateCursor() {
    if (flexSection.visible && flexSection.cursorActive) flexSection.activateCursor()
  }
  function cursorItem() { return flexSection.visible ? flexSection.cursorItem() : null }
  function requestEvercountSync() {
    if (root.evercountSyncVisible && !root.controller.evercountSyncBusy)
      root.syncEvercount()
  }

  function providerManualSync(providerId) {
    return root.providerRows.some(function(provider) {
      return provider.id === providerId && provider.manualSync === true
    })
  }

  function metricNumber(value) {
    const numeric = Number(value)
    if (!isFinite(numeric)) return "0"
    if (Math.round(numeric) === numeric) return String(numeric)
    return numeric.toFixed(2).replace(/\.?0+$/, "")
  }

  function gateValue(gate) {
    if (!gate.synchronized) return qsTr("Syncing")
    if (gate.metricUnit === "seconds" || gate.kind === "duration")
      return qsTr("%1 / %2")
        .arg(Model.formatDuration(gate.used))
        .arg(Model.formatDuration(gate.required))
    const unit = gate.metricUnit === "provider_units"
      ? qsTr("units")
      : (gate.required === 1 ? qsTr("completion") : qsTr("completions"))
    return qsTr("%1 / %2 %3")
      .arg(metricNumber(gate.used)).arg(metricNumber(gate.required)).arg(unit)
  }

  function gateDetail(gate) {
    if (!gate.synchronized) return qsTr("Checking today's activity")
    if (gate.satisfied) {
      const details = []
      if (gate.unlockedTargets)
        details.push(qsTr("Unlocked: %1").arg(gate.unlockedTargets))
      if (gate.waitingTargets)
        details.push(qsTr("Waiting on another prerequisite: %1").arg(gate.waitingTargets))
      return details.length > 0 ? qsTr("Completed · %1").arg(details.join(qsTr(" · ")))
        : qsTr("Completed")
    }
    if (gate.metricUnit !== "seconds" && gate.kind !== "duration") {
      const unit = gate.metricUnit === "provider_units"
        ? (gate.remaining === 1 ? qsTr("unit") : qsTr("units"))
        : (gate.remaining === 1 ? qsTr("completion") : qsTr("completions"))
      return qsTr("%1 %2 left · Required for: %3")
        .arg(metricNumber(gate.remaining)).arg(unit).arg(gate.targets)
    }
    return qsTr("%1 left · Required for: %2")
      .arg(Model.formatDuration(gate.remaining)).arg(gate.targets)
  }

  function clockLabel(value) {
    const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ""))
    if (!match) return String(value || "")
    const date = new Date(2000, 0, 1, Number(match[1]), Number(match[2]))
    return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function curfewValue() {
    const curfew = root.controller.status.curfew || {}
    if (curfew.active) return qsTr("Active")
    if (curfew.seconds_until_start !== null && curfew.seconds_until_start !== undefined)
      return qsTr("In %1").arg(Model.formatCountdown(curfew.seconds_until_start))
    return qsTr("Scheduled")
  }

  function curfewDetail() {
    const curfew = root.controller.status.curfew || {}
    if (curfew.active) return qsTr("Active until %1").arg(clockLabel(curfew.end))
    return qsTr("Available %1–%2").arg(clockLabel(curfew.end)).arg(clockLabel(curfew.start))
  }

  function providerHealth(provider) {
    if (provider.health === "healthy") return qsTr("Healthy")
    if (provider.health === "never_synchronized") return qsTr("Not synced")
    if (provider.health === "unavailable") return qsTr("Unavailable")
    if (provider.health === "incompatible") return qsTr("Needs update")
    if (provider.health === "inactive") return qsTr("Inactive")
    return qsTr("Unknown")
  }

  function providerDetail(provider) {
    const parts = []
    const lastSync = new Date(String(provider.lastSyncAt || ""))
    if (!isNaN(lastSync.getTime()))
      parts.push(qsTr("Last sync %1").arg(lastSync.toLocaleString(Qt.locale(), Locale.ShortFormat)))
    else
      parts.push(qsTr("No successful sync recorded"))
    const lastRead = new Date(String(provider.lastReadAt || ""))
    if (isNaN(lastSync.getTime()) && !isNaN(lastRead.getTime()))
      parts.push(qsTr("Last provider read %1")
        .arg(lastRead.toLocaleString(Qt.locale(), Locale.ShortFormat)))
    if (provider.errorMessage) parts.push(provider.errorMessage)
    if (provider.errorAction) parts.push(provider.errorAction)
    return parts.join(qsTr(" · "))
  }

  Text {
    visible: root.controller.statusError !== "" && root.controller.statusCompatibility === ""
    width: parent.width
    text: root.controller.statusError
    textFormat: Text.PlainText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    visible: root.controller.available && root.browserAttention
    width: parent.width
    text: qsTr("Browser protection needs attention")
    textFormat: Text.PlainText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.WordWrap
  }

  Text {
    visible: root.controller.available && root.controller.status.apps.groups.length > 0
      && !root.controller.status.apps.healthy
    width: parent.width
    text: qsTr("Application tracking needs attention")
    textFormat: Text.PlainText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.WordWrap
  }

  PanelSeparator { foreground: root.foreground }

  Item {
    width: parent.width
    implicitHeight: Math.max(todayHeader.implicitHeight, todayTotal.implicitHeight)

    PanelSectionHeader {
      id: todayHeader
      anchors.left: parent.left
      anchors.right: todayTotal.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: qsTr("TODAY")
      elide: Text.ElideRight
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      id: todayTotal
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Model.formatDuration(Model.totalToday(root.budgetRows)) + qsTr(" tracked")
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Repeater {
    model: root.budgetRows

    BudgetRow {
      width: root.width
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
    }
  }

  PanelSeparator {
    visible: root.controller.available
    foreground: root.foreground
  }

  PanelSectionHeader {
    visible: root.controller.available
    text: qsTr("CURFEW")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  StatusRow {
    visible: root.controller.available
    width: root.width
    label: qsTr("Daily curfew")
    value: root.curfewValue()
    detail: root.curfewDetail()
    urgent: root.controller.status.curfew.active === true
    foreground: root.foreground
    dim: root.dim
    positiveColor: Color.accent
    urgentColor: Color.urgent
    fontFamily: root.fontFamily
    rowSpacing: Style.space(3)
    labelGap: Style.space(8)
    bodyFontSize: Style.font.body
    captionFontSize: Style.font.caption
  }

  PanelSeparator {
    visible: root.gateRows.length > 0
    foreground: root.foreground
  }

  PanelSectionHeader {
    visible: root.gateRows.length > 0
    text: qsTr("PREREQUISITES")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.hasProviderPrerequisites && root.controller.adapterStatusKnown
      && root.controller.adapterStatusError !== ""
    width: parent.width
    text: root.controller.adapterStatusError
    textFormat: Text.PlainText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.gateRows

    PolicyProgressRow {
      required property var modelData
      width: root.width
      label: modelData.source
      value: root.gateValue(modelData)
      detail: root.gateDetail(modelData)
      ratio: modelData.ratio
      complete: modelData.passed === true
      actionVisible: modelData.provider === "evercount"
        && root.providerManualSync(modelData.provider)
      actionBusy: actionVisible && root.controller.evercountSyncBusy
      actionTooltip: root.controller.evercountSyncBusy
        ? qsTr("Syncing Evercount")
        : (root.controller.evercountSyncError !== ""
          ? qsTr("Retry Evercount sync")
          : qsTr("Sync Evercount"))
      actionStatus: actionVisible
        ? (root.controller.evercountSyncError || root.controller.evercountSyncMessage)
        : ""
      actionStatusUrgent: root.controller.evercountSyncError !== ""
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
      onActionTriggered: root.requestEvercountSync()
    }
  }

  PanelSectionHeader {
    visible: root.providerRows.length > 0
    text: qsTr("PROVIDER STATUS")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.providerRows

    StatusRow {
      required property var modelData
      width: root.width
      label: modelData.label
      value: root.providerHealth(modelData)
      detail: root.providerDetail(modelData)
      positive: modelData.health === "healthy"
      urgent: modelData.health === "unavailable" || modelData.health === "incompatible"
      foreground: root.foreground
      dim: root.dim
      positiveColor: Color.accent
      urgentColor: Color.urgent
      fontFamily: root.fontFamily
      rowSpacing: Style.space(3)
      labelGap: Style.space(8)
      bodyFontSize: Style.font.body
      captionFontSize: Style.font.caption
    }
  }

  PanelSeparator {
    visible: root.earnedRows.length > 0
    foreground: root.foreground
  }

  PanelSectionHeader {
    visible: root.earnedRows.length > 0
    text: qsTr("EARNED TIME")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.earnedRows

    PolicyProgressRow {
      required property var modelData
      width: root.width
      label: qsTr("%1 → %2").arg(modelData.source).arg(modelData.target)
      value: qsTr("%1 / %2").arg(Model.formatDuration(modelData.bank)).arg(Model.formatDuration(modelData.cap))
      detail: modelData.suppressed ? qsTr("Paused while the target is active")
        : modelData.earning ? qsTr("Earning now") : qsTr("Reward bank")
      ratio: modelData.ratio
      active: modelData.earning
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
    }
  }

  PanelSeparator {
    visible: flexSection.visible
    foreground: root.foreground
  }

  FlexSection {
    id: flexSection
    width: root.width
    status: root.controller.status
    busy: root.controller.flexBusy
    message: root.controller.flexMessage
    error: root.controller.flexError
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
    onRedeem: function(target) { root.redeem(target) }
  }
}
