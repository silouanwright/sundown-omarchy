pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root

  property var status: Model.emptyStatus()
  property bool busy: false
  property string message: ""
  property string error: ""
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property var targets: Model.flexTargets(status)
  readonly property var auditRows: Model.flexAuditRows(status)
  readonly property var flex: status && status.flex ? status.flex : Model.emptyStatus().flex
  property int cursorIndex: 0
  property bool cursorActive: false

  signal redeem(string target)

  function moveCursor(direction) {
    if (targets.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      cursorIndex = direction < 0 ? targets.length - 1 : 0
      return
    }
    cursorIndex = Math.max(0, Math.min(targets.length - 1, cursorIndex + direction))
  }

  function activateCursor() {
    if (!cursorActive || cursorIndex < 0 || cursorIndex >= targets.length
        || busy || (flex.remaining_uses || 0) <= 0) return
    redeem(targets[cursorIndex].target)
  }

  function cursorItem() {
    return cursorIndex >= 0 && cursorIndex < targets.length
      ? flexRepeater.itemAt(cursorIndex) : null
  }

  function resetCursor() {
    cursorActive = false
    cursorIndex = 0
  }

  function timeLabel(value) {
    const date = new Date(String(value || ""))
    return isNaN(date.getTime()) ? "" : date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function clampCursor() {
    if (targets.length === 0) {
      resetCursor()
      return
    }
    cursorIndex = Math.max(0, Math.min(targets.length - 1, cursorIndex))
  }

  visible: flex.enabled === true
  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)
  onTargetsChanged: clampCursor()

  Item {
    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, balance.implicitHeight)

    PanelSectionHeader {
      id: header
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: qsTr("FLEX PASS")
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      id: balance
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: qsTr("%1 left · %2 each")
        .arg(root.flex.remaining_uses || 0)
        .arg(Model.formatDuration(root.flex.pass_seconds || 0))
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(6)

    Repeater {
      id: flexRepeater
      model: root.targets

      CursorSurface {
        id: flexRow

        required property var modelData
        required property int index
        readonly property string actionLabel: qsTr("Add %1 to %2")
          .arg(Model.formatDuration(root.flex.pass_seconds || 0))
          .arg(modelData.label)

        width: root.width
        implicitHeight: Style.space(40)
        hasCursor: root.cursorActive && index === root.cursorIndex
        bordered: true
        enabled: !root.busy && (root.flex.remaining_uses || 0) > 0
        foreground: root.foreground
        Accessible.role: Accessible.Button
        Accessible.name: actionLabel

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          enabled: flexRow.enabled
          cursorShape: flexRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onEntered: {
            root.cursorActive = true
            root.cursorIndex = flexRow.index
          }
          onClicked: root.redeem(flexRow.modelData.target)
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: flexRow.actionLabel
            textFormat: Text.PlainText
            color: flexRow.enabled ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: "󰄬"
            textFormat: Text.PlainText
            color: flexRow.enabled ? Color.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
            Layout.alignment: Qt.AlignVCenter
            Accessible.ignored: true
          }
        }
      }
    }
  }

  Column {
    visible: root.auditRows.length > 0
    width: parent.width
    spacing: Style.space(5)

    PanelSectionHeader {
      text: qsTr("USED TODAY")
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Repeater {
      model: root.auditRows

      Item {
        required property var modelData
        width: root.width
        implicitHeight: Math.max(auditLabel.implicitHeight, auditTime.implicitHeight)

        Text {
          id: auditLabel
          anchors.left: parent.left
          anchors.right: auditTime.left
          anchors.rightMargin: Style.space(8)
          text: qsTr("%1 → %2").arg(Model.formatDuration(modelData.seconds)).arg(modelData.label)
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: auditTime
          anchors.right: parent.right
          text: root.timeLabel(modelData.redeemedAt)
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Text {
    visible: root.busy || root.message !== "" || root.error !== ""
    width: parent.width
    text: root.busy ? qsTr("Redeeming flex pass…")
      : root.error !== "" ? root.error : root.message
    textFormat: Text.PlainText
    color: root.error !== "" ? Color.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
