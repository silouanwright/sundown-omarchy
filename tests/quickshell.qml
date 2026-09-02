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

    const locked = lockedBudgetComponent.createObject(root)
    if (!locked) return fail("could not create multi-prerequisite BudgetRow")
    if (locked.detailText !== "Locked · Reading log: 1 entry")
      return fail("BudgetRow dropped its QML-bound unmet prerequisite list")
    locked.destroy()
  }

  function checkWeekChart() {
    const chart = weekChartComponent.createObject(root)
    if (!chart) return fail("could not create WeekChart")
    if (chart.cellWidth <= chart.columnWidth || chart.plotHeight <= 0)
      return fail("WeekChart columns do not fit their day cells")
    chart.destroy()
  }

  function checkPanelViews() {
    const today = todayViewComponent.createObject(root)
    if (!today || today.implicitHeight <= 0)
      return fail("could not create the Today panel view")
    const durationGate = {
      synchronized: true,
      kind: "duration",
      used: 616,
      required: 600,
      remaining: 0,
      satisfied: true,
      targets: "Gaming, Social",
      unlockedTargets: "Social",
      waitingTargets: "Gaming"
    }
    if (today.gateValue(durationGate) !== "10m / 10m"
        || today.gateDetail(durationGate)
          !== "Completed · Unlocked: Social · Waiting on another prerequisite: Gaming")
      return fail("multi-prerequisite readiness was not reflected per allowance")
    today.gateRows = [{
      provider: "evercount",
      source: "Morning Prayer",
      kind: "duration",
      used: 600,
      required: 1800,
      remaining: 1200,
      ratio: 1 / 3,
      synchronized: true,
      satisfied: false,
      targets: "Gaming"
    }]
    today.providerRows = [{
      id: "evercount",
      label: "Evercount",
      health: "healthy",
      synchronized: true,
      lastSyncAt: "2026-09-02T09:10:01-05:00",
      message: "",
      manualSync: true
    }]
    if (!today.evercountSyncVisible)
      return fail("Evercount prerequisite did not expose manual sync")
    if (today.providerHealth(today.providerRows[0]) !== "Healthy"
        || today.providerDetail(today.providerRows[0]).indexOf("Last sync") !== 0)
      return fail("provider health and last sync were not surfaced")
    let syncRequests = 0
    today.syncEvercount.connect(function() { syncRequests++ })
    today.requestEvercountSync()
    if (syncRequests !== 1)
      return fail("manual Evercount sync did not emit exactly once")
    const countGate = {
      synchronized: true,
      kind: "count",
      used: 1,
      required: 2,
      remaining: 1,
      satisfied: false,
      targets: "Facebook"
    }
    if (today.gateValue(countGate) !== "1 / 2 entries"
        || today.gateDetail(countGate) !== "1 entry left · Required for: Facebook")
      return fail("count prerequisite progress is not explicit")
    today.destroy()

    const history = historyViewComponent.createObject(root)
    if (!history || history.implicitHeight <= 0)
      return fail("could not create the History panel view")
    history.destroy()

    const statusRow = statusRowComponent.createObject(root)
    if (!statusRow || statusRow.implicitHeight <= 0
        || statusRow.value !== "Healthy" || !statusRow.positive)
      return fail("could not create a positive provider status row")
    statusRow.destroy()
  }

  QtObject {
    id: fakeController
    property bool statusKnown: true
    property string statusCompatibility: ""
    property bool available: true
    property string statusError: ""
    property bool flexBusy: false
    property string flexMessage: ""
    property string flexError: ""
    property bool evercountSyncBusy: false
    property string evercountSyncMessage: ""
    property string evercountSyncError: ""
    property bool reportKnown: true
    property string reportError: ""
    property var status: ({
      curfew: { active: false, start: "19:00", end: "06:00" },
      apps: { healthy: true, groups: [] },
      flex: { enabled: false, eligible: [], redemptions: [] }
    })
    property var report: ({
      end_date: "2026-09-01",
      recorded_days: 1,
      days: [],
      totals: { steam_seconds: 0, web_seconds: {}, app_seconds: {} }
    })
  }

  Component {
    id: controllerComponent
    Plugin.SundownController {
      panelOpen: true
      sundownCommand: "/definitely-missing/sundown"
      evercountCommand: "/definitely-missing/sundown-adapter-evercount"
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
        meterScope: "rolling",
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
    id: lockedBudgetComponent
    Plugin.BudgetRow {
      width: 380
      modelData: ({
        label: "Gaming",
        restricted: true,
        used: 1800,
        limit: 3600,
        meterUsed: 1800,
        meterLimit: 3600,
        meterRatio: 0.5,
        meterScope: "daily",
        active: false,
        blocked: true,
        blockedBy: "prerequisite-gate",
        prerequisiteLocked: true,
        prerequisiteChecking: false,
        unmetPrerequisites: [{
          source: "Reading log",
          synchronized: true,
          kind: "count",
          remaining: 1
        }],
        gate: null,
        schedule: null,
        pace: null,
        flexRemaining: 900,
        earnedBank: 0,
        warningMinutes: 50
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

  Component {
    id: todayViewComponent
    Plugin.TodayView {
      width: 380
      controller: fakeController
    }
  }

  Component {
    id: statusRowComponent
    Plugin.StatusRow {
      width: 380
      label: "Evercount"
      value: "Healthy"
      detail: "Last sync 9/2/26, 9:10 AM"
      positive: true
      foreground: "#202020"
      dim: "#707070"
      positiveColor: "#008000"
      urgentColor: "#c00000"
      fontFamily: "sans-serif"
      rowSpacing: 3
      labelGap: 8
      bodyFontSize: 14
      captionFontSize: 11
    }
  }

  Component {
    id: historyViewComponent
    Plugin.HistoryView {
      width: 380
      controller: fakeController
      weekRows: [
        { date: "2026-09-01", label: "T", seconds: 600, recorded: true }
      ]
      categories: [{ label: "Gaming", seconds: 600 }]
      flexAuditRows: [{
        label: "Gaming",
        seconds: 900,
        redeemedAt: "2026-09-02T09:30:00-05:00"
      }]
      weekMaximum: 600
    }
  }

  Component {
    id: fullPanelComponent
    Plugin.Panel {}
  }

  Timer {
    interval: 25
    running: true
    repeat: true
    onTriggered: {
      root.attempts++
      if (root.controller.statusKnown && root.controller.reportKnown
          && !root.controller.evercountSyncBusy) {
        if (root.controller.available
            || root.controller.statusError !== qsTr("Sundown is not available")
            || root.controller.reportError !== qsTr("Could not load Screen Time history"))
          return root.fail("failed commands did not settle into their error states")
        if (root.controller.evercountSyncError !== qsTr("Could not start the Evercount adapter"))
          return root.fail("failed Evercount sync did not settle into its error state")
        root.checkFlexSection()
        root.checkRollingBudgetRow()
        root.checkWeekChart()
        root.checkPanelViews()
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
    controller.syncEvercount()
  }
}
