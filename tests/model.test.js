const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\.pragma library\s*/m, "")
const context = { Date, JSON, Math, Number, Object, String, Array, RegExp, isFinite }
vm.createContext(context)
vm.runInContext(source, context)

assert.equal(context.parseStatus("nope").ok, false)
assert.equal(context.parseStatus('{"version":0}').compatibility, "core-too-old")
assert.equal(context.parseStatus('{"version":2}').compatibility, "plugin-too-old")

const status = context.parseStatus(JSON.stringify({
  version: 1,
  mode: "enforce",
  steam: { daily_limit_seconds: 7200, used_seconds: 3600, remaining_seconds: 3600, next_warning_minutes: 20 },
  curfew: { active: false, seconds_until_start: 3600, start: "19:00", end: "06:00" },
  morning: { enabled: true, active: false, start: "06:00", end: "09:00" },
  runtime: { support_level: "enforcing" },
  web: {
    healthy: true,
    enforcement_ready: true,
    rules: [{
      name: "social",
      daily_limit_seconds: 1800,
      used_seconds: 600,
      remaining_seconds: 1200,
      next_warning_minutes: 10,
      domain_usage: [
        { domain: "x.com", used_seconds: 120 },
        { domain: "reddit.com", used_seconds: 480 }
      ]
    }]
  }
})).data

const budgets = context.budgetRows(status)
assert.equal(budgets.length, 2)
assert.equal(budgets[0].label, "Steam")
assert.equal(budgets[0].ratio, 0.5)
assert.equal(budgets[0].meterRatio, 0.5)
assert.equal(budgets[0].meterScope, "daily")
assert.equal(budgets[1].label, "Social")
assert.equal(context.totalToday(budgets), 4200)
assert.equal(context.formatDuration(59), "<1m")
assert.equal(context.formatDuration(7260), "2h 1m")
assert.equal(context.minutesUntil("2026-09-01T11:18:01-05:00", "2026-09-01T11:11:30-05:00"), 7)
assert.equal(context.minutesUntil("2026-09-01T11:18:01-05:00", "2026-09-01T11:18:02-05:00"), 0)
assert.equal(context.minutesUntil("not-a-time", "2026-09-01T11:18:02-05:00"), null)
assert.equal(context.browserNeedsAttention({
  web: { browser_active: false, healthy: false, enforcement_ready: false }
}), false)
assert.equal(context.browserNeedsAttention({
  web: { browser_active: true, healthy: false, enforcement_ready: false }
}), true)
assert.equal(context.browserNeedsAttention({
  web: { browser_active: true, healthy: true, enforcement_ready: true }
}), false)

const gamingStatus = context.parseStatus(JSON.stringify({
  version: 1,
  mode: "enforce",
  runtime: { support_level: "enforcing" },
  steam: {
    name: "gaming",
    shared_app_group: "gaming",
    daily_limit_seconds: 14400,
    used_seconds: 5400,
    steam_used_seconds: 3600,
    shared_app_used_seconds: 1800,
    remaining_seconds: 9000
  },
  curfew: { active: false, seconds_until_start: 7200, start: "21:00", end: "06:00" },
  web: { healthy: true, enforcement_ready: true, rules: [] },
  apps: { healthy: true, groups: [{ name: "gaming", used_seconds: 1800, shared_with_steam: true }] }
})).data
assert.deepEqual(context.budgetRows(gamingStatus).map(row => row.label), ["Gaming"])
assert.equal(context.totalToday(context.budgetRows(gamingStatus)), 5400)

