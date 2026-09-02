.pragma library

var SUPPORTED_PROVIDER_STATUS_VERSION = 1

function stringValue(value) {
  return value === null || value === undefined ? "" : String(value)
}

function title(value) {
  return stringValue(value || "provider").split(/[-_]/).map(function(part) {
    return part ? part.charAt(0).toUpperCase() + part.slice(1) : ""
  }).join(" ")
}

function providerIdForSource(source) {
  var value = stringValue(source).toLowerCase()
  if (value.indexOf("/services/evercount/") === 0) return "evercount"
  if (value.indexOf("/apps/voice-journal/") === 0) return "journal"
  var parts = value.split("/").filter(function(part) { return part !== "" })
  return parts.length >= 2 ? parts[1] : ""
}

function providerLabel(id) {
  if (id === "evercount") return "Evercount"
  if (id === "journal") return "Journal"
  return title(id)
}

function health(value) {
  var normalized = stringValue(value).toLowerCase().replace(/-/g, "_")
  var known = ["healthy", "never_synchronized", "unavailable", "incompatible", "inactive"]
  return known.indexOf(normalized) >= 0 ? normalized : "unknown"
}

function normalizedProvider(value, fallbackId) {
  value = value || {}
  var id = stringValue(value.id || value.provider || fallbackId).toLowerCase()
  return {
    id: id,
    label: stringValue(value.label) || providerLabel(id),
    health: health(value.health),
    synchronized: value.synchronized === true,
    lastSyncAt: stringValue(value.last_sync_at || value.lastSyncAt
      || value.last_successful_delivery_at || value.lastSuccessfulDeliveryAt),
    lastAttemptAt: stringValue(value.last_attempt_at || value.lastAttemptAt),
    message: stringValue(value.message || value.last_error || value.lastError),
    manualSync: value.manual_sync === true || value.manualSync === true
  }
}

function parseDirectStatus(raw, expectedProvider) {
  try {
    var value = JSON.parse(stringValue(raw))
    if (!value || typeof value !== "object" || Array.isArray(value))
      return { ok: false, error: "Invalid provider status response" }
    if (Number(value.version) !== SUPPORTED_PROVIDER_STATUS_VERSION)
      return { ok: false, error: "Unsupported provider status version" }
    var provider = normalizedProvider(value, expectedProvider)
    if (!provider.id || (expectedProvider && provider.id !== expectedProvider))
      return { ok: false, error: "Unexpected provider status response" }
    provider.manualSync = provider.id === "evercount"
    provider.synchronized = provider.lastSyncAt !== ""
    return { ok: true, provider: provider, error: "" }
  } catch (error) {
    return { ok: false, error: "Invalid provider status JSON" }
  }
}

function unavailableProvider(id, message) {
  return normalizedProvider({
    id: id,
    health: "unavailable",
    message: message,
    manualSync: id === "evercount"
  }, id)
}

function failedProvider(previous, id, message) {
  previous = previous || unavailableProvider(id, message)
  return normalizedProvider({
    id: id,
    label: previous.label,
    health: "unavailable",
    synchronized: previous.synchronized,
    lastSyncAt: previous.lastSyncAt,
    lastAttemptAt: previous.lastAttemptAt,
    message: message,
    manualSync: id === "evercount"
  }, id)
}

function rawGates(status) {
  status = status || {}
  var rows = []
  var groups = [status.completion_gates, status.duration_gates]
  groups.forEach(function(group) {
    if (!Array.isArray(group)) return
    group.forEach(function(gate) { rows.push(gate || {}) })
  })
  return rows
}

function providerIds(status) {
  var result = []
  rawGates(status).forEach(function(gate) {
    var id = providerIdForSource(gate.source)
    if (id && result.indexOf(id) < 0) result.push(id)
  })
  return result
}

function canonicalProviders(status) {
  var source = status && Array.isArray(status.prerequisite_providers)
    ? status.prerequisite_providers : []
  var result = {}
  source.forEach(function(value) {
    var provider = normalizedProvider(value)
    if (provider.id) result[provider.id] = provider
  })
  return result
}

function hasCanonicalProvider(status, id) {
  return canonicalProviders(status)[String(id || "").toLowerCase()] !== undefined
}

function providers(status, directProviders) {
  var canonical = canonicalProviders(status)
  var direct = directProviders || {}
  var gates = rawGates(status)
  return providerIds(status).map(function(id) {
    var selected = canonical[id] || direct[id] || normalizedProvider({ id: id }, id)
    var providerGates = gates.filter(function(gate) {
      return providerIdForSource(gate.source) === id
    })
    var synchronized = providerGates.length > 0 && providerGates.every(function(gate) {
      return gate.synchronized !== false
    })
    return {
      id: selected.id,
      label: selected.label,
      health: selected.health,
      synchronized: canonical[id] ? selected.synchronized : synchronized,
      lastSyncAt: selected.lastSyncAt,
      lastAttemptAt: selected.lastAttemptAt,
      message: selected.message,
      manualSync: selected.manualSync || id === "evercount"
    }
  })
}
