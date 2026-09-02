.pragma library

var SUPPORTED_ADAPTER_STATUS_VERSION = 1
var KNOWN_HEALTH = [
  "healthy", "never_synchronized", "unavailable", "incompatible", "inactive"
]
var KNOWN_UNITS = ["completions", "seconds", "provider_units"]
var KNOWN_TRANSPORTS = ["observable", "scheduled_pull", "push", "manual_only"]

function stringValue(value) {
  return value === null || value === undefined ? "" : String(value)
}

function numberValue(value) {
  return typeof value === "number" && isFinite(value) ? value : null
}

function emptyStatus() {
  return { version: SUPPORTED_ADAPTER_STATUS_VERSION, adapters: [] }
}

function normalizeError(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null
  return {
    code: stringValue(value.code),
    message: stringValue(value.message),
    action: stringValue(value.action),
    retryable: value.retryable === true,
    occurredAt: stringValue(value.occurredAt)
  }
}

function normalizePrerequisite(value, adapterId) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    return { ok: false, error: "Invalid adapter prerequisite status" }
  var gateId = stringValue(value.gateId)
  var progress = value.progress
  var requirement = value.requirement
  var kind = stringValue(value.kind)
  if (!gateId || !stringValue(value.source)
      || (kind !== "completion" && kind !== "duration")
      || !progress || typeof progress !== "object"
      || !requirement || typeof requirement !== "object"
      || !Array.isArray(value.targets))
    return { ok: false, error: "Invalid adapter prerequisite status" }
  var progressValue = numberValue(progress.value)
  var requirementValue = numberValue(requirement.value)
  var unit = stringValue(progress.unit)
  if (progressValue === null || progressValue < 0 || requirementValue === null
      || requirementValue <= 0 || unit !== stringValue(requirement.unit)
      || KNOWN_UNITS.indexOf(unit) < 0)
    return { ok: false, error: "Invalid adapter prerequisite metric" }
  var targets = value.targets.map(stringValue)
  return {
    ok: true,
    data: {
      id: gateId,
      gateId: gateId,
      providerId: adapterId,
      source: stringValue(value.source),
      kind: kind,
      progress: progressValue,
      requirement: requirementValue,
      unit: unit,
      satisfied: value.satisfied === true,
      synchronized: value.synchronized === true,
      targetIds: targets
    }
  }
}

function normalizeAdapter(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)
      || Number(value.version) !== SUPPORTED_ADAPTER_STATUS_VERSION)
    return { ok: false, error: "Unsupported adapter status version" }
  var adapterId = stringValue(value.adapterId)
  if (!adapterId || !stringValue(value.displayName) || !stringValue(value.policyDate)
      || KNOWN_TRANSPORTS.indexOf(stringValue(value.transport)) < 0
      || typeof value.manualSync !== "boolean" || !Array.isArray(value.prerequisites))
    return { ok: false, error: "Invalid adapter status response" }
  var health = stringValue(value.health)
  if (KNOWN_HEALTH.indexOf(health) < 0)
    return { ok: false, error: "Invalid adapter health" }
  var gates = []
  var gateIds = {}
  for (var index = 0; index < value.prerequisites.length; index++) {
    var parsed = normalizePrerequisite(value.prerequisites[index], adapterId)
    if (!parsed.ok) return parsed
    if (gateIds[parsed.data.gateId])
      return { ok: false, error: "Duplicate adapter prerequisite ID" }
    gateIds[parsed.data.gateId] = true
    gates.push(parsed.data)
  }
  if (value.error !== null && value.error !== undefined
      && (!value.error || typeof value.error !== "object" || Array.isArray(value.error)))
    return { ok: false, error: "Invalid adapter error status" }
  var error = normalizeError(value.error)
  if (error && (!error.code || !error.message || !error.action || !error.occurredAt))
    return { ok: false, error: "Invalid adapter error status" }
  return {
    ok: true,
    data: {
      id: adapterId,
      adapterId: adapterId,
      label: stringValue(value.displayName),
      health: health,
      policyDate: stringValue(value.policyDate),
      transport: stringValue(value.transport),
      manualSync: value.manualSync === true,
      synchronized: gates.length > 0 && gates.every(function(gate) {
        return gate.synchronized
      }),
      prerequisites: gates,
      lastTrigger: stringValue(value.lastTrigger),
      lastAttemptAt: stringValue(value.lastAttemptAt),
      lastReadAt: stringValue(value.lastSuccessfulReadAt),
      lastSyncAt: stringValue(value.lastSuccessfulSyncAt),
      nextSyncAt: stringValue(value.nextScheduledSyncAt),
      errorCode: error ? error.code : "",
      errorMessage: error ? error.message : "",
      errorAction: error ? error.action : "",
      errorRetryable: error ? error.retryable : false,
      errorOccurredAt: error ? error.occurredAt : ""
    }
  }
}

function parseAggregateStatus(raw) {
  try {
    var value = JSON.parse(stringValue(raw))
    if (!value || typeof value !== "object" || Array.isArray(value)
        || Number(value.version) !== SUPPORTED_ADAPTER_STATUS_VERSION
        || !Array.isArray(value.adapters))
      return { ok: false, error: "Unsupported aggregate adapter status response" }
    var result = []
    var adapterIds = {}
    var gateIds = {}
    for (var index = 0; index < value.adapters.length; index++) {
      var parsed = normalizeAdapter(value.adapters[index])
      if (!parsed.ok) return parsed
      if (adapterIds[parsed.data.adapterId])
        return { ok: false, error: "Duplicate adapter ID" }
      adapterIds[parsed.data.adapterId] = true
      for (var gateIndex = 0; gateIndex < parsed.data.prerequisites.length; gateIndex++) {
        var gateId = parsed.data.prerequisites[gateIndex].gateId
        if (gateIds[gateId])
          return { ok: false, error: "Duplicate aggregate prerequisite ID" }
        gateIds[gateId] = true
      }
      result.push(parsed.data)
    }
    return {
      ok: true,
      data: { version: SUPPORTED_ADAPTER_STATUS_VERSION, adapters: result },
      error: ""
    }
  } catch (error) {
    return { ok: false, error: "Invalid aggregate adapter status JSON" }
  }
}

function providers(status) {
  return status && Array.isArray(status.adapters) ? status.adapters : []
}

function prerequisites(status) {
  var result = []
  providers(status).forEach(function(provider) {
    var gates = Array.isArray(provider.prerequisites) ? provider.prerequisites : []
    gates.forEach(function(gate) {
      result.push({
        id: gate.gateId,
        gateId: gate.gateId,
        providerId: provider.adapterId,
        source: gate.source,
        kind: gate.kind,
        progress: gate.progress,
        requirement: gate.requirement,
        unit: gate.unit,
        satisfied: gate.satisfied,
        synchronized: gate.synchronized,
        targetIds: gate.targetIds
      })
    })
  })
  return result
}

function providerManualSync(status, adapterId) {
  var expected = stringValue(adapterId)
  return providers(status).some(function(provider) {
    return provider.adapterId === expected && provider.manualSync === true
  })
}
