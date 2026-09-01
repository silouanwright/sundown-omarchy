pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  readonly property color foreground: Color.popups.text
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property string fontFamily: Style.font.family
  readonly property var budgetRows: Model.budgetRows(controller.status)
  readonly property var gateRows: Model.gateRows(controller.status)
  readonly property var earnedRows: Model.earnedRows(controller.status)
  readonly property var weekRows: Model.weekRows(controller.report)
  readonly property var historyCategories: Model.reportCategories(controller.report, controller.status)
  readonly property var dayWindow: Model.dayWindow(controller.status)
  readonly property real weekMaximum: Model.maximumDay(weekRows)
  readonly property bool browserAttention: controller.statusKnown
    && Model.browserNeedsAttention(controller.status)
  readonly property bool attention: controller.statusKnown && (
    controller.status.curfew.active === true
    || controller.status.mode !== "enforce"
    || controller.status.runtime.support_level !== "enforcing"
    || root.browserAttention
    || (controller.status.apps.groups.length > 0 && controller.status.apps.healthy !== true)
  )

  function clockLabel(value) {
    const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ""))
    if (!match) return String(value || "")
    const date = new Date(2000, 0, 1, Number(match[1]), Number(match[2]))
    return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  function ensureVisible(item) {
    if (!item || !scrollArea) return
    Qt.callLater(function() {
      const flick = scrollArea.contentItem
      if (!item || !flick || flick.contentY === undefined) return
      const point = item.mapToItem(flick.contentItem || flick, 0, 0)
      const margin = Style.space(8)
      const top = point.y
      const bottom = top + item.height
      const maximum = Math.max(0, flick.contentHeight - flick.height)
      if (top < flick.contentY + margin)
        flick.contentY = Math.max(0, top - margin)
      else if (bottom > flick.contentY + flick.height - margin)
        flick.contentY = Math.min(maximum, bottom + margin - flick.height)
    })
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
    if (controller.status.mode !== "enforce") return root.heroTitle()
    if (controller.status.curfew.active)
      return qsTr("Curfew active until %1").arg(clockLabel(controller.status.curfew.end))
    if (controller.status.morning.active)
      return qsTr("Morning routine until %1").arg(clockLabel(controller.status.morning.end))
    return qsTr("Available %1–%2")
      .arg(clockLabel(controller.status.curfew.end))
      .arg(clockLabel(controller.status.curfew.start))
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
    if (root.browserAttention) return qsTr("Sundown browser protection needs attention")
    if (controller.status.apps.groups.length > 0 && !controller.status.apps.healthy)
      return qsTr("Sundown application tracking needs attention")
    return qsTr("Sundown curfew begins in %1").arg(Model.formatCountdown(controller.status.curfew.seconds_until_start))
  }

  moduleName: "io.github.silouanwright.sundown"
  ipcTarget: "sundown-panel"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    controller.panelOpen = opened
    if (opened) {
      flexSection.resetCursor()
      controller.refreshAll()
    }
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
      textFormat: Text.PlainText
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
      onMoveRequested: function(_dx, dy) {
        if (flexSection.visible && dy !== 0) {
          flexSection.moveCursor(dy)
          root.ensureVisible(flexSection.cursorItem())
        }
      }
      onActivateRequested: if (flexSection.visible && flexSection.cursorActive) flexSection.activateCursor()
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

          PolicyProgressRow {
            visible: controller.statusKnown && controller.statusCompatibility === ""
            label: qsTr("Usable day")
            value: qsTr("%1–%2")
              .arg(root.clockLabel(controller.status.curfew.end))
              .arg(root.clockLabel(controller.status.curfew.start))
            detail: controller.status.curfew.active
              ? qsTr("Curfew is active")
              : qsTr("%1 until curfew").arg(Model.formatCountdown(root.dayWindow.remaining))
            ratio: root.dayWindow.ratio
            complete: controller.status.curfew.active && root.dayWindow.ratio >= 1
            active: !controller.status.curfew.active
            foreground: root.foreground
            dim: root.dim
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
            visible: controller.available && root.browserAttention
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
            visible: controller.available && controller.status.apps.groups.length > 0
              && !controller.status.apps.healthy
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
              width: content.width
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
              width: content.width
              label: modelData.source
              value: modelData.satisfied ? qsTr("Ready")
                : modelData.kind === "count"
                  ? qsTr("%1 left").arg(modelData.remaining)
                  : qsTr("%1 left").arg(Model.formatDuration(modelData.remaining))
              detail: modelData.satisfied
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
              width: content.width
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
            width: content.width
            status: controller.status
            busy: controller.flexBusy
            message: controller.flexMessage
            error: controller.flexError
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            onRedeem: function(target) { controller.redeemFlex(target) }
          }

          PanelSeparator { foreground: root.foreground }

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
              text: controller.reportKnown ? Model.formatDuration(Model.reportTotal(controller.report)) : qsTr("Loading…")
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
            currentDate: controller.report.end_date
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
          }

          Text {
            visible: controller.reportKnown && controller.reportError === ""
            width: parent.width
            text: Model.recordedDaysLabel(controller.report.recorded_days)
              + qsTr(" · unrecorded days are unknown")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          PanelSectionHeader {
            visible: controller.reportKnown && root.historyCategories.length > 0
            text: qsTr("BREAKDOWN")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: controller.reportKnown ? root.historyCategories : []

            Item {
              id: historyRow

              required property var modelData
              width: content.width
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
            textFormat: Text.PlainText
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
