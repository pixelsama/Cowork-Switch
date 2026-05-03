# Cowork-Switch: Start Here

This folder contains two things:

- a local Anthropic-compatible gateway for Claude Desktop
- a macOS menu bar app to manage providers and fake `/v1/models`

## 1. Start The Gateway Service

Requires Node.js 18+.

Run once manually:

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
node src/server.js
```

Check it:

```bash
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/_admin/status
```

Stop it with `Ctrl+C`.

## 2. Install It As A Login Service

Copy the LaunchAgent template:

```bash
cp launchd/com.pixelsama.cowork-switch.plist ~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
```

Replace:

```text
__NODE_PATH__   absolute path from: which node
__PROJECT_DIR__ absolute path to this folder
```

Load it:

```bash
plutil -lint ~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pixelsama.cowork-switch.plist
launchctl enable gui/$(id -u)/com.pixelsama.cowork-switch
launchctl kickstart -k gui/$(id -u)/com.pixelsama.cowork-switch
```

## 3. Build And Open The Menu Bar App

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
zsh scripts/build-macos-app.sh
open dist/CoworkSwitch.app
```

## 3.5 Package A Signed macOS Release

This project supports the same signing/notarization variable names used by `Free-Agent-Vtuber-Openclaw`.

Signed package:

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
brew install create-dmg
npm run package:macos:signed
```

Offline dry run:

```bash
cd /Users/pixelsama/deepseek-anthropic-proxy
SKIP_NOTARIZATION=1 npm run package:macos:signed
```

If Apple notarization returns `403` about missing or expired agreements, fix the Apple Developer agreements first and rerun the package command.

The DMG installer UI is generated with `create-dmg`, so the released disk image opens with a background, app icon placement, and an `Applications` drag target.

The menu bar app lets you:

- see whether the gateway is running
- switch the active Anthropic-compatible provider
- choose whether `/v1/models` should be faked or passed through
- edit fake model IDs for providers like DeepSeek

## 4. Configure Claude Desktop

```text
Provider: Gateway / Anthropic-compatible
Gateway base URL: http://127.0.0.1:8787
Gateway API key: your provider API key
Gateway auth scheme: bearer
```

## When To Fake `/v1/models`

- If the upstream provider does not implement `/v1/models`, enable fake models and fill in model IDs.
- If the upstream provider already supports `/v1/models`, disable fake models and let the gateway pass the request upstream untouched.