const adaptiveStatus = context.parseStatus(JSON.stringify({
  version: 1,
  mode: "enforce",
  runtime: { support_level: "enforcing" },
  steam: {
    daily_limit_seconds: 7200,
    used_seconds: 1200,
    remaining_seconds: 6000,
    available_seconds: 0,
    blocked_by: "prerequisite-gate",
    schedule: { allowed: true, next_change_at: "2026-08-29T18:00:00-05:00" },
    flex_granted_seconds: 900,
    flex_remaining_seconds: 900,
    earned_granted_seconds: 300,
    earned_bank_seconds: 300,
    pace: {
      limit_seconds: 3600,
      window_seconds: 10800,
      used_seconds: 1200,
      remaining_seconds: 2400
    }
  },
  curfew: { active: false, start: "19:00", end: "06:00" },
  morning: { enabled: false, active: false },
  web: { healthy: true, enforcement_ready: true, rules: [] },
  apps: {
    healthy: true,
    groups: [
      { name: "journaling", used_seconds: 600, daily_limit_seconds: null },
      { name: "other-games", used_seconds: 300, daily_limit_seconds: 7200, available_seconds: 6900 }
    ]
  },
  gates: [{
    name: "journal-first",
    source_group: "journaling",
    targets: ["steam", "app:other-games"],
    used_seconds: 600,
    required_seconds: 1200,
    remaining_seconds: 600,
    satisfied: false
  }],
  flex: {
    enabled: true,
    pass_seconds: 900,
    remaining_uses: 1,
    eligible: ["steam", "app:other-games"],
    redemptions: [
      { id: 1, target: "steam", granted_seconds: 900, redeemed_at: "2026-08-29T10:00:00-05:00" },
      { id: 2, target: "app:other-games", granted_seconds: 900, redeemed_at: "2026-08-29T12:00:00-05:00" }
    ]
  },
  earned: [{
    name: "journal-reward",
    source_group: "journaling",
    target: "steam",
    bank_seconds: 300,
    bank_cap_seconds: 900,
    earning_now: true,
    suppressed_by_target_activity: false
  }]
})).data

const adaptiveBudgets = context.budgetRows(adaptiveStatus)
assert.equal(adaptiveBudgets.length, 2)
assert.equal(adaptiveBudgets[0].limit, 8400)
assert.equal(adaptiveBudgets[0].meterUsed, 1200)
assert.equal(adaptiveBudgets[0].meterLimit, 3600)
assert.equal(adaptiveBudgets[0].meterRatio, 1 / 3)
assert.equal(adaptiveBudgets[0].meterScope, "rolling")
assert.equal(adaptiveBudgets[0].blockedBy, "prerequisite-gate")
assert.equal(adaptiveBudgets[0].prerequisiteLocked, true)
assert.equal(context.budgetDetail(adaptiveBudgets[0]), "Locked · 10m of Journaling needed")
assert.equal(adaptiveBudgets[1].label, "Other Games")
assert.equal(context.totalToday(adaptiveBudgets), 1500)
assert.equal(context.budgetDetail({
  restricted: true,
  blockedBy: "",
  remaining: 2400,
  pace: { used_seconds: 1200, limit_seconds: 3600, window_seconds: 10800, remaining_seconds: 2400 }
}), "40m rolling remaining")
assert.equal(context.budgetDetail({
  restricted: true,
  blockedBy: "",
  pace: { used_seconds: 3600, limit_seconds: 3600, window_seconds: 10800, remaining_seconds: 0 }
}), "Rolling allowance spent")
assert.equal(context.budgetRows(context.parseStatus(JSON.stringify({
  version: 1,
  steam: {
    daily_limit_seconds: 7200,
    used_seconds: 1200,
    pace: { used_seconds: 905, limit_seconds: 900, window_seconds: 3600, remaining_seconds: 0 }
  }
})).data)[0].meterRatio, 1)

const dailyBindingBudget = context.budgetRows(context.parseStatus(JSON.stringify({
  version: 1,
  steam: {
    daily_limit_seconds: 1800,
    used_seconds: 1500,
    remaining_seconds: 300,
    pace: {
      used_seconds: 300,
      limit_seconds: 900,
      window_seconds: 3600,
      remaining_seconds: 600
    }
  }
})).data)[0]
assert.equal(dailyBindingBudget.dailyRemaining, 300)
assert.equal(dailyBindingBudget.meterUsed, 1500)
assert.equal(dailyBindingBudget.meterLimit, 1800)
assert.equal(dailyBindingBudget.meterRatio, 5 / 6)
assert.equal(dailyBindingBudget.meterScope, "daily")
assert.equal(context.budgetDetail(dailyBindingBudget), "5m remaining today")
assert.equal(context.gateRows(adaptiveStatus)[0].ratio, 0.5)

