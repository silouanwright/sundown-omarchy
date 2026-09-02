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
  property var earnedRows: []
  property bool browserAttention: false
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property bool flexVisible: flexSection.visible
  readonly property bool flexCursorActive: flexSection.cursorActive
  readonly property bool evercountSyncVisible: root.gateRows.some(function(gate) {
    return gate.provider === "evercount"
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

  function gateValue(gate) {
    if (!gate.synchronized) return qsTr("Syncing")
    if (gate.kind === "count") {
      const unit = gate.required === 1 ? qsTr("entry") : qsTr("entries")
      return qsTr("%1 / %2 %3").arg(gate.used).arg(gate.required).arg(unit)
    }
    return qsTr("%1 / %2")
      .arg(Model.formatDuration(gate.used))
      .arg(Model.formatDuration(gate.required))
  }

  function gateDetail(gate) {
    if (!gate.synchronized) return qsTr("Checking today's activity")
    if (gate.satisfied)
      return qsTr("Completed · Unlocked: %1").arg(gate.targets)
    if (gate.kind === "count") {
      const unit = gate.remaining === 1 ? qsTr("entry") : qsTr("entries")
      return qsTr("%1 %2 left · Unlocks: %3")
        .arg(gate.remaining).arg(unit).arg(gate.targets)
    }
    return qsTr("%1 left · Unlocks: %2")
      .arg(Model.formatDuration(gate.remaining)).arg(gate.targets)
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
    visible: root.gateRows.length > 0
    foreground: root.foreground
  }

  PanelSectionHeader {
    visible: root.gateRows.length > 0
    text: qsTr("PREREQUISITES")
    foreground: root.foreground
    fontFamily: root.fontFamily
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
      complete: modelData.satisfied
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
    }
  }

  Button {
    visible: root.evercountSyncVisible
    width: root.width
    text: root.controller.evercountSyncBusy
      ? qsTr("Syncing Evercount…")
      : (root.controller.evercountSyncError !== ""
        ? qsTr("Retry Evercount sync")
        : qsTr("Sync Evercount"))
    iconText: "󰑐"
    iconSpinning: root.controller.evercountSyncBusy
    enabled: !root.controller.evercountSyncBusy
    focusable: true
    bordered: true
    foreground: root.foreground
    accent: Color.accent
    fontFamily: root.fontFamily
    Accessible.role: Accessible.Button
    Accessible.name: text
    onClicked: root.requestEvercountSync()
  }

  Text {
    visible: root.evercountSyncVisible
      && (root.controller.evercountSyncError !== ""
        || root.controller.evercountSyncMessage !== "")
    width: parent.width
    text: root.controller.evercountSyncError !== ""
      ? root.controller.evercountSyncError
      : root.controller.evercountSyncMessage
    textFormat: Text.PlainText
    color: root.controller.evercountSyncError !== "" ? Color.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
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
