# Working Context - Concorde EFB

This file tracks the active tasks, architecture, and current state of the Concorde EFB project for
development agents. Keep it updated right before ending a turn so subsequent agents can seamlessly
pick up.

## 1. Project Overview & Current State

The Flutter migration (originally tracked here as in-progress) is complete and has been the sole
codebase for a while — there is no React/TypeScript/Tauri code left in this repo. See
[AGENTS.md](AGENTS.md) for the full architecture reference; this file only tracks *current, active*
work.

* **Platform support**: Windows desktop (primary), macOS packaging, Android (AdMob), Web (GitHub
  Pages — marketing/changelog site only, not the full app).
* **Branch**: `main` (the old `flutter` migration branch has been merged/retired).
* **Version**: `3.4.10+44` (`pubspec.yaml`).
* **Theme**: app-wide light/dark retheme (unified `AppColors`, flat Material cards, single
  JetBrains Mono font) is complete — see AGENTS.md §7 for what changed and §8 for the "always
  route colors through `context.colors`" rule going forward.

## 2. Recent Actions & Commits (most recent first)

* Added a screenshot showcase carousel to the marketing landing page.
* Added a Discord link to the website nav/footer, and an in-app Discord invite.
* `SimBridgeLauncher.startWatching()`: poll for MSFS's own process every 5s and force-restart the
  telemetry bridge the moment it's detected running — fixes stale SimConnect connections when the
  app is opened well before the sim (see AGENTS.md §4 and §8 for the underlying "why").
* Aligned in-app checklist content with the Concorde manual's actual procedures; added a landing
  phase (`lib/data/checklist_data.dart`).
* Removed the disclaimer footer from the planner and monitor tabs.
* Fixed broken scrolling in the checklist tab.
* Moved the airport DB cache off `Documents` on Windows.
* Eagerly snap the default cruise FL to the known flight direction.
* Surfaced SimConnect bridge launch failures in the Flight Monitor UI (distinguishing "exe never
  launched" from "bridge up, waiting on SimConnect" — see `SimBridgeStatus` in
  `lib/core/sim_bridge_launcher.dart`).
* Wired the real app icon and polished Windows uninstaller metadata.
* Completed the app-wide retheme: unified `AppColors` (light/dark), flat Material cards
  (`EfbFlatCard`) replacing the old glassmorphism system, single JetBrains Mono font throughout —
  `UiTokens`, `EfbGlassContainer`, `AmbientGlow`, and Flight Monitor's separate `fm_theme.dart`
  dark cockpit palette were all deleted as part of this, not left dormant.

## 3. Immediate Next Steps

* No active in-progress task at the moment — check with the user before starting new work.
* General ongoing watch items: monitor SimConnect bridge reliability across MSFS 2020/2024 and
  Steam/MS Store variants; continue verifying checklist parity against the real Concorde manual as
  more procedures are added; visually spot-check new UI in both light and dark mode before calling
  a UI change done.

## 4. Key Rules

* Read [AGENTS.md](AGENTS.md) first for architecture, file map, and known gotchas — this file is
  only a rolling activity log, not the source of truth for how the app works.
* All colors must resolve through `context.colors` (`lib/core/app_colors.dart`) — never reintroduce
  hardcoded `Color(0x...)` literals or a static token class.
* `SimBridgeLauncher` only ever manages a bridge process it spawned itself — never touch an
  externally/manually run dev bridge.
* Run `flutter analyze` (must stay clean) and `flutter test` after changes; visually verify UI
  changes in the running app before reporting done.
* Update `public/changelog/entries.json` when user-visible behavior changes — it's the sole
  changelog now; README only links to it, don't reintroduce version history there.
