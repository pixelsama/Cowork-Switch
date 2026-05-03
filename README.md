# Claude Anthropic Gateway

Local Anthropic-compatible gateway for Claude Desktop, now with a macOS menu bar companion app.

## What It Does

- Proxies `POST /v1/messages` and related sub-routes to any Anthropic-compatible upstream provider.
- Supports multiple providers and lets you switch the active one.
- Can fake `GET /v1/models` and `GET /v1/models/:id` when an upstream does not implement them.
- Can also pass `/v1/models` straight through to the upstream when fake models are disabled.
- Exposes local admin endpoints for the menu bar app:
  - `GET /_admin/status`
  - `GET /_admin/config`
  - `PUT /_admin/config`

## Runtime Pieces

- Node gateway source: [src](/Users/pixelsama/deepseek-anthropic-proxy/src)
- Menu bar app source: [macos-app/ClaudeGatewayTray](/Users/pixelsama/deepseek-anthropic-proxy/macos-app/ClaudeGatewayTray)
- Built app bundle: [dist/ClaudeGatewayTray.app](/Users/pixelsama/deepseek-anthropic-proxy/dist/ClaudeGatewayTray.app)
- Config file: `/Users/pixelsama/Library/Application Support/ClaudeAnthropicGateway/config.json`

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
- `baseUrl`
- `apiKey`
- `useFakeModels`
- `fakeModels`

If `useFakeModels = true`, the gateway returns your local fake `/v1/models` list.

If `useFakeModels = false`, the gateway forwards `/v1/models` directly to the upstream provider.

## Background Service

The gateway is installed as:

```text
/Users/pixelsama/Library/LaunchAgents/com.pixelsama.deepseek-anthropic-proxy.plist
```

Useful commands:

```bash
launchctl print gui/$(id -u)/com.pixelsama.deepseek-anthropic-proxy
launchctl kickstart -k gui/$(id -u)/com.pixelsama.deepseek-anthropic-proxy
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.pixelsama.deepseek-anthropic-proxy.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pixelsama.deepseek-anthropic-proxy.plist
tail -f /tmp/deepseek-anthropic-proxy.out.log /tmp/deepseek-anthropic-proxy.err.log
```

## Build The Menu Bar App

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
zsh scripts/build-macos-app.sh
open dist/ClaudeGatewayTray.app
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
cd /Users/pixelsama/deepseek-anthropic-proxy
npm run package:macos:signed
```

Dry run without notarization:

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
SKIP_NOTARIZATION=1 npm run package:macos:signed
```

Verify the packaged artifacts:

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
npm run verify:macos:package
```

Artifacts are written to:

```text
release/ClaudeGatewayTray-<version>-arm64-mac.zip
release/ClaudeGatewayTray-<version>-arm64-mac.dmg
release/checksums-macos.txt
```

Notes:

- If `CSC_NAME` is omitted and there is only one `Developer ID Application` certificate installed, the script auto-detects it.
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
