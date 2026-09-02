# Prerequisite Provider Boundary

The panel uses two provider-neutral Sundown contracts with separate duties:

- `sundown status --json` remains authoritative for restrictions and whether
  every prerequisite permits an allowance.
- `sundown adapters status --json` supplies adapter operation, provider metric
  progress, freshness, manual-sync capability, and actionable errors.

Provider health never grants access. An allowance is shown as unlocked only
when every core gate targeting it is synchronized and satisfied.

`PrerequisiteAdapter.js` is the adapter-status boundary. `TodayView.qml`
receives normalized provider and gate rows and does not parse command payloads.

## Stable keys and normalized shapes

Provider rows use the contract's `adapterId` as `id` and its `displayName` as
`label`:

```json
{
  "id": "evercount",
  "label": "Evercount",
  "health": "healthy",
  "synchronized": true,
  "lastReadAt": "2026-09-02T09:10:00-05:00",
  "lastSyncAt": "2026-09-02T09:10:01-05:00",
  "errorMessage": "",
  "errorAction": "",
  "manualSync": true
}
```

Provider prerequisite rows retain the stable `gateId`, `adapterId`, semantic
source, target IDs, and contract metric:

```json
{
  "gateId": "prayer-before-gaming",
  "providerId": "evercount",
  "source": "/services/evercount/prayer-daily-goal",
  "progress": 4.5,
  "requirement": 5,
  "unit": "provider_units",
  "satisfied": false,
  "synchronized": true,
  "targetIds": ["steam"]
}
```

The panel accepts `completions`, `seconds`, and `provider_units` without
converting between them. It joins provider metrics to current core gate rows by
the globally unique `gateId`. The core gate still decides `satisfied`,
`synchronized`, and allowance readiness; the aggregate metric controls only
the progress presentation. An aggregate prerequisite with no current core gate
is not presented as a current restriction.

## Health, freshness, and errors

The panel renders the version 1 health values `healthy`,
`never_synchronized`, `unavailable`, `incompatible`, and `inactive`.
`lastSuccessfulSyncAt` becomes the displayed last-sync time because it records
an acknowledged Sundown reconciliation. When no successful sync exists but
`lastSuccessfulReadAt` does, the panel identifies that provider read without
claiming synchronization.

When `error` is present, the panel shows both its sanitized `message` and its
concrete `action`. `retryable` remains descriptive contract data; it does not
create a polling or retry loop.

## Manual sync boundary

Adapter-status version 1 has no generic mutation command. The existing
Evercount action therefore remains explicitly mapped:

```text
adapterId: evercount
command: /usr/bin/sundown-adapter-evercount sync
```

The action and its keyboard shortcut are available only when the matching
provider row publishes `manualSync: true`. Other providers require their own
documented command mapping before the panel can expose a manual action.

## Compatibility and failure behavior

The published consumer contract requires the aggregate command and does not
define a provider-specific compatibility fallback. The panel therefore never
invokes `sundown-adapter-evercount status` and never reads adapter state files.

An empty valid `adapters` array means no adapter has published status. A command
failure, malformed document, legacy direct-adapter document, unsupported
version, or duplicate stable ID is an error instead. After a successful load,
such an error preserves the last valid aggregate snapshot while surfacing the
refresh failure. Before the first successful load, provider status remains
absent; the panel does not manufacture an empty provider snapshot.

This boundary keeps future integration narrow: a new provider needs to publish
the aggregate version 1 fields and, only if manual mutation is desired, add one
explicit provider-command mapping. The panel, History view, and policy model do
not need another surface or provider-specific status parser.
