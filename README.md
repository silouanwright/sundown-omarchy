# Sundown for Omarchy

A native, read-only Omarchy bar panel for Sundown allowances, curfew state,
browser health, warnings, and seven-day Screen Time history.

![Sundown panel](docs/assets/live-panel.png)

Website allowances appear as compact group rows such as `Social`.
Constituent-domain accounting remains available in Sundown's JSON reports,
without crowding the panel. Healthy browser protection is silent; a browser
warning appears only when protection needs attention.

Sundown's Rust daemon remains authoritative. This independently versioned
plugin stores no policy or usage data and calls only:

```bash
sundown status --json
sundown report week --json
```

## Install

Install the Sundown core first. Then add this repository through Omarchy:

```bash
omarchy plugin add https://github.com/silouanwright/sundown-omarchy.git --enable
```

The panel is optional. Sundown's application limits and curfew continue to
work without Omarchy, and browser limits require Sundown's separately
package-managed Chromium integration rather than this plugin.

Update or remove it through the same Omarchy plugin manager:

```bash
omarchy plugin update io.github.silouanwright.sundown
omarchy plugin remove io.github.silouanwright.sundown
```

## Compatibility

Plugin `0.1.x` supports Sundown status/report protocol `1`. A lower protocol
version prompts the user to update the Sundown core; a higher version prompts
the user to update this plugin. The top-level `version` field in both JSON
commands is the protocol contract, independent of either package version.

## Development

```bash
node tests/model.test.js
omarchy plugin validate .
```

The plugin requires no third-party QML packages.

## Privacy and permissions

The plugin runs `/usr/bin/sundown status --json` and `/usr/bin/sundown report
week --json`. It has no installer, privileged actions, network access, or
persistent state. Usage policy, counters, browser integration, and enforcement
remain in the separately installed Sundown core.

## License

MIT
