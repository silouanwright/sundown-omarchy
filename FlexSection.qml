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
  readonly property var flex: status && status.flex ? status.flex : Model.emptyStatus().flex
  property int cursorIndex: 0
  property bool cursorActive: false
  property bool expanded: false
  readonly property int actionCount: expanded ? targets.length + 1 : 1

  signal redeem(string target)

  function moveCursor(direction) {
    if (!cursorActive) {
      cursorActive = true
      cursorIndex = direction < 0 ? actionCount - 1 : 0
      return
    }
    cursorIndex = Math.max(0, Math.min(actionCount - 1, cursorIndex + direction))
  }

  function activateCursor() {
    if (!cursorActive || cursorIndex < 0 || cursorIndex >= actionCount) return
    if (cursorIndex === 0) {
      toggleExpanded()
      return
    }
    chooseTarget(targets[cursorIndex - 1].target)
  }

  function toggleExpanded() {
    if (busy || (flex.remaining_uses || 0) <= 0 || targets.length === 0) return
    expanded = !expanded
    cursorActive = true
    cursorIndex = expanded ? 1 : 0
  }

  function chooseTarget(target) {
    if (busy || (flex.remaining_uses || 0) <= 0) return
    expanded = false
    cursorIndex = 0
    redeem(target)
  }

  function cursorItem() {
    if (cursorIndex === 0) return flexButton
    return cursorIndex > 0 && cursorIndex < actionCount
      ? flexRepeater.itemAt(cursorIndex - 1) : null
  }

  function resetCursor() {
    expanded = false
    cursorActive = false
    cursorIndex = 0
  }

  function clampCursor() {
    if (targets.length === 0) {
      expanded = false
      cursorIndex = 0
      return
    }
    cursorIndex = Math.max(0, Math.min(actionCount - 1, cursorIndex))
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
      anchors.right: balance.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: qsTr("FLEX PASS")
      elide: Text.ElideRight
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

  Button {
    id: flexButton

    width: root.width
    text: (root.flex.remaining_uses || 0) > 0 ? qsTr("Use flex pass") : qsTr("Flex pass used today")
    bordered: true
    hasCursor: root.cursorActive && root.cursorIndex === 0
    enabled: !root.busy && (root.flex.remaining_uses || 0) > 0 && root.targets.length > 0
    foreground: root.foreground
    fontFamily: root.fontFamily
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: root.expanded ? qsTr("Hide eligible targets") : qsTr("Show eligible targets")
    onHovered: function(isHovered) {
      if (isHovered) {
        root.cursorActive = true
        root.cursorIndex = 0
      }
    }
    onClicked: root.toggleExpanded()
  }

  Column {
    visible: root.expanded
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
        hasCursor: root.cursorActive && index + 1 === root.cursorIndex
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
            root.cursorIndex = flexRow.index + 1
          }
          onClicked: root.chooseTarget(flexRow.modelData.target)
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
