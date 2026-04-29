# Mobidex Internal Changelog

This changelog tracks Mobidex-specific product and integration history. It is intentionally founder-facing: what changed, why it mattered, and what must be protected in future upstream merges.

## 2026-04-28 / 2026-04-29 - Upstream Remodex April 26-28 integration

- Audited upstream `Emanuele-web04/remodex` commits from April 26, April 27, and April 28 in the US/Central release window.
- Merged the upstream feature line through `3da4d17` while preserving Mobidex-owned identity, local-first behavior, free access, and secure wire compatibility.
- Integrated upstream timeline and streaming stability work, including item-scoped assistant handling, replay dedupe, timeline projection, double-message fixes, automatic local title updates, and working-directory context in timeline rows.
- Integrated local project folder and new-chat workflow improvements, including bridge-side folder listing/validation/creation and iOS project picker/browser surfaces.
- Integrated plugin mention composer support and autocomplete refinements while keeping backward-compatible runtime fallbacks.
- Integrated Git initialization, git status/draft improvements, command/git draft UI support, and bridge-side git writer support.
- Integrated safe workspace image preview support with bridge-side path checks, recognized image extensions, size limits, and cache validation.
- Prepared release baseline as iOS version `1.3`, build `114`, with bridge package `mobidex@1.3.10`.
- Explicitly rejected upstream subscription/paywall artifacts so Mobidex remains free-access.
- Multi-device implementation was not merged because the actual multi-Mac product surface lives on a separate `codex/multi-device` branch rather than local `main`.

Protection notes:

- Keep visible naming as Mobidex / Mobi-Dex.
- Keep iOS bundle id `com.z360.mobidex`.
- Keep npm package and update commands on `mobidex`.
- Keep relay identity on `mobidex-relay`.
- Keep secure protocol tags `remodex-e2ee-v1` and `remodex-trusted-session-resolve-v1` unless every participant is migrated together.
- Do not restore RevenueCat, StoreKit, Pro gates, free-send counters, or subscription screens.

## 2026-04-28 - Project history recap

- Added `Docs/RECAP-project-progress.md` as a durable narrative recap of the Mobidex program.
- Captured the local-first architecture, white-labeling, pairing reliability, runtime capability direction, artifacts, loop controls, Sprint Runner, diagnostics, and free-access release posture.

## 2026-04-23 - Free-access release baseline

- Merged the Mobidex free-access release to `main`.
- Preserved app functionality while removing subscription access gates.
- Validated the release baseline with bridge, relay, static paywall residue, and iOS release gates before TestFlight upload.
- Established TestFlight baseline version `1.3`, build `113`.

## 2026-04-22 - Rebrand, relay, pairing, and release operations

- Rebranded the fork from Remodex/CodexMobile into Mobidex across visible product identity, iOS bundle identity, bridge launcher, npm package, relay deployment, and release runbook.
- Deployed and verified the Mobidex relay path.
- Fixed secure pairing compatibility after rebrand work by keeping legacy wire-format tags stable.
- Removed Pro/paywall functionality as access control rather than deleting core features.
- Documented release operations and TestFlight workflow.

## 2026-04-21 - Local-first Mobidex foundation

- Established the Mobidex white-label fork as a local-first iPhone control surface for a Mac-hosted Codex runtime.
- Set the product model: iPhone as controller, Mac bridge as runtime owner, relay as transport and optional push plumbing.
- Added Mobidex launcher and runtime identity support while preserving compatibility paths where needed.
