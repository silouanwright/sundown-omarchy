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
  property real weekMaximum: 0
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(14)

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
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.controller.reportKnown
        ? Model.formatDuration(Model.reportTotal(root.controller.report)) : qsTr("Loading…")
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  WeekChart {
    visible: root.weekRows.length > 0
    width: parent.width
    rows: root.weekRows
    maximum: root.weekMaximum
    currentDate: root.controller.report.end_date
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.controller.reportKnown && root.controller.reportError === ""
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
    visible: root.controller.reportKnown && root.categories.length > 0
    text: qsTr("BREAKDOWN")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.controller.reportKnown ? root.categories : []

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

  Text {
    visible: root.controller.reportError !== ""
    width: parent.width
    text: root.controller.reportError
    textFormat: Text.PlainText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
  }
}
