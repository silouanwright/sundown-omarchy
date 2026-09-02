# Prerequisite Provider Boundary

The panel treats Sundown as the authority for policy and prerequisite progress.
It does not infer access from provider health. An allowance is unlocked only
when every gate that targets it is both synchronized and satisfied.

`PrerequisiteAdapter.js` is the compatibility boundary between provider data
and QML views. `TodayView.qml` receives normalized provider rows and does not
parse core or provider payloads itself.

## Normalized panel shape

Each provider row has this internal shape:

```json
{
  "id": "evercount",
  "label": "Evercount",
  "health": "healthy",
  "synchronized": true,
  "lastSyncAt": "2026-09-02T09:10:01-05:00",
  "lastAttemptAt": "2026-09-02T09:10:00-05:00",
  "message": "",
  "manualSync": true
}
```

Supported health values are `healthy`, `never_synchronized`, `unavailable`,
`incompatible`, `inactive`, and `unknown`. Synchronization describes whether
the evidence is current enough for policy evaluation. Health describes the
adapter or provider. They are deliberately separate.

## Current compatibility path

Protocol 1 status provides `completion_gates` and `duration_gates`. The panel
uses each gate's `source`, `targets`, `synchronized`, and `satisfied` fields to
group providers and evaluate every prerequisite for an allowance.

Evercount health currently comes from:

```text
sundown-adapter-evercount status
```

The adapter document maps into the panel shape as follows:

| Adapter field | Panel field |
| --- | --- |
| `provider` | `id` |
| `health` | `health` |
| `lastSuccessfulDeliveryAt` | `lastSyncAt` |
| `lastAttemptAt` | `lastAttemptAt` |
| `lastError` | `message` |

The successful delivery timestamp is used for last sync because it confirms
that normalized evidence reached Sundown. A successful provider read alone is
not enough.

Voice Journal does not currently expose a machine-readable health command.
The panel therefore shows gate synchronization from Sundown, `unknown` health,
and an unavailable last-sync time. It does not invent a timestamp from the
panel refresh time.

## Expected provider-neutral core mapping

A later core integration can add this optional top-level array to
`sundown status --json`:

```json
{
  "prerequisite_providers": [
    {
      "id": "evercount",
      "label": "Evercount",
      "health": "healthy",
      "synchronized": true,
      "last_sync_at": "2026-09-02T09:10:01-05:00",
      "last_attempt_at": "2026-09-02T09:10:00-05:00",
      "message": "",
      "manual_sync": true
    }
  ]
}
```

The normalization layer already prefers `prerequisite_providers` over direct
adapter documents. Integration should therefore be limited to producing this
array and, once all supported cores provide it, deleting the Evercount status
process and its transient controller state. `TodayView.qml`, `StatusRow.qml`,
and the allowance aggregation do not need to change.

The core must continue to expose individual gates. Provider rows report
operational state; they do not replace gate progress or decide whether an
allowance is unlocked.
