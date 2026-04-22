# AGENTS.md (Local-First)

Keep this file and `CLAUDE.md` aligned.

This repo is local-first now. Do not reintroduce hosted-service assumptions, remote deployment runbooks, or hardcoded production domains.

## Core guardrails

- Prefer local Mac runtime, local bridge, QR pairing, and daemon workflows.
- Be an intraprendente agent: proactively inspect local code, protocol/schema, and official sources to confirm facts before replying; do not repeatedly stop to ask for confirmation when the next verification step is safe and obvious.
- Keep repo isolation by thread/project metadata and local `cwd`.
- Do not reintroduce filtering by selected repo in sidebar/content.
- Keep cross-repo open/create flow with automatic local context switch.
- Preserve single responsibility: shared logic belongs in services/coordinators, not duplicated in views.
- Treat this repo as open source: avoid junk code, placeholder hacks, noisy one-off workarounds, and low-signal docs.
- If you touch docs, keep them local-only and remove stale hosted-service notes instead of adding compatibility layers.
- Do not create one-off report markdown files in the repo root (security reports, audit notes, scratch summaries, etc.) unless the user explicitly asks for a file. Keep ad-hoc analysis in the chat.
- For open-source/self-hosted safety, do not log live relay `sessionId` values or other bearer-like pairing identifiers in server logs; redact or hash them instead.
- Keep user-facing answers compact by default unless the user explicitly asks for more detail.

## iOS runtime + timeline guardrails

- `turn/started` may not include a usable `turnId`: keep the per-thread running fallback.
- If Stop is tapped and `activeTurnIdByThread` is missing, resolve via `thread/read` before interrupting.
- On reconnect/background recover, rehydrate active turn state so Stop remains visible.
- Suppress benign background disconnect noise (`NWError.posix(.ECONNABORTED)`) and retry on foreground.
- Keep assistant rows item-scoped to avoid timeline flattening/reordering.
- Merge late reasoning deltas into existing rows; do not spawn fake extra "Thinking..." rows.
- Ignore late turn-less activity events when the turn is already inactive.
- Preserve item-aware history reconciliation instead of falling back to `turnId`-only matching.

## Local connection guardrails

- Prefer saved relay pairing and local connection state as the source of truth.
- Avoid hardcoded remote domains; default to local values or explicit user config.
- Keep pairing/auth UX stable: do not clear saved relay info too early during reconnect flows.
- Preserve reconnect behavior across relaunch when the local host session is still valid.
- Preserve the QR/local-relay pairing path: do not regress the scanner -> saved pairing -> connect flow by letting onboarding/auto-reconnect race manual scan control.
- For local relay recovery, keep resumed desktop-thread live mirroring and rollout fallback logic intact so reopened/running threads still recover state even when the rollout file is older than the recent-candidate window.

## Mobidex fork operating notes

This checkout is the Mobidex white-label fork of the original Remodex/CodexMobile app. Keep visible product naming as Mobidex, but keep secure wire-format protocol tags legacy-compatible with the bridge and relay. In particular, do not rename `remodex-e2ee-v1` or `remodex-trusted-session-resolve-v1` unless the iOS app, bridge, relay, and published npm package are migrated together. A previous Mobidex rename broke QR/code pairing because the iOS app verified a different transcript tag than the bridge signed.

Current live topology:

- iOS bundle id: `com.z360.mobidex`
- Apple team id: `K3H6JK29AN`
- App Store Connect app id: `6762963486`
- App Store/TestFlight listing name: `Mobi-Dex`; installed iOS display name: `Mobidex`
- App Store subtitle target: `Control Codex from your iPhone.`
- Fly app: `mobidex-relay`
- Relay health: `https://mobidex-relay.fly.dev/health`
- Relay websocket: `wss://mobidex-relay.fly.dev/relay`
- npm package: `mobidex`
- Current package/build baseline after pairing fix: npm `1.3.9`, iOS version `1.3`, build `113`

Important private/local files and secrets:

