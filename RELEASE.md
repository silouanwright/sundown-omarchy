# Release Checklist

- Run `node tests/model.test.js`.
- Run `omarchy plugin validate .`.
- Confirm `manifest.json` and the README describe the same compatibility range.
- Confirm the root README, license, manifest, and preview are present.
- Install from the public repository with `omarchy plugin add`.
- Update an existing checkout with `omarchy plugin update` and verify it
  fast-forwards without changing user configuration.
- Verify the `sundown-panel` IPC target and inspect Omarchy Shell logs for QML
  errors.
- If submitting to the marketplace, provide the exact tested commit and the
  install, update, removal, permissions, privacy, and dependency evidence.

The marketplace is optional. Omarchy supports direct git installation from
this repository.
