import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  property var controller: null
  property int attempts: 0

  function fail(message) {
    console.error("QML check failed:", message)
    Qt.exit(1)
  }

  function checkFlexSection() {
    const section = flexComponent.createObject(root)
    if (!section) return fail("could not create FlexSection")
    if (section.expanded || section.actionCount !== 1)
      return fail("flex targets must start behind one action")

    let redeemed = ""
    section.redeem.connect(function(target) { redeemed = target })
    section.moveCursor(1)
    section.activateCursor()
    if (!section.expanded || section.cursorIndex !== 1)
      return fail("the flex action did not reveal and select its first target")

    section.activateCursor()
    if (redeemed !== "steam" || section.expanded)
      return fail("the selected target was not redeemed and collapsed")
    section.destroy()
  }

  function checkRollingBudgetRow() {
    const row = rollingBudgetComponent.createObject(root)
    if (!row) return fail("could not create rolling BudgetRow")
    if (row.metaText !== "19m / 45m today · 1h window · 15m flex")
      return fail("rolling BudgetRow did not preserve daily and flex context")
    row.destroy()
  }

  function checkWeekChart() {
    const chart = weekChartComponent.createObject(root)
    if (!chart) return fail("could not create WeekChart")
    if (chart.cellWidth <= chart.columnWidth || chart.plotHeight <= 0)
      return fail("WeekChart columns do not fit their day cells")
    chart.destroy()
  }

  Component {
    id: controllerComponent
    Plugin.SundownController {
      panelOpen: true
      sundownCommand: "/definitely-missing/sundown"
    }
  }

  Component {
    id: flexComponent
    Plugin.FlexSection {
      width: 380
      status: ({
        flex: {
          enabled: true,
          pass_seconds: 900,
          remaining_uses: 1,
          eligible: ["steam", "web:social"],
          redemptions: []
        },
        steam: { name: "gaming" },
        web: { rules: [{ name: "social" }] },
        apps: { groups: [] }
      })
    }
  }

  Component {
    id: rollingBudgetComponent
    Plugin.BudgetRow {
      width: 380
      modelData: ({
        label: "Social",
        restricted: true,
        used: 1165,
        limit: 2700,
        meterUsed: 905,
        meterLimit: 900,
        meterRatio: 1,
        active: false,
        blocked: true,
        blockedBy: "pace-limit",
        gate: null,
        schedule: null,
        pace: {
          limit_seconds: 900,
          window_seconds: 3600,
          used_seconds: 905,
          remaining_seconds: 0,
          next_refill_at: "2026-09-01T11:18:49-05:00"
        },
        flexRemaining: 900,
        earnedBank: 0,
        warningMinutes: null
      })
    }
  }

  Component {
    id: weekChartComponent
    Plugin.WeekChart {
      width: 380
      maximum: 21420
      currentDate: "2026-09-01"
      rows: [
        { date: "2026-08-26", label: "W", seconds: 0, recorded: false },
        { date: "2026-08-27", label: "T", seconds: 0, recorded: false },
        { date: "2026-08-28", label: "F", seconds: 0, recorded: false },
        { date: "2026-08-29", label: "S", seconds: 12600, recorded: true },
        { date: "2026-08-30", label: "S", seconds: 21420, recorded: true },
        { date: "2026-08-31", label: "M", seconds: 6060, recorded: true },
        { date: "2026-09-01", label: "T", seconds: 4080, recorded: true }
      ]
    }
  }

  Timer {
    interval: 25
    running: true
    repeat: true
    onTriggered: {
      root.attempts++
      if (root.controller.statusKnown && root.controller.reportKnown) {
        if (root.controller.available
            || root.controller.statusError !== qsTr("Sundown is not available")
            || root.controller.reportError !== qsTr("Could not load Screen Time history"))
          return root.fail("failed commands did not settle into their error states")
        root.checkFlexSection()
        root.checkRollingBudgetRow()
        root.checkWeekChart()
        console.log("QML checks passed")
        Qt.quit()
      } else if (root.attempts >= 200) {
        root.fail("controller checks timed out")
      }
    }
  }

  Component.onCompleted: {
    controller = controllerComponent.createObject(root)
    if (!controller) fail("could not create SundownController")
  }
}
