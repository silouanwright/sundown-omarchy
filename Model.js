.pragma library

var SUPPORTED_PROTOCOL_VERSION = 1

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : (fallback === undefined ? 0 : fallback)
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function emptyStatus() {
  return {
    version: 1,
    observed_at: "",
    mode: "unknown",
    runtime: { support_level: "unknown" },
    steam: {
      daily_limit_seconds: 0,
      used_seconds: 0,
      remaining_seconds: 0,
      limit_reached: false,
      active: false,
      next_warning_minutes: null
    },
    curfew: {
      active: false,
      seconds_until_start: null,
      next_warning_minutes: null,
      start: "",
      end: ""
    },
    morning: { enabled: false, active: false, start: "", end: "" },
    web: {
      healthy: false,
      enforcement_ready: false,
      browser_active: false,
      active_rule: null,
      rules: []
    },
    apps: { healthy: false, groups: [] },
    flex: { enabled: false, pass_seconds: 0, remaining_uses: 0, eligible: [], redemptions: [] },
    gates: [],
    completion_gates: [],
    duration_gates: [],
    earned: []
  }
}

function browserNeedsAttention(status) {
  var web = status && status.web ? status.web : emptyStatus().web
  return web.browser_active === true
    && (web.healthy !== true || web.enforcement_ready !== true)
}

function emptyReport() {
  return {
    version: 1,
    range: "week",
    start_date: "",
    end_date: "",
    recorded_days: 0,
    days: [],
    totals: { steam_seconds: 0, web_seconds: {}, app_seconds: {} },
    limit_hits: []
  }
}

function parseObject(raw, kind) {
  try {
    var value = JSON.parse(String(raw || ""))
    if (!value || typeof value !== "object" || Array.isArray(value))
      return { ok: false, compatibility: "", error: "Invalid " + kind + " response" }
    var version = number(value.version, 0)
    if (version < SUPPORTED_PROTOCOL_VERSION)
      return { ok: false, compatibility: "core-too-old", error: "Outdated Sundown core" }
    if (version > SUPPORTED_PROTOCOL_VERSION)
      return { ok: false, compatibility: "plugin-too-old", error: "Outdated Sundown panel" }
    return { ok: true, compatibility: "", data: value, error: "" }
  } catch (error) {
    return { ok: false, compatibility: "", error: "Invalid " + kind + " JSON" }
  }
}

function parseStatus(raw) {
  var parsed = parseObject(raw, "status")
  if (!parsed.ok) return parsed
  var value = parsed.data
  var fallback = emptyStatus()
  value.runtime = value.runtime || fallback.runtime
  value.steam = value.steam || fallback.steam
  value.curfew = value.curfew || fallback.curfew
  value.morning = value.morning || fallback.morning
  value.web = value.web || fallback.web
  value.web.rules = Array.isArray(value.web.rules) ? value.web.rules : []
  value.apps = value.apps || fallback.apps
  value.apps.groups = Array.isArray(value.apps.groups) ? value.apps.groups : []
  value.flex = value.flex || fallback.flex
  value.flex.eligible = Array.isArray(value.flex.eligible) ? value.flex.eligible : []
  value.flex.redemptions = Array.isArray(value.flex.redemptions) ? value.flex.redemptions : []
  value.gates = Array.isArray(value.gates) ? value.gates : []
  value.completion_gates = Array.isArray(value.completion_gates) ? value.completion_gates : []
  value.duration_gates = Array.isArray(value.duration_gates) ? value.duration_gates : []
  value.earned = Array.isArray(value.earned) ? value.earned : []
  return { ok: true, data: value, error: "" }
}

function parseReport(raw) {
  var parsed = parseObject(raw, "report")
  if (!parsed.ok) return parsed
  var value = parsed.data
  value.days = Array.isArray(value.days) ? value.days : []
  value.totals = value.totals || { steam_seconds: 0, web_seconds: {}, app_seconds: {} }
  value.totals.web_seconds = value.totals.web_seconds || {}
  value.totals.app_seconds = value.totals.app_seconds || {}
  value.limit_hits = Array.isArray(value.limit_hits) ? value.limit_hits : []
  return { ok: true, data: value, error: "" }
}

