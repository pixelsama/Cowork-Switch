# Cowork-Switch

Local Anthropic-compatible gateway for Claude Desktop, now with a macOS menu bar companion app.

## What It Does

- Proxies `POST /v1/messages` and related sub-routes to any Anthropic-compatible upstream provider.
- Supports multiple providers and lets you switch the active one.
- Includes built-in presets for DeepSeek and OpenRouter.
- Can fake `GET /v1/models` and `GET /v1/models/:id` when an upstream does not implement them.
- Can also pass `/v1/models` straight through to the upstream when fake models are disabled.
- Exposes local admin endpoints for the menu bar app:
  - `GET /_admin/status`
  - `GET /_admin/config`
  - `PUT /_admin/config`

## Runtime Pieces

- Node gateway source: [src](src)
- Menu bar app source: [macos-app/CoworkSwitch](macos-app/CoworkSwitch)
- Built app bundle: [dist/CoworkSwitch.app](dist/CoworkSwitch.app)
- Config file: `~/Library/Application Support/CoworkSwitch/config.json`

## Claude Desktop

Use the local gateway as:

```text
Provider: Gateway / Anthropic-compatible
Gateway base URL: http://127.0.0.1:8787
Gateway API key: your upstream provider key, or leave provider key stored in gateway config
Gateway auth scheme: bearer
```

## Provider Behavior

For each provider you can configure:

- `name`
- `providerKind` (`deepseek`, `openrouter`, or `generic`)
- `baseUrl`
- `apiKey`
- `useFakeModels`
- `fakeModels`

If `useFakeModels = true`, the gateway returns your local fake `/v1/models` list, even when the list is empty.

If `useFakeModels = false`, the gateway forwards `/v1/models` directly to the upstream provider.

## OpenRouter Preset

Cowork-Switch now includes an `OpenRouter` preset for Claude Code or Claude Desktop setups that want Anthropic-compatible routing through OpenRouter.

- Preset base URL: `https://openrouter.ai/api`
- Default `/v1/models` behavior: direct upstream passthrough
- Authentication: store your OpenRouter API key on the provider, or let the client send it as a bearer token

In the macOS app, use `Settings > Add Provider > Add OpenRouter Preset`, then make it the active provider.

## Background Service

The gateway is installed as:

```text
~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
```

Useful commands:

```bash
launchctl print gui/$(id -u)/com.pixelsama.cowork-switch
launchctl kickstart -k gui/$(id -u)/com.pixelsama.cowork-switch
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
tail -f /tmp/cowork-switch.out.log /tmp/cowork-switch.err.log
```

## Build The Menu Bar App

```bash
cd /path/to/Cowork-Switch
zsh scripts/build-macos-app.sh
open dist/CoworkSwitch.app
```

## Signed macOS Packaging

This project now follows the same local signing/notarization convention as `Free-Agent-Vtuber-Openclaw`.

The main variables are:

- `CSC_NAME`
- `APPLE_TEAM_ID`
- `APPLE_KEYCHAIN_PROFILE`

Default notarization profile:

```bash
otakuclaw-notary
```

Build signed release artifacts:

```bash
cd /path/to/Cowork-Switch
brew install create-dmg
npm run package:macos:signed
```

Dry run without notarization:

```bash
cd /path/to/Cowork-Switch
SKIP_NOTARIZATION=1 npm run package:macos:signed
```

Verify the packaged artifacts:

```bash
cd /path/to/Cowork-Switch
npm run verify:macos:package
```

Artifacts are written to:

```text
release/CoworkSwitch-<version>-arm64-mac.zip
release/CoworkSwitch-<version>-arm64-mac.dmg
release/checksums-macos.txt
```

Notes:

- If `CSC_NAME` is omitted and there is only one `Developer ID Application` certificate installed, the script auto-detects it.
- The DMG installer UI is generated with `create-dmg`, which adds the background, icon layout, and `Applications` drop target.
- If Apple notarization fails with `403 A required agreement is missing or has expired`, the Apple Developer account needs updated legal agreements before notarization will succeed.

The app shows:

- whether the gateway is reachable
- the currently active provider
- whether fake `/v1/models` is enabled
- a settings window for switching providers and editing fake model IDs

## Tests

```bash
npm test
npm run test:coverage
```
