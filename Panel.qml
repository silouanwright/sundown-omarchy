import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  readonly property color foreground: Color.popups.text
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property string fontFamily: Style.font.family
  readonly property var budgetRows: Model.budgetRows(controller.status)
  readonly property var weekRows: Model.weekRows(controller.report)
  readonly property real weekMaximum: Model.maximumDay(weekRows)
  readonly property bool attention: controller.statusKnown && (
    controller.status.curfew.active === true
    || controller.status.mode !== "enforce"
    || controller.status.runtime.support_level !== "enforcing"
    || controller.status.web.healthy !== true
    || budgetRows.some(function(row) { return row.reached })
  )

  function clockLabel(value) {
    var match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ""))
    if (!match) return String(value || "")
    var date = new Date(2000, 0, 1, Number(match[1]), Number(match[2]))
    return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function heroTitle() {
    if (!controller.statusKnown) return qsTr("Checking Sundown")
    if (controller.statusCompatibility === "core-too-old") return qsTr("Update Sundown")
    if (controller.statusCompatibility === "plugin-too-old") return qsTr("Update panel")
    if (!controller.available) return qsTr("Sundown unavailable")
    if (controller.status.mode !== "enforce") return qsTr("Observe mode")
    if (controller.status.curfew.active) return qsTr("Curfew active")
    if (controller.status.morning.active) return qsTr("Morning routine")
    return qsTr("Protection active")
  }

  function heroMeta() {
    if (!controller.statusKnown) return qsTr("Loading current policy")
    if (controller.statusCompatibility !== "") return controller.statusError
    if (!controller.available) return qsTr("The Sundown command could not be reached")
    return root.heroTitle()
  }

  function heroPill() {
    if (!controller.available) return ""
    if (controller.status.mode !== "enforce") return qsTr("OBSERVE")
    if (controller.status.curfew.active) return qsTr("NOW")
    if (controller.status.morning.active)
      return qsTr("UNTIL %1").arg(clockLabel(controller.status.morning.end))
    return Model.formatCountdown(controller.status.curfew.seconds_until_start)
  }

  function barTooltip() {
    if (!controller.statusKnown) return qsTr("Sundown is checking protection")
    if (!controller.available) return qsTr("Sundown is unavailable")
    if (controller.status.curfew.active)
      return qsTr("Sundown curfew is active until %1").arg(clockLabel(controller.status.curfew.end))
    if (controller.status.morning.active)
      return qsTr("Sundown morning routine is active until %1").arg(clockLabel(controller.status.morning.end))
    if (!controller.status.web.healthy) return qsTr("Sundown browser protection needs attention")
    return qsTr("Sundown curfew begins in %1").arg(Model.formatCountdown(controller.status.curfew.seconds_until_start))
  }

  moduleName: "io.github.silouanwright.sundown"
  ipcTarget: "sundown-panel"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    controller.panelOpen = opened
    if (opened) controller.refreshAll()
  }

  SundownController {
    id: controller
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖔"
    active: root.attention
    tooltipText: root.barTooltip()
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) controller.refreshAll()
      else root.toggle()
    }
  }

  Component {
    id: heroIcon
    Text {
      text: "󰖔"
      color: root.attention ? Color.urgent : Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") controller.refreshAll()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: content
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            iconComponent: heroIcon
            title: "Sundown"
            meta: root.heroMeta()
            detail: root.heroPill()
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            visible: controller.statusError !== "" && controller.statusCompatibility === ""
            width: parent.width
            text: controller.statusError
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            visible: controller.available
              && (!controller.status.web.healthy || !controller.status.web.enforcement_ready)
            width: parent.width
            text: qsTr("Browser protection needs attention")
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
              anchors.verticalCenter: parent.verticalCenter
              text: qsTr("TODAY")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              id: todayTotal
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Model.formatDuration(Model.totalToday(root.budgetRows)) + qsTr(" tracked")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Repeater {
            model: root.budgetRows

            Column {
              required property var modelData
              width: content.width
              spacing: Style.space(5)

              Item {
                width: parent.width
                implicitHeight: Math.max(budgetLabel.implicitHeight, budgetTime.implicitHeight)

                Text {
                  id: budgetLabel
                  anchors.left: parent.left
                  anchors.right: budgetTime.left
                  anchors.rightMargin: Style.space(8)
                  text: modelData.label + (modelData.active ? qsTr(" · active") : "")
                  textFormat: Text.PlainText
                  color: modelData.reached ? Color.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: modelData.active || modelData.reached
                  elide: Text.ElideRight
                }

                Text {
                  id: budgetTime
                  anchors.right: parent.right
                  text: Model.formatDuration(modelData.used) + " / " + Model.formatDuration(modelData.limit)
                  color: modelData.reached ? Color.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(5)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * modelData.ratio)
                  height: parent.height
                  radius: parent.radius
                  color: modelData.reached ? Color.urgent
                    : (modelData.active ? Color.accent
                      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62))
                }
              }

              Item {
                width: parent.width
                implicitHeight: Math.max(remainingText.implicitHeight, warningText.implicitHeight)

                Text {
                  id: remainingText
                  anchors.left: parent.left
                  anchors.right: warningText.left
                  anchors.rightMargin: Style.space(8)
                  text: modelData.reached ? qsTr("Blocked for today")
                    : qsTr("%1 remaining").arg(Model.formatDuration(modelData.remaining))
                  color: modelData.reached ? Color.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Text {
                  id: warningText
                  anchors.right: parent.right
                  text: modelData.warningMinutes === null ? ""
                    : qsTr("Warn at %1m left").arg(modelData.warningMinutes)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

            }
          }

          PanelSeparator { foreground: root.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(historyHeader.implicitHeight, historyTotal.implicitHeight)

            PanelSectionHeader {
              id: historyHeader
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: qsTr("LAST 7 DAYS")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              id: historyTotal
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: controller.reportKnown ? Model.formatDuration(Model.reportTotal(controller.report)) : qsTr("Loading…")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            id: weekChart
            visible: root.weekRows.length > 0
            width: parent.width
            height: Style.space(78)
            spacing: Style.space(6)

            Repeater {
              model: root.weekRows

              Item {
                required property var modelData
                width: Math.floor((weekChart.width - weekChart.spacing * 6) / 7)
                height: weekChart.height

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  text: modelData.recorded ? Model.formatDuration(modelData.seconds) : "—"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: dayLabel.top
                  anchors.bottomMargin: Style.space(5)
                  height: {
                    var available = parent.height - dayLabel.implicitHeight - Style.space(24)
                    if (!modelData.recorded) return Style.spacing.hairline
                    if (modelData.seconds <= 0) return Style.space(3)
                    return Math.max(Style.space(4), Math.round(available * modelData.seconds / root.weekMaximum))
                  }
                  radius: Style.cornerRadius > 0 ? Math.min(width, height) / 2 : 0
                  color: modelData.date === controller.report.end_date ? Color.accent
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, modelData.recorded ? 0.55 : 0.12)
                }

                Text {
                  id: dayLabel
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  text: modelData.label
                  color: modelData.date === controller.report.end_date ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: modelData.date === controller.report.end_date
                }
              }
            }
          }

          Text {
            visible: controller.reportKnown && controller.reportError === ""
            width: parent.width
            text: Model.recordedDaysLabel(controller.report.recorded_days)
              + qsTr(" · unrecorded days are unknown")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            visible: controller.reportError !== ""
            width: parent.width
            text: controller.reportError
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: qsTr("Press R to refresh · right-click the bar icon anytime")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