function titleForRule(name) {
  var known = {
    "social": "Social",
    "facebook": "Facebook",
    "youtube": "YouTube"
  }
  if (known[name]) return known[name]
  return String(name || "Website").split("-").map(function(part) {
    return part ? part.charAt(0).toUpperCase() + part.slice(1) : ""
  }).join(" ")
}

function targetLabel(target, status) {
  if (String(target || "").toLowerCase() === "steam")
    return titleForRule(status && status.steam && status.steam.name || "steam")
  var parts = String(target || "").split(":")
  return titleForRule(parts.length > 1 ? parts.slice(1).join(":") : parts[0])
}

function evidenceSourceLabel(source, fallbackName) {
  var known = {
    "/apps/voice-journal/daily-entry": "Journal",
    "/apps/voice-journal/recorded-duration": "Journal"
  }
  return known[String(source || "")] || titleForRule(fallbackName || "Prerequisite")
}

function evidenceProvider(source) {
  var value = String(source || "").toLowerCase()
  if (value.indexOf("/services/evercount/") === 0) return "evercount"
  if (value.indexOf("/apps/voice-journal/") === 0) return "journal"
  return ""
}

function gateForTarget(status, target) {
  var gates = gateRows(status)
  for (var i = 0; i < gates.length; i++) {
    var targets = gates[i].targetIds
    if (targets.some(function(candidate) {
      return String(candidate).toLowerCase() === String(target).toLowerCase()
    })) return gates[i]
  }
  return null
}

function budgetRow(id, label, value, status) {
  var restricted = value.daily_limit_seconds !== null && value.daily_limit_seconds !== undefined
  var baseLimit = restricted ? Math.max(0, number(value.daily_limit_seconds, 0)) : 0
  var limit = restricted ? baseLimit
    + Math.max(0, number(value.flex_granted_seconds, 0))
    + Math.max(0, number(value.earned_granted_seconds, 0)) : 0
  var used = Math.max(0, number(value.used_seconds, 0))
  var dailyRemaining = restricted ? Math.max(0, limit - used) : 0
  var remaining = restricted ? Math.max(0, number(value.available_seconds,
    number(value.remaining_seconds, dailyRemaining))) : 0
  var blockedBy = value.blocked_by || ""
  var gate = gateForTarget(status, id)
  var prerequisiteChecking = gate !== null && gate.synchronized === false
  var prerequisiteLocked = gate !== null && gate.synchronized !== false && gate.satisfied !== true
  var schedule = value.schedule || null
  var pace = value.pace || null
  var paceUsed = pace ? Math.max(0, number(pace.used_seconds, 0)) : 0
  var paceLimit = pace ? Math.max(0, number(pace.limit_seconds, 0)) : 0
  var paceRemaining = pace ? Math.max(0, number(pace.remaining_seconds,
    Math.max(0, paceLimit - paceUsed))) : 0
  var dailyIsBinding = pace && dailyRemaining < paceRemaining
  var meterUsed = pace && !dailyIsBinding ? paceUsed : used
  var meterLimit = pace && !dailyIsBinding ? paceLimit : limit
  return {
    id: id,
    label: label,
    restricted: restricted,
    used: used,
    limit: limit,
    remaining: remaining,
    dailyRemaining: dailyRemaining,
    ratio: limit > 0 ? clamp(used / limit, 0, 1) : 0,
    meterUsed: meterUsed,
    meterLimit: meterLimit,
    meterRatio: meterLimit > 0 ? clamp(meterUsed / meterLimit, 0, 1) : 0,
    meterScope: pace && !dailyIsBinding ? "rolling" : "daily",
    active: value.active === true,
    blocked: blockedBy !== "" || prerequisiteLocked || value.action_due === true,
    reached: blockedBy === "daily-limit" || value.limit_reached === true,
    blockedBy: blockedBy,
    gate: gate,
    prerequisiteChecking: prerequisiteChecking,
    prerequisiteLocked: prerequisiteLocked,
    schedule: schedule,
    pace: pace,
    flexRemaining: Math.max(0, number(value.flex_remaining_seconds, 0)),
    earnedBank: Math.max(0, number(value.earned_bank_seconds, 0)),
    warningMinutes: value.next_warning_minutes === null || value.next_warning_minutes === undefined
      ? null : Math.max(0, number(value.next_warning_minutes, 0))
  }
}

