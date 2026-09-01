pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "Model.js" as Model

Column {
  id: root

  required property var rows
  required property real maximum
  required property string currentDate
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property real cellSpacing: Style.space(6)
  readonly property real cellWidth: Math.floor((width - cellSpacing * 6) / 7)
  readonly property real columnWidth: Math.min(cellWidth - Style.space(8),
    Math.max(Style.space(20), Math.round(cellWidth * 0.46)))
  readonly property real plotHeight: Style.space(58)

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(7)

  Item {
    id: plot

    width: parent.width
    height: root.plotHeight

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Style.spacing.hairline
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
      Accessible.ignored: true
    }

    Row {
      anchors.fill: parent
      spacing: root.cellSpacing

      Repeater {
        model: root.rows

        Item {
          id: columnCell

          required property var modelData
          width: root.cellWidth
          height: plot.height

          Text {
            id: valueLabel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: columnCell.modelData.recorded
              ? Model.formatDuration(columnCell.modelData.seconds) : "—"
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Item {
            id: usageColumn

            visible: columnCell.modelData.recorded
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.columnWidth
            height: {
              const available = parent.height - valueLabel.implicitHeight - Style.space(8)
              if (columnCell.modelData.seconds <= 0) return Style.space(2)
              return Math.max(Style.space(3),
                Math.round(available * columnCell.modelData.seconds / Math.max(1, root.maximum)))
            }
            readonly property real topRadius: Style.cornerRadius > 0
              ? Math.min(Style.space(4), width / 2, height) : 0
            readonly property color fillColor: columnCell.modelData.date === root.currentDate ? Color.accent
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
            Accessible.ignored: true

            Rectangle {
              anchors.fill: parent
              radius: usageColumn.topRadius
              color: usageColumn.fillColor
              Accessible.ignored: true
            }

            Rectangle {
              visible: usageColumn.topRadius > 0
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Math.min(usageColumn.topRadius, parent.height / 2)
              color: usageColumn.fillColor
              Accessible.ignored: true
            }
          }
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: root.cellSpacing

    Repeater {
      model: root.rows

      Text {
        id: dayLabel

        required property var modelData
        width: root.cellWidth
        text: dayLabel.modelData.label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        color: dayLabel.modelData.date === root.currentDate ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: dayLabel.modelData.date === root.currentDate
      }
    }
  }
}