- `CodexMobile/BuildSupport/PrivateOverrides.xcconfig` is ignored and should contain the private default relay URL for local archives.
- `relay/fly.toml` is ignored and contains the Fly app config; public examples stay in `relay/fly.toml.example`.
- Fly secrets are the source of truth for APNs push in production. Secret names currently used: `MOBIDEX_ENABLE_PUSH_SERVICE`, `MOBIDEX_APNS_TEAM_ID`, `MOBIDEX_APNS_KEY_ID`, `MOBIDEX_APNS_BUNDLE_ID`, `MOBIDEX_APNS_PRIVATE_KEY`.
- Do not print or commit APNs private-key material. The APNs key file used during setup was under `/Users/ansar/Desktop/IOS-certificates/`; treat that directory as private.
- Firebase is not part of the current Mobidex push path. The relay uses direct APNs.

Current runtime model:

- The iPhone app is a controller. It does not run Codex itself.
- The Mac bridge runs Codex locally and connects to the Fly relay.
- The Fly relay is transport and optional push plumbing only; it should not become a hosted Codex runtime.
- The phone and bridge pair through QR/code bootstrap, then use trusted reconnect when the Mac identity and phone identity still match.
- If pairing fails with "The secure Mac signature could not be verified", first check for iOS/bridge wire-protocol tag drift or stale trusted-pair state before blaming Fly.
- The active Mac service label is `com.z360.mobidex.bridge`; the stale old label `com.remodex.bridge` should not be running.

## Build guardrails

- Do not run Xcode tests unless the user explicitly asks. Do not decide to run them on your own.
- Markdown files inside Xcode-synced groups can still produce harmless warnings.
- For small iOS/mobile fixes, prefer inspection and targeted edits over simulator runs by default.

## Local quick runbook

```bash
mobidex up
mobidex status --json
```

Source checkout fallback:

```bash
cd phodex-bridge
node ./bin/mobidex.js up
```

## Mobidex release runbook

Use this when creating a new internal TestFlight build for Ansar.

1. Verify the local bridge and relay:

```bash
mobidex status --json
curl -fsS https://mobidex-relay.fly.dev/health
```

2. If bridge package code changed, bump `phodex-bridge/package.json`, run bridge tests, and publish:

```bash
cd phodex-bridge
npm test
MOBIDEX_PACKAGE_DEFAULT_RELAY_URL="wss://mobidex-relay.fly.dev/relay" \
MOBIDEX_PACKAGE_DEFAULT_PUSH_SERVICE_URL="https://mobidex-relay.fly.dev" \
npm publish --access public
```

Publishing is a public registry action and may require npm browser auth/2FA.

3. For iOS changes, bump `CURRENT_PROJECT_VERSION` in `CodexMobile/CodexMobile.xcodeproj/project.pbxproj`. Keep `MARKETING_VERSION` at `1.3` unless intentionally shipping a new version line.

4. Build and smoke-test on the simulator before archiving:

```bash
xcodebuild -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro CLI,OS=26.2' \
  build
```

5. Archive and upload to App Store Connect/TestFlight:

```bash
rm -rf /tmp/Mobidex.xcarchive /tmp/Mobidex-upload
cat > /tmp/Mobidex-uploadOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>K3H6JK29AN</string>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <true/>
  <key>testFlightInternalTestingOnly</key>
  <true/>
</dict>
</plist>
PLIST

xcodebuild -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/Mobidex.xcarchive \
  archive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/Mobidex.xcarchive \
  -exportPath /tmp/Mobidex-upload \
  -exportOptionsPlist /tmp/Mobidex-uploadOptions.plist \
  -allowProvisioningUpdates
```

6. Verify in App Store Connect:

- App: `Mobi-Dex`
- TestFlight internal group: `Internal Testers`
- Expected state after processing: build row shows `Testing` or `Ready to Test`
- Ansar's internal tester account is `ansarullahanas@icloud.com`

7. Commit and push only the intentional source/docs changes. Leave unrelated untracked planning docs alone unless explicitly asked.