function budgetRows(status) {
  status = status || emptyStatus()
  var rows = [budgetRow("steam", titleForRule(status.steam && status.steam.name || "steam"), status.steam || {}, status)]
  var rules = status.web && Array.isArray(status.web.rules) ? status.web.rules : []
  for (var i = 0; i < rules.length; i++) {
    var rule = rules[i] || {}
    rows.push(budgetRow("web:" + String(rule.name || "website-" + i), titleForRule(rule.name), rule, status))
  }
  var groups = status.apps && Array.isArray(status.apps.groups) ? status.apps.groups : []
  for (var j = 0; j < groups.length; j++) {
    var group = groups[j] || {}
    if (group.shared_with_steam === true) continue
    var row = budgetRow("app:" + String(group.name || "application-" + j), titleForRule(group.name), group, status)
    if (row.restricted) rows.push(row)
  }
  return rows
}

function budgetDetail(row) {
  row = row || {}
  if (row.restricted === false) return "Observed activity"
  if (row.prerequisiteChecking) return "Checking " + (row.gate || {}).source + " activity"
  if (row.prerequisiteLocked) {
    var prerequisite = row.gate || {}
    if (prerequisite.kind === "count")
      return "Locked · " + String(prerequisite.remaining) + " more " + prerequisite.source
        + (prerequisite.remaining === 1 ? " entry needed" : " entries needed")
    return "Locked · " + formatDuration(prerequisite.remaining) + " of " + prerequisite.source + " needed"
  }
  if (row.blockedBy === "schedule") return "Outside schedule"
  if (row.blockedBy === "prerequisite-gate") {
    var gate = row.gate || {}
    if (gate.synchronized === false) return "Syncing " + gate.source
    if (gate.kind === "count")
      return String(gate.remaining) + " more " + gate.source + (gate.remaining === 1 ? " entry needed" : " entries needed")
    return formatDuration(gate.remaining) + " of " + gate.source + " needed"
  }
  if (row.blockedBy === "pace-limit") return "Rolling limit reached"
  if (row.blockedBy === "daily-limit") return "Blocked for today"
  if (row.pace) {
    if (row.meterScope === "daily")
      return formatDuration(row.dailyRemaining) + " remaining today"
    var paceRemaining = Math.max(0, number(row.pace.remaining_seconds, 0))
    return paceRemaining > 0
      ? formatDuration(paceRemaining) + " rolling remaining"
      : "Rolling allowance spent"
  }
  return formatDuration(row.remaining) + " remaining"
}

