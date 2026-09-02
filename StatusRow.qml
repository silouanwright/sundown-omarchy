import QtQuick

Column {
  id: root

  property string label: ""
  property string value: ""
  property string detail: ""
  property bool positive: false
  property bool urgent: false
  required property color foreground
  required property color dim
  required property color positiveColor
  required property color urgentColor
  required property string fontFamily
  required property real rowSpacing
  required property real labelGap
  required property real bodyFontSize
  required property real captionFontSize

  width: parent ? parent.width : implicitWidth
  spacing: root.rowSpacing

  Item {
    width: parent.width
    implicitHeight: Math.max(statusLabel.implicitHeight, statusValue.implicitHeight)

    Text {
      id: statusLabel
      text: root.label
      textFormat: Text.PlainText
      color: root.foreground
      elide: Text.ElideRight
      anchors {
        left: parent.left
        right: statusValue.left
        rightMargin: root.labelGap
      }
      font {
        family: root.fontFamily
        pixelSize: root.bodyFontSize
      }
    }

    Text {
      id: statusValue
      anchors.right: parent.right
      text: root.value
      textFormat: Text.PlainText
      color: root.urgent ? root.urgentColor : (root.positive ? root.positiveColor : root.dim)
      font {
        family: root.fontFamily
        pixelSize: root.bodyFontSize
        bold: root.urgent || root.positive
      }
    }
  }

  Text {
    visible: root.detail !== ""
    width: parent.width
    text: root.detail
    textFormat: Text.PlainText
    color: root.urgent ? root.urgentColor : root.dim
    font.family: root.fontFamily
    font.pixelSize: root.captionFontSize
    wrapMode: Text.WordWrap
  }
}
