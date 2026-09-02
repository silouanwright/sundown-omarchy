import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  property string label: ""
  property string value: ""
  property string detail: ""
  property real ratio: 0
  property bool complete: false
  property bool active: false
  property bool actionVisible: false
  property bool actionBusy: false
  property string actionTooltip: ""
  property string actionStatus: ""
  property bool actionStatusUrgent: false
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family

  signal actionTriggered()

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(5)

  Item {
    width: parent.width
    implicitHeight: Math.max(title.implicitHeight, amount.implicitHeight,
      actionButton.visible ? actionButton.implicitHeight : 0)

    Text {
      id: title
      anchors.left: actionButton.visible ? actionButton.right : parent.left
      anchors.leftMargin: actionButton.visible ? Style.space(6) : 0
      anchors.right: amount.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.active
      elide: Text.ElideRight
    }

    Text {
      id: amount
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.value
      textFormat: Text.PlainText
      color: root.complete ? Color.accent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.complete
    }

    PanelActionButton {
      id: actionButton
      visible: root.actionVisible
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      iconText: "󰑐"
      tooltipText: root.actionTooltip
      enabled: !root.actionBusy
      focusable: true
      bordered: true
      foreground: root.dim
      hoverColor: Color.accent
      fontFamily: root.fontFamily
      Accessible.role: Accessible.Button
      Accessible.name: root.actionTooltip
      onClicked: root.actionTriggered()

      RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 800
        loops: Animation.Infinite
        running: root.actionBusy && actionButton.visible
      }
    }
  }

  Rectangle {
    width: parent.width
    height: Style.space(4)
    radius: Style.cornerRadius > 0 ? height / 2 : 0
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    Accessible.ignored: true

    Rectangle {
      width: Math.round(parent.width * Math.max(0, Math.min(1, root.ratio)))
      height: parent.height
      radius: parent.radius
      color: root.complete || root.active ? Color.accent
        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62)
      Accessible.ignored: true
    }
  }

  Text {
    width: parent.width
    text: root.detail
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    visible: root.actionStatus !== ""
    width: parent.width
    text: root.actionStatus
    textFormat: Text.PlainText
    color: root.actionStatusUrgent ? Color.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
