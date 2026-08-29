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

const report = context.parseReport(JSON.stringify({
  version: 1,
  range: "week",
  start_date: "2026-08-23",
  end_date: "2026-08-29",
  recorded_days: 2,
  days: [
    { date: "2026-08-28", steam: { used_seconds: 3600 }, web: [{ used_seconds: 600 }] },
    { date: "2026-08-29", steam: { used_seconds: 0 }, web: [{ used_seconds: 300 }] }
  ],
  totals: { steam_seconds: 3600, web_seconds: { social: 900 } },
  limit_hits: []
})).data

const week = context.weekRows(report)
assert.equal(week.length, 7)
assert.equal(week[0].date, "2026-08-23")
assert.equal(week[5].seconds, 4200)
assert.equal(week[5].recorded, true)
assert.equal(week[4].recorded, false)
assert.equal(context.reportTotal(report), 4500)
assert.equal(context.recordedDaysLabel(1), "1 recorded day")
assert.equal(context.recordedDaysLabel(2), "2 recorded days")

console.log("model checks passed")
