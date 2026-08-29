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
      active_rule: null,
      rules: []
    }
  }
}

function emptyReport() {
  return {
    version: 1,
    range: "week",
    start_date: "",
    end_date: "",
    recorded_days: 0,
    days: [],
    totals: { steam_seconds: 0, web_seconds: {} },
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
  return { ok: true, data: value, error: "" }
}

function parseReport(raw) {
  var parsed = parseObject(raw, "report")
  if (!parsed.ok) return parsed
  var value = parsed.data
  value.days = Array.isArray(value.days) ? value.days : []
  value.totals = value.totals || { steam_seconds: 0, web_seconds: {} }
  value.totals.web_seconds = value.totals.web_seconds || {}
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

function budgetRow(id, label, value) {
  var limit = Math.max(0, number(value.daily_limit_seconds, 0))
  var used = Math.max(0, number(value.used_seconds, 0))
  var remaining = Math.max(0, number(value.remaining_seconds, Math.max(0, limit - used)))
  return {
    id: id,
    label: label,
    used: used,
    limit: limit,
    remaining: remaining,
    ratio: limit > 0 ? clamp(used / limit, 0, 1) : 0,
    active: value.active === true,
    reached: value.limit_reached === true || (limit > 0 && remaining <= 0),
    warningMinutes: value.next_warning_minutes === null || value.next_warning_minutes === undefined
      ? null : Math.max(0, number(value.next_warning_minutes, 0))
  }
}

function budgetRows(status) {
  status = status || emptyStatus()
  var rows = [budgetRow("steam", "Steam", status.steam || {})]
  var rules = status.web && Array.isArray(status.web.rules) ? status.web.rules : []
  for (var i = 0; i < rules.length; i++) {
    var rule = rules[i] || {}
    rows.push(budgetRow(String(rule.name || "website-" + i), titleForRule(rule.name), rule))
  }
  return rows
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
  return Math.max(0, total)
}

function recordedDaysLabel(count) {
  var total = Math.max(0, Math.floor(number(count, 0)))
  return total + " recorded " + (total === 1 ? "day" : "days")
}
