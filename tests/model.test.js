const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\.pragma library\s*/m, "")
const context = { Date, JSON, Math, Number, Object, String, Array, RegExp, isFinite }
vm.createContext(context)
vm.runInContext(source, context)

const adapterSource = fs.readFileSync(path.join(__dirname, "..", "PrerequisiteAdapter.js"), "utf8")
  .replace(/^\.pragma library\s*/m, "")
const adapter = { Date, JSON, Math, Number, Object, String, Array, RegExp, isFinite }
vm.createContext(adapter)
vm.runInContext(adapterSource, adapter)

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
assert.equal(adaptiveBudgets[0].meterLimit, 4500)
assert.equal(adaptiveBudgets[0].meterRatio, 1200 / 4500)
assert.equal(adaptiveBudgets[0].meterScope, "rolling")
assert.equal(adaptiveBudgets[0].blockedBy, "prerequisite-gate")
assert.equal(adaptiveBudgets[0].prerequisiteLocked, true)
assert.equal(context.budgetDetail(adaptiveBudgets[0]), "Locked · Journaling: 10m")
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

const rollingFlexBudget = context.budgetRows(context.parseStatus(JSON.stringify({
  version: 1,
  steam: { daily_limit_seconds: null, used_seconds: 0 },
  web: {
    rules: [{
      name: "youtube",
      daily_limit_seconds: 3600,
      used_seconds: 2054,
      available_seconds: 646,
      flex_granted_seconds: 900,
      flex_remaining_seconds: 646,
      pace: {
        used_seconds: 2054,
        limit_seconds: 1800,
        window_seconds: 7200,
        remaining_seconds: 0
      }
    }]
  }
})).data)[1]
assert.equal(rollingFlexBudget.meterScope, "rolling")
assert.equal(rollingFlexBudget.meterUsed, 2054)
assert.equal(rollingFlexBudget.meterLimit, 2700)
assert.equal(rollingFlexBudget.meterRatio, 2054 / 2700)

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
assert.equal(context.budgetDetail(context.budgetRows(journalStatus)[0]), "Locked · Journal: 3m")

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
assert.equal(context.budgetRows(syncingStatus)[0].prerequisiteLocked, true)
assert.equal(context.budgetDetail(context.budgetRows(syncingStatus)[0]), "Locked · Journal: checking")

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

const multiplePrerequisiteStatus = context.parseStatus(JSON.stringify({
  version: 1,
  steam: {
    name: "gaming",
    daily_limit_seconds: 7200,
    used_seconds: 0,
    available_seconds: 0,
    blocked_by: "prerequisite-gate"
  },
  duration_gates: [{
    name: "journal-before-distractions",
    source: "/apps/voice-journal/recorded-duration",
    targets: ["steam"],
    recorded_seconds: 600,
    required_seconds: 600,
    remaining_seconds: 0,
    synchronized: true,
    satisfied: true
  }],
  completion_gates: [{
    name: "selected-counter-before-distractions",
    source: "/services/evercount/selected-counter-daily-goal",
    targets: ["steam"],
    active_completions: 0,
    required_completions: 1,
    remaining_completions: 1,
    synchronized: true,
    satisfied: false
  }]
})).data
const multiplePrerequisiteRows = context.gateRows(multiplePrerequisiteStatus)
const multiplePrerequisiteBudget = context.budgetRows(multiplePrerequisiteStatus)[0]
assert.equal(multiplePrerequisiteBudget.prerequisites.length, 2)
assert.equal(multiplePrerequisiteBudget.unmetPrerequisites.length, 1)
assert.equal(multiplePrerequisiteBudget.unmetPrerequisites[0].provider, "evercount")
assert.equal(multiplePrerequisiteBudget.prerequisiteLocked, true)
assert.equal(multiplePrerequisiteRows[0].unlockedTargets, "")
assert.equal(multiplePrerequisiteRows[0].waitingTargets, "Gaming")
assert.equal(multiplePrerequisiteRows[1].unlockedTargets, "")

multiplePrerequisiteStatus.completion_gates[0].active_completions = 1
multiplePrerequisiteStatus.completion_gates[0].remaining_completions = 0
multiplePrerequisiteStatus.completion_gates[0].satisfied = true
const unlockedRows = context.gateRows(multiplePrerequisiteStatus)
const unlockedBudget = context.budgetRows(multiplePrerequisiteStatus)[0]
assert.equal(unlockedBudget.unmetPrerequisites.length, 0)
assert.equal(unlockedBudget.prerequisiteLocked, false)
assert.equal(unlockedRows[0].unlockedTargets, "Gaming")
assert.equal(unlockedRows[1].unlockedTargets, "Gaming")