function gateRows(status) {
  status = status || emptyStatus()
  var rows = []
  var gates = Array.isArray(status.gates) ? status.gates : []
  gates.forEach(function(gate) {
    var required = Math.max(0, number(gate.required_seconds, 0))
    var used = Math.max(0, number(gate.used_seconds, 0))
    var targetIds = Array.isArray(gate.targets) ? gate.targets : []
    rows.push({
      kind: "duration",
      name: String(gate.name || "Prerequisite"),
      source: titleForRule(gate.source_group),
      targetIds: targetIds,
      targets: targetIds.map(function(target) {
        return targetLabel(target, status)
      }).join(", "),
      used: used,
      required: required,
      remaining: Math.max(0, number(gate.remaining_seconds, required - used)),
      ratio: required > 0 ? clamp(used / required, 0, 1) : 0,
      synchronized: true,
      satisfied: gate.satisfied === true
    })
  })
  var completionGates = Array.isArray(status.completion_gates) ? status.completion_gates : []
  completionGates.forEach(function(gate) {
    var required = Math.max(0, number(gate.required_completions, 0))
    var used = Math.max(0, number(gate.active_completions, 0))
    var targetIds = Array.isArray(gate.targets) ? gate.targets : []
    rows.push({
      kind: "count",
      name: String(gate.name || "Prerequisite"),
      source: evidenceSourceLabel(gate.source, gate.name),
      provider: evidenceProvider(gate.source),
      targetIds: targetIds,
      targets: targetIds.map(function(target) { return targetLabel(target, status) }).join(", "),
      used: used,
      required: required,
      remaining: Math.max(0, number(gate.remaining_completions, required - used)),
      ratio: required > 0 ? clamp(used / required, 0, 1) : 0,
      synchronized: gate.synchronized !== false,
      satisfied: gate.satisfied === true
    })
  })
  var durationGates = Array.isArray(status.duration_gates) ? status.duration_gates : []
  durationGates.forEach(function(gate) {
    var required = Math.max(0, number(gate.required_seconds, 0))
    var used = Math.max(0, number(gate.recorded_seconds, 0))
    var targetIds = Array.isArray(gate.targets) ? gate.targets : []
    rows.push({
      kind: "duration",
      name: String(gate.name || "Prerequisite"),
      source: evidenceSourceLabel(gate.source, gate.name),
      provider: evidenceProvider(gate.source),
      targetIds: targetIds,
      targets: targetIds.map(function(target) { return targetLabel(target, status) }).join(", "),
      used: used,
      required: required,
      remaining: Math.max(0, number(gate.remaining_seconds, required - used)),
      ratio: required > 0 ? clamp(used / required, 0, 1) : 0,
      synchronized: gate.synchronized !== false,
      satisfied: gate.satisfied === true
    })
  })
  return rows
}

function earnedRows(status) {
  var earned = status && Array.isArray(status.earned) ? status.earned : []
  return earned.map(function(value) {
    var cap = Math.max(0, number(value.bank_cap_seconds, 0))
    var bank = Math.max(0, number(value.bank_seconds, 0))
    return {
      name: titleForRule(value.name),
      source: titleForRule(value.source_group),
      target: targetLabel(value.target, status),
      bank: bank,
      cap: cap,
      ratio: cap > 0 ? clamp(bank / cap, 0, 1) : 0,
      earning: value.earning_now === true,
      suppressed: value.suppressed_by_target_activity === true
    }
  })
}

function flexTargets(status) {
  var flex = status && status.flex ? status.flex : emptyStatus().flex
  var eligible = Array.isArray(flex.eligible) ? flex.eligible : []
  return eligible.map(function(target) {
    return { target: String(target), label: targetLabel(target, status) }
  })
}

function flexAuditRows(status) {
  var flex = status && status.flex ? status.flex : emptyStatus().flex
  var redemptions = Array.isArray(flex.redemptions) ? flex.redemptions : []
  return redemptions.slice().reverse().map(function(redemption) {
    return {
      label: targetLabel(redemption.target, status),
      seconds: Math.max(0, number(redemption.granted_seconds, 0)),
      redeemedAt: String(redemption.redeemed_at || "")
    }
  })
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.floor(number(seconds, 0)))
  if (total === 0) return "0m"
  if (total < 60) return "<1m"
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  if (hours > 0 && minutes > 0) return hours + "h " + minutes + "m"
  if (hours > 0) return hours + "h"
  return minutes + "m"
}

function minutesUntil(value, now) {
  var target = new Date(String(value || ""))
  var current = now === undefined ? new Date() : new Date(now)
  if (isNaN(target.getTime()) || isNaN(current.getTime())) return null
  return Math.max(0, Math.ceil((target.getTime() - current.getTime()) / 60000))
}