const journalStatus = context.parseStatus(JSON.stringify({
  version: 1,
  steam: {
    daily_limit_seconds: 7200,
    used_seconds: 0,
    available_seconds: 0,
    blocked_by: "prerequisite-gate"
  },
  duration_gates: [{
    name: "journal-before-distractions",
    source: "/apps/voice-journal/recorded-duration",
    targets: ["steam", "web:social"],
    recorded_seconds: 420,
    required_seconds: 600,
    remaining_seconds: 180,
    satisfied: false
  }],
  completion_gates: [{
    name: "two-entries",
    source: "/apps/voice-journal/daily-entry",
    targets: ["web:facebook"],
    active_completions: 1,
    required_completions: 2,
    remaining_completions: 1,
    satisfied: false
  }]
})).data
const journalGates = context.gateRows(journalStatus)
assert.equal(journalGates.length, 2)
assert.equal(journalGates[0].source, "Journal")
assert.equal(journalGates[0].kind, "count")
assert.equal(journalGates[0].remaining, 1)
assert.equal(journalGates[1].source, "Journal")
assert.equal(journalGates[1].ratio, 0.7)
assert.equal(context.budgetDetail(context.budgetRows(journalStatus)[0]), "Locked · 3m of Journal needed")

const syncingStatus = context.parseStatus(JSON.stringify({
  version: 1,
  steam: {
    name: "gaming",
    daily_limit_seconds: 7200,
    used_seconds: 0,
    remaining_seconds: 7200,
    available_seconds: 0,
    blocked_by: "prerequisite-gate"
  },
  duration_gates: [{
    name: "journal-before-distractions",
    source: "/apps/voice-journal/recorded-duration",
    targets: ["steam"],
    recorded_seconds: 0,
    required_seconds: 600,
    remaining_seconds: 600,
    synchronized: false,
    satisfied: false
  }]
})).data
assert.equal(context.gateRows(syncingStatus)[0].synchronized, false)
assert.equal(context.budgetRows(syncingStatus)[0].prerequisiteChecking, true)
assert.equal(context.budgetRows(syncingStatus)[0].prerequisiteLocked, false)
assert.equal(context.budgetDetail(context.budgetRows(syncingStatus)[0]), "Checking Journal activity")

const evercountStatus = context.parseStatus(JSON.stringify({
  version: 1,
  duration_gates: [{
    name: "morning-prayer",
    source: "/services/evercount/morning-prayer-minutes",
    targets: ["steam"],
    recorded_seconds: 600,
    required_seconds: 1800,
    remaining_seconds: 1200,
    synchronized: true,
    satisfied: false
  }]
})).data
assert.equal(context.gateRows(evercountStatus)[0].provider, "evercount")
assert.equal(context.gateRows(journalStatus)[0].provider, "journal")

assert.equal(context.earnedRows(adaptiveStatus)[0].bank, 300)
assert.equal(context.flexTargets(adaptiveStatus)[1].label, "Other Games")
assert.deepEqual(context.flexAuditRows(adaptiveStatus).map(row => row.label), ["Other Games", "Steam"])
assert.equal(context.flexAuditRows(adaptiveStatus)[0].seconds, 900)

const report = context.parseReport(JSON.stringify({
  version: 1,
  range: "week",
  start_date: "2026-08-23",
  end_date: "2026-08-29",
  recorded_days: 2,
  days: [
    { date: "2026-08-28", steam: { used_seconds: 3600 }, web: [{ used_seconds: 600 }], apps: [{ used_seconds: 300 }, { used_seconds: 600 }] },
    { date: "2026-08-29", steam: { used_seconds: 0 }, web: [{ used_seconds: 300 }] }
  ],
  totals: { steam_seconds: 3600, web_seconds: { social: 900 }, app_seconds: { "other-games": 300, journaling: 600 } },
  limit_hits: []
})).data

const week = context.weekRows(report)
assert.equal(week.length, 7)
assert.equal(week[0].date, "2026-08-23")
assert.equal(week[5].seconds, 5100)
assert.equal(week[5].recorded, true)
assert.equal(week[4].recorded, false)
assert.equal(context.reportTotal(report), 5400)
assert.deepEqual(context.reportCategories(report).map(row => row.label), ["Steam", "Social", "Other Games", "Journaling"])
const gamingReport = JSON.parse(JSON.stringify(report))
gamingReport.totals.app_seconds.gaming = gamingReport.totals.app_seconds["other-games"]
delete gamingReport.totals.app_seconds["other-games"]
assert.deepEqual(
  context.reportCategories(gamingReport, gamingStatus).map(row => [row.label, row.seconds]),
  [["Gaming", 3900], ["Social", 900], ["Journaling", 600]]
)
assert.equal(context.recordedDaysLabel(1), "1 recorded day")
assert.equal(context.recordedDaysLabel(2), "2 recorded days")

console.log("model checks passed")
