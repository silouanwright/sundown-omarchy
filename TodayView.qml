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
  property var dayWindow: ({ ratio: 0, remaining: 0 })
  property bool browserAttention: false
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property bool flexVisible: flexSection.visible
  readonly property bool flexCursorActive: flexSection.cursorActive

  signal redeem(string target)

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(14)

  function clockLabel(value) {
    const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ""))
    if (!match) return String(value || "")
    const date = new Date(2000, 0, 1, Number(match[1]), Number(match[2]))
    return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function resetCursor() { flexSection.resetCursor() }
  function moveCursor(delta) { if (flexSection.visible) flexSection.moveCursor(delta) }
  function activateCursor() {
    if (flexSection.visible && flexSection.cursorActive) flexSection.activateCursor()
  }
  function cursorItem() { return flexSection.visible ? flexSection.cursorItem() : null }

  PolicyProgressRow {
    visible: root.controller.statusKnown && root.controller.statusCompatibility === ""
    label: qsTr("Usable day")
    value: qsTr("%1–%2")
      .arg(root.clockLabel(root.controller.status.curfew.end))
      .arg(root.clockLabel(root.controller.status.curfew.start))
    detail: root.controller.status.curfew.active
      ? qsTr("Curfew is active")
      : qsTr("%1 until curfew").arg(Model.formatCountdown(root.dayWindow.remaining))
    ratio: root.dayWindow.ratio
    complete: root.controller.status.curfew.active && root.dayWindow.ratio >= 1
    active: !root.controller.status.curfew.active
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
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
      value: !modelData.synchronized ? qsTr("Syncing")
        : modelData.satisfied ? qsTr("Completed")
        : modelData.kind === "count"
          ? qsTr("%1 left").arg(modelData.remaining)
          : qsTr("%1 left").arg(Model.formatDuration(modelData.remaining))
      detail: !modelData.synchronized
        ? qsTr("Checking today's activity")
        : modelData.satisfied
          ? qsTr("%1 unlocked").arg(modelData.targets)
          : qsTr("Unlocks %1").arg(modelData.targets)
      ratio: modelData.ratio
      complete: modelData.satisfied
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
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