function formatCountdown(seconds) {
  var total = Math.max(0, Math.floor(number(seconds, 0)))
  if (total < 60) return "under a minute"
  return formatDuration(total)
}

function totalToday(rows) {
  var total = 0
  for (var i = 0; i < rows.length; i++) total += number(rows[i].used, 0)
  return total
}

function parseDay(day) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(day || ""))
  if (!match) return null
  var date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])))
  return isNaN(date.getTime()) ? null : date
}

function dayKey(date) {
  return date.getUTCFullYear() + "-" + String(date.getUTCMonth() + 1).padStart(2, "0") + "-" + String(date.getUTCDate()).padStart(2, "0")
}

function totalForDay(day) {
  var total = number(day && day.steam && day.steam.used_seconds, 0)
  var web = day && Array.isArray(day.web) ? day.web : []
  for (var i = 0; i < web.length; i++) total += number(web[i] && web[i].used_seconds, 0)
  var apps = day && Array.isArray(day.apps) ? day.apps : []
  for (var j = 0; j < apps.length; j++) total += number(apps[j] && apps[j].used_seconds, 0)
  return Math.max(0, total)
}

function weekRows(report) {
  report = report || emptyReport()
  var days = Array.isArray(report.days) ? report.days : []
  var byDate = {}
  for (var i = 0; i < days.length; i++) {
    if (days[i] && days[i].date) byDate[String(days[i].date)] = days[i]
  }
  var end = parseDay(report.end_date)
  if (!end && days.length > 0) end = parseDay(days[days.length - 1].date)
  if (!end) return []
  var rows = []
  var letters = ["S", "M", "T", "W", "T", "F", "S"]
  for (var offset = 6; offset >= 0; offset--) {
    var date = new Date(end.getTime() - offset * 86400000)
    var key = dayKey(date)
    var source = byDate[key]
    rows.push({
      date: key,
      label: letters[date.getUTCDay()],
      recorded: !!source,
      seconds: source ? totalForDay(source) : 0
    })
  }
  return rows
}

function maximumDay(rows) {
  var maximum = 0
  for (var i = 0; i < rows.length; i++) maximum = Math.max(maximum, number(rows[i].seconds, 0))
  return Math.max(1, maximum)
}

function reportTotal(report) {
  report = report || emptyReport()
  var totals = report.totals || {}
  var total = number(totals.steam_seconds, 0)
  var web = totals.web_seconds || {}
  Object.keys(web).forEach(function(key) { total += number(web[key], 0) })
  var apps = totals.app_seconds || {}
  Object.keys(apps).forEach(function(key) { total += number(apps[key], 0) })
  return Math.max(0, total)
}

function reportCategories(report, status) {
  report = report || emptyReport()
  var totals = report.totals || {}
  var steam = status && status.steam || {}
  var shared = String(steam.shared_app_group || "")
  var apps = totals.app_seconds || {}
  var steamSeconds = number(totals.steam_seconds, 0) + (shared ? number(apps[shared], 0) : 0)
  var rows = [{ id: "steam", label: titleForRule(steam.name || "steam"), seconds: Math.max(0, steamSeconds) }]
  var web = totals.web_seconds || {}
  Object.keys(web).forEach(function(key) {
    rows.push({ id: "web:" + key, label: titleForRule(key), seconds: Math.max(0, number(web[key], 0)) })
  })
  Object.keys(apps).forEach(function(key) {
    if (shared && key.toLowerCase() === shared.toLowerCase()) return
    rows.push({ id: "app:" + key, label: titleForRule(key), seconds: Math.max(0, number(apps[key], 0)) })
  })
  return rows
}

function recordedDaysLabel(count) {
  var total = Math.max(0, Math.floor(number(count, 0)))
  return total + " recorded " + (total === 1 ? "day" : "days")
}