const aggregateDocument = {
  version: 1,
  adapters: [{
    version: 1,
    adapterId: "evercount",
    displayName: "Evercount",
    health: "unavailable",
    policyDate: "2026-09-02",
    transport: "scheduled_pull",
    manualSync: true,
    prerequisites: [{
      gateId: "selected-counter-before-distractions",
      source: "/services/evercount/selected-counter-daily-goal",
      kind: "completion",
      progress: { value: 4.5, unit: "provider_units" },
      requirement: { value: 5, unit: "provider_units" },
      satisfied: false,
      synchronized: true,
      targets: ["steam"]
    }],
    lastTrigger: "scheduled_pull",
    lastAttemptAt: "2026-09-02T09:11:00-05:00",
    lastSuccessfulReadAt: "2026-09-02T09:10:00-05:00",
    lastSuccessfulSyncAt: "2026-09-02T09:10:01-05:00",
    nextScheduledSyncAt: "2026-09-02T09:15:00-05:00",
    error: {
      code: "provider-timeout",
      message: "Evercount did not respond.",
      action: "Check the connection, then sync again.",
      retryable: true,
      occurredAt: "2026-09-02T09:11:00-05:00"
    }
  }, {
    version: 1,
    adapterId: "journal",
    displayName: "Voice Journal",
    health: "healthy",
    policyDate: "2026-09-02",
    transport: "observable",
    manualSync: false,
    prerequisites: [{
      gateId: "journal-before-distractions",
      source: "/apps/voice-journal/recorded-duration",
      kind: "duration",
      progress: { value: 600, unit: "seconds" },
      requirement: { value: 600, unit: "seconds" },
      satisfied: true,
      synchronized: true,
      targets: ["steam"]
    }],
    lastTrigger: "observable_change",
    lastAttemptAt: "2026-09-02T09:09:00-05:00",
    lastSuccessfulReadAt: "2026-09-02T09:09:00-05:00",
    lastSuccessfulSyncAt: "2026-09-02T09:09:01-05:00",
    nextScheduledSyncAt: null,
    error: null
  }]
}
const aggregateStatus = adapter.parseAggregateStatus(JSON.stringify(aggregateDocument))
assert.equal(aggregateStatus.ok, true)
const providerRows = adapter.providers(aggregateStatus.data)
assert.deepEqual(Array.from(providerRows, row => row.id), ["evercount", "journal"])
assert.equal(providerRows[0].health, "unavailable")
assert.equal(providerRows[0].lastSyncAt, "2026-09-02T09:10:01-05:00")
assert.equal(providerRows[0].lastReadAt, "2026-09-02T09:10:00-05:00")
assert.equal(providerRows[0].errorMessage, "Evercount did not respond.")
assert.equal(providerRows[0].errorAction, "Check the connection, then sync again.")
assert.equal(adapter.providerManualSync(aggregateStatus.data, "evercount"), true)
assert.equal(adapter.providerManualSync(aggregateStatus.data, "journal"), false)

const aggregateGates = adapter.prerequisites(aggregateStatus.data)
assert.deepEqual(Array.from(aggregateGates, gate => gate.gateId), [
  "selected-counter-before-distractions", "journal-before-distractions"
])
const metricRows = context.gateRows(multiplePrerequisiteStatus, aggregateGates)
const metricEvercount = metricRows.find(row => row.id === "selected-counter-before-distractions")
assert.equal(metricEvercount.provider, "evercount")
assert.equal(metricEvercount.metricUnit, "provider_units")
assert.equal(metricEvercount.used, 4.5)
assert.equal(metricEvercount.required, 5)
assert.equal(metricEvercount.satisfied, true)
assert.equal(metricEvercount.adapterSatisfied, false)

assert.equal(adapter.parseAggregateStatus(JSON.stringify({
  version: 1,
  provider: "evercount",
  health: "healthy"
})).ok, false)
assert.equal(adapter.parseAggregateStatus('{"version":1,"adapters":[]}').ok, true)
assert.equal(adapter.parseAggregateStatus('{"version":1,"adapters":"old"}').ok, false)
assert.equal(adapter.parseAggregateStatus('{"version":2,"adapters":[]}').ok, false)
assert.equal(adapter.parseAggregateStatus("not json").ok, false)
const mismatchedMetricDocument = JSON.parse(JSON.stringify(aggregateDocument))
mismatchedMetricDocument.adapters[0].prerequisites[0].requirement.unit = "seconds"
assert.equal(adapter.parseAggregateStatus(JSON.stringify(mismatchedMetricDocument)).ok, false)
const duplicateGateDocument = JSON.parse(JSON.stringify(aggregateDocument))
duplicateGateDocument.adapters[1].prerequisites[0].gateId =
  duplicateGateDocument.adapters[0].prerequisites[0].gateId
assert.equal(adapter.parseAggregateStatus(JSON.stringify(duplicateGateDocument)).ok, false)

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
