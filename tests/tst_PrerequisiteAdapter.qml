import QtQuick
import QtTest
import "../PrerequisiteAdapter.js" as Adapter

TestCase {
  id: root
  name: "PrerequisiteAdapterTests"

  readonly property string aggregatePayload: JSON.stringify({
    version: 1,
    adapters: [{
      version: 1,
      adapterId: "evercount",
      displayName: "Evercount",
      health: "healthy",
      policyDate: "2026-09-02",
      transport: "scheduled_pull",
      manualSync: true,
      prerequisites: [{
        gateId: "prayer-before-gaming",
        source: "/services/evercount/prayer-daily-goal",
        kind: "completion",
        progress: { value: 4.5, unit: "provider_units" },
        requirement: { value: 5, unit: "provider_units" },
        satisfied: false,
        synchronized: true,
        targets: ["steam"]
      }],
      lastTrigger: "scheduled_pull",
      lastAttemptAt: "2026-09-02T09:01:00-05:00",
      lastSuccessfulReadAt: "2026-09-02T09:00:00-05:00",
      lastSuccessfulSyncAt: "2026-09-02T09:00:01-05:00",
      nextScheduledSyncAt: "2026-09-02T09:05:00-05:00",
      error: null
    }]
  })

  function test_aggregateUsesStableProviderAndGateIds() {
    const parsed = Adapter.parseAggregateStatus(root.aggregatePayload)
    verify(parsed.ok)
    compare(parsed.data.adapters[0].id, "evercount")
    compare(parsed.data.adapters[0].lastSyncAt, "2026-09-02T09:00:01-05:00")
    compare(Adapter.prerequisites(parsed.data)[0].gateId, "prayer-before-gaming")
    compare(Adapter.prerequisites(parsed.data)[0].unit, "provider_units")
    verify(Adapter.providerManualSync(parsed.data, "evercount"))
  }

  function test_legacyAndMalformedShapesAreRejected() {
    verify(!Adapter.parseAggregateStatus(JSON.stringify({
      version: 1,
      provider: "evercount",
      health: "healthy"
    })).ok)
    verify(!Adapter.parseAggregateStatus('{"version":1,"adapters":"old"}').ok)
    verify(!Adapter.parseAggregateStatus("not json").ok)
  }

  function test_emptyAggregateMeansNoPublishedStatus() {
    const parsed = Adapter.parseAggregateStatus('{"version":1,"adapters":[]}')
    verify(parsed.ok)
    compare(Adapter.providers(parsed.data).length, 0)
    compare(Adapter.prerequisites(parsed.data).length, 0)
  }
}
