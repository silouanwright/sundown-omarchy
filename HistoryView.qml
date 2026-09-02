pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root

  required property var controller
  property var weekRows: []
  property var categories: []
  property var flexAuditRows: []
  property real weekMaximum: 0
  property color foreground: Color.popups.text
  property color urgent: Color.urgent
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property string viewState: historyState.viewState
  readonly property bool showHistoryContent: historyState.showHistoryContent
  readonly property bool showRefreshStatus: historyState.showRefreshStatus
  readonly property string refreshStatusText: historyState.refreshStatusText
  readonly property string stateTitle: historyState.stateTitle
  readonly property string stateDetail: historyState.stateDetail

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(14)

  HistoryState {
    id: historyState
    reportEverLoaded: root.controller.reportEverLoaded
    reportBusy: root.controller.reportBusy
    reportError: root.controller.reportError
    recordedDays: Number(root.controller.report.recorded_days || 0)
  }

  function timeLabel(value) {
    const date = new Date(String(value || ""))
    return isNaN(date.getTime()) ? "" : date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(historyHeader.implicitHeight, historyTotal.implicitHeight)

    PanelSectionHeader {
      id: historyHeader
      anchors.left: parent.left
      anchors.right: historyTotal.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: qsTr("LAST 7 DAYS")
      elide: Text.ElideRight
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      id: historyTotal
      visible: root.showHistoryContent
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Model.formatDuration(Model.reportTotal(root.controller.report))
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    visible: root.showRefreshStatus
    width: parent.width
    text: root.refreshStatusText
    textFormat: Text.PlainText
    color: root.controller.reportError !== "" ? root.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
  }

  Column {
    visible: !root.showHistoryContent
    width: parent.width
    spacing: Style.space(4)

    Text {
      width: parent.width
      topPadding: Style.space(8)
      text: root.stateTitle
      textFormat: Text.PlainText
      color: root.viewState === "error" ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    Text {
      visible: root.stateDetail !== ""
      width: parent.width
      bottomPadding: Style.space(8)
      text: root.stateDetail
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }

  WeekChart {
    visible: root.showHistoryContent && root.weekRows.length > 0
    width: parent.width
    rows: root.weekRows
    maximum: root.weekMaximum
    currentDate: root.controller.report.end_date
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.showHistoryContent
    width: parent.width
    text: Model.recordedDaysLabel(root.controller.report.recorded_days)
      + qsTr(" · unrecorded days are unknown")
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
  }

  PanelSectionHeader {
    visible: root.showHistoryContent && root.categories.length > 0
    text: qsTr("BREAKDOWN")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.showHistoryContent ? root.categories : []

    Item {
      id: historyRow

      required property var modelData
      width: root.width
      implicitHeight: Math.max(historyCategoryLabel.implicitHeight, historyCategoryTime.implicitHeight)

      Text {
        id: historyCategoryLabel
        anchors.left: parent.left
        anchors.right: historyCategoryTime.left
        anchors.rightMargin: Style.space(8)
        text: historyRow.modelData.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: historyCategoryTime
        anchors.right: parent.right
        text: Model.formatDuration(historyRow.modelData.seconds)
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }

  PanelSeparator {
    visible: root.flexAuditRows.length > 0
    foreground: root.foreground
  }

  PanelSectionHeader {
    visible: root.flexAuditRows.length > 0
    text: qsTr("FLEX USED TODAY")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.flexAuditRows

    Item {
      id: flexAuditRow

      required property var modelData
      width: root.width
      implicitHeight: Math.max(flexAuditLabel.implicitHeight, flexAuditTime.implicitHeight)

      Text {
        id: flexAuditLabel
        anchors.left: parent.left
        anchors.right: flexAuditTime.left
        anchors.rightMargin: Style.space(8)
        text: qsTr("%1 → %2")
          .arg(Model.formatDuration(flexAuditRow.modelData.seconds))
          .arg(flexAuditRow.modelData.label)
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        id: flexAuditTime
        anchors.right: parent.right
        text: root.timeLabel(flexAuditRow.modelData.redeemedAt)
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

}
