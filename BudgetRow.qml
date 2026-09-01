import QtQuick
import qs.Commons
import "Model.js" as Model

Column {
  id: root

  required property var modelData
  property color foreground: Color.popups.text
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  property string fontFamily: Style.font.family
  readonly property string metaText: {
    const parts = []
    if (modelData.pace) {
      parts.push(qsTr("%1 / %2 today")
        .arg(Model.formatDuration(modelData.used))
        .arg(Model.formatDuration(modelData.limit)))
      parts.push(qsTr("%1 window").arg(Model.formatDuration(modelData.pace.window_seconds)))
    }
    if (modelData.earnedBank > 0)
      parts.push(qsTr("%1 earned").arg(Model.formatDuration(modelData.earnedBank)))
    if (modelData.flexRemaining > 0)
      parts.push(qsTr("%1 flex").arg(Model.formatDuration(modelData.flexRemaining)))
    return parts.join(qsTr(" · "))
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(5)

  function timeLabel(value) {
    const date = new Date(String(value || ""))
    return isNaN(date.getTime()) ? "" : date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function timingHint() {
    if (modelData.blockedBy === "schedule" && modelData.schedule)
      return qsTr("Opens %1").arg(timeLabel(modelData.schedule.next_change_at))
    if (modelData.blockedBy === "pace-limit" && modelData.pace && modelData.pace.next_refill_at) {
      const minutes = Model.minutesUntil(modelData.pace.next_refill_at)
      if (minutes === null) return ""
      if (minutes === 0) return qsTr("Returns now")
      return qsTr("Returns in %1m · %2")
        .arg(minutes)
        .arg(timeLabel(modelData.pace.next_refill_at))
    }
    if (modelData.schedule && modelData.schedule.allowed)
      return qsTr("Closes %1").arg(timeLabel(modelData.schedule.next_change_at))
    if (modelData.warningMinutes !== null)
      return qsTr("Warn at %1m").arg(modelData.warningMinutes)
    return ""
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(budgetLabel.implicitHeight, budgetTime.implicitHeight)

    Text {
      id: budgetLabel
      anchors.left: parent.left
      anchors.right: budgetTime.left
      anchors.rightMargin: Style.space(8)
      text: root.modelData.label + (root.modelData.active ? qsTr(" · active") : "")
      textFormat: Text.PlainText
      color: root.modelData.blocked ? Color.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.modelData.active || root.modelData.blocked
      elide: Text.ElideRight
    }

    Text {
      id: budgetTime
      anchors.right: parent.right
      text: root.modelData.restricted
        ? Model.formatDuration(root.modelData.meterUsed) + " / " + Model.formatDuration(root.modelData.meterLimit)
        : qsTr("%1 tracked").arg(Model.formatDuration(root.modelData.used))
      textFormat: Text.PlainText
      color: root.modelData.blocked ? Color.urgent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Rectangle {
    visible: root.modelData.restricted
    width: parent.width
    height: Style.space(5)
    radius: Style.cornerRadius > 0 ? height / 2 : 0
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    Accessible.ignored: true

    Rectangle {
      width: Math.round(parent.width * root.modelData.meterRatio)
      height: parent.height
      radius: parent.radius
      color: root.modelData.blocked ? Color.urgent
        : (root.modelData.active ? Color.accent
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62))
      Accessible.ignored: true
    }
  }

  Item {
    visible: root.modelData.restricted
    width: parent.width
    implicitHeight: Math.max(detailText.implicitHeight, timingText.implicitHeight)

    Text {
      id: detailText
      anchors.left: parent.left
      anchors.right: timingText.left
      anchors.rightMargin: Style.space(8)
      text: Model.budgetDetail(root.modelData)
      textFormat: Text.PlainText
      color: root.modelData.blocked ? Color.urgent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      id: timingText
      anchors.right: parent.right
      text: root.timingHint()
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    visible: root.modelData.restricted && root.metaText !== ""
    width: parent.width
    text: root.metaText
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
