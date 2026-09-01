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
  readonly property real weekMaximum: Model.maximumDay(weekRows)
  readonly property var controllerForViews: controller
  property string currentView: "today"
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

  function resetScroll() {
    const flick = scrollArea.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function showView(view) {
    currentView = view === "history" ? "history" : "today"
    resetScroll()
    Qt.callLater(function() {
      root.resetScroll()
      if (root.currentView === "today" && viewLoader.item && viewLoader.item.resetCursor)
        viewLoader.item.resetCursor()
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
      root.showView("today")
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

  Component {
    id: todayViewComponent

    TodayView {
      controller: root.controllerForViews
      budgetRows: root.budgetRows
      gateRows: root.gateRows
      earnedRows: root.earnedRows
      browserAttention: root.browserAttention
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
      onRedeem: function(target) { root.controllerForViews.redeemFlex(target) }
    }
  }

  Component {
    id: historyViewComponent

    HistoryView {
      controller: root.controllerForViews
      weekRows: root.weekRows
      categories: root.historyCategories
      weekMaximum: root.weekMaximum
      foreground: root.foreground
      dim: root.dim
      fontFamily: root.fontFamily
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
      onCloseRequested: {
        if (root.currentView === "history") root.showView("today")
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(_dx, dy) {
        if (root.currentView === "today" && viewLoader.item && viewLoader.item.flexVisible && dy !== 0) {
          viewLoader.item.moveCursor(dy)
          root.ensureVisible(viewLoader.item.cursorItem())
        }
      }
      onActivateRequested: {
        if (root.currentView === "today" && viewLoader.item && viewLoader.item.flexCursorActive)
          viewLoader.item.activateCursor()
      }
      onTextKey: function(text) {
        if (text === "r" || text === "R") controller.refreshAll()
        else if (text === "h" || text === "H") root.showView("history")
        else if (text === "t" || text === "T") root.showView("today")
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

          Item {
            width: parent.width
            implicitHeight: viewSelector.implicitHeight

            ButtonGroup {
              id: viewSelector
              anchors.horizontalCenter: parent.horizontalCenter
              options: [
                { value: "today", label: qsTr("Today") },
                { value: "history", label: qsTr("History") }
              ]
              value: root.currentView
              focusable: false
              foreground: root.foreground
              background: "transparent"
              accent: Color.accent
              fontFamily: root.fontFamily
              onChanged: function(value) { root.showView(value) }
            }
          }

          Loader {
            id: viewLoader
            width: content.width
            height: item ? item.implicitHeight : 0
            sourceComponent: root.currentView === "history" ? historyViewComponent : todayViewComponent
            onLoaded: Qt.callLater(root.resetScroll)
          }

          Text {
            width: parent.width
            text: root.currentView === "history"
              ? qsTr("Press T for Today · R to refresh")
              : qsTr("Press H for History · R to refresh")
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
