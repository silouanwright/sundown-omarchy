# Release Checklist

- Run `node tests/model.test.js`.
- Run `tests/run-qml-checks` in an Omarchy session.
- Run `tests/run-qt-quick-tests`.
- Run `omarchy plugin validate .`.
- Run the deterministic QML review and system `qmllint` where available.
- Confirm `manifest.json` and the README describe the same compatibility range.
- Confirm the root README, license, manifest, and preview are present.
- Install from the public repository with `omarchy plugin add`.
- Update an existing checkout with `omarchy plugin update` and verify it
  fast-forwards without changing user configuration.
- Verify the `sundown-panel` IPC target and inspect Omarchy Shell logs for QML
  errors.
- Exercise schedule, prerequisite, earned-time, and flex-pass states against a
  compatible Sundown core. Exercise valid, empty, malformed, and unavailable
  `sundown adapters status --json` results; confirm stable adapter/gate IDs,
  metric units, actionable errors, and `manualSync` gating. Confirm keyboard
  selection scrolls the selected flex action into view before activation.
- Capture the panel in at least two Omarchy themes, including a fullscreen
  application, and check text contrast, truncation, spacing, and maximum
  height.
- If submitting to the marketplace, provide the exact tested commit and the
  install, update, removal, permissions, privacy, and dependency evidence.

The marketplace is optional. Omarchy supports direct git installation from
this repository.
