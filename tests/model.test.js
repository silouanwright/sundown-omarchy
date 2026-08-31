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
assert.equal(budgets[1].label, "Social")
assert.equal(context.totalToday(budgets), 4200)
assert.equal(context.formatDuration(59), "<1m")
assert.equal(context.formatDuration(7260), "2h 1m")

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
assert.equal(context.dayWindow(gamingStatus).remaining, 7200)

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
assert.equal(adaptiveBudgets[0].blockedBy, "prerequisite-gate")
assert.equal(context.budgetDetail(adaptiveBudgets[0]), "10m in Journaling needed")
assert.equal(adaptiveBudgets[1].label, "Other Games")
assert.equal(context.totalToday(adaptiveBudgets), 1500)
assert.equal(context.budgetDetail({
  restricted: true,
  blockedBy: "",
  remaining: 2400,
  pace: { used_seconds: 1200, limit_seconds: 3600, window_seconds: 10800 }
}), "20m / 1h · 3h rolling")
assert.equal(context.gateRows(adaptiveStatus)[0].ratio, 0.5)
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
