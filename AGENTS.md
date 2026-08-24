# Concorde EFB Agent Context

This file is a high-context handoff for future coding agents working in this repo.
It captures what the app does, what has been built over time, where key logic lives,
and what to watch before editing.

**This file describes the current Flutter codebase.** The app was fully migrated off the
original React/TypeScript/Tauri stack (see `public/changelog/entries.json` v3.1.20, 2026-06-30). There is
no `src/ConcordeEFB.tsx` or `src-tauri/` in this codebase anymore — do not look for them.

## 1) Project Snapshot (current state)

- Product: `Concorde EFB` (Electronic Flight Bag for DC Designs Concorde in MSFS 2020/2024).
- Framework: Flutter (Dart), single codebase for Desktop (Windows primary, macOS packaging
  present), Mobile (Android, with AdMob), and Web (GitHub Pages, static marketing/changelog only).
- State management: `flutter_riverpod` (v3, `Notifier`/`NotifierProvider` style).
- Current version: `3.4.10+44` in `pubspec.yaml` (`version: name+buildNumber`). Keep this and the
  `public/changelog/entries.json` in sync when cutting a release — README no longer carries its
  own changelog, it just links to that page.
- Theme system: unified light/dark `AppColors` (`lib/core/app_colors.dart`) resolved via
  `context.colors`, flat Material cards (`lib/widgets/efb_flat_card.dart`), one font family
  (JetBrains Mono via `lib/core/ui_text.dart`). The old glassmorphism system (`UiTokens`,
  `EfbGlassContainer`, `AmbientGlow`) and Flight Monitor's separate dark cockpit palette
  (`fm_theme.dart`) have been fully removed — if you see references to any of those in old docs,
  they're stale.

## 2) What the App Does

- Flight planning: DEP/ARR/ALT ICAO input, route/planned-distance entry, cruise FL handling
  (Concorde ceiling + Non-RVSM snapping), SimBrief OFP import.
- Fuel planning: climb/accel/cruise-climb/descent mission profile, trip/taxi/contingency/final
  reserve/alternate fuel, optional trim tank, endurance vs ETE+reserves validation.
- Performance & runway checks: takeoff/landing required runway length, weight-scaled V1/VR/V2/
  VLS/VAPP, METAR/elevation-aware correction factors, takeoff reheat (afterburner) toggle.
- Weather/runway awareness: METAR fetch with fallback, wind/QNH/temp/visibility parsing,
  runway-relative headwind/crosswind, longest-runway auto-pick (user-overridable).
- Ops safety: Operational Alerts panel (fuel, alternate, weight-limit, runway, tailwind).
- Checklists: interactive multi-phase checklists (Cold & Dark → Cockpit Prep → Engine Start →
  Takeoff → Decel & Descent → Approach → Landing → After Landing/Shutdown), with live
  takeoff/landing speeds plumbed into the relevant steps.
- Flight Monitor: live SimConnect telemetry over a local WebSocket bridge — EICAS-style engine
  readouts, fuel/CG envelope, PFD pitch/roll, droop nose/gear state, flight recording + history
  playback timeline.
- UX/system: persisted light/dark theme toggle, changelog/donate static pages, GitHub Releases
  update-availability banner, first-close flightsim.to rating prompt.

## 3) Core Behavior and Formula Summary

These are heuristic/indicative models, not certified performance data. Core constants live in
`lib/core/concorde_constants.dart`; the math lives in `lib/core/concorde_logic.dart`.

- MTOW `185,066 kg`, MLW `111,130 kg`, fuel capacity `95,681 kg`, OEW `78,700 kg`.
- Full pax count `100`, default pax mass `84 kg`.
- Nominal cruise TAS `1164 kt` (Mach `2.04`), base burn `24.45 kg/NM`, climb burn factor `1.7`,
  descent burn factor `0.5`, reheat cap `25 min`.
- Runway references: takeoff `11800 ft` (~3597 m) at MTOW baseline; landing `2200 m` at MLW
  baseline.
- Cruise FL: clamped to `[0, 590]`; above FL410 snapped to Non-RVSM sets (Eastbound `410, 450,
  490, 530, 570`; Westbound `430, 470, 510, 550, 590`), direction inferred from DEP→ARR bearing.
- Runway feasibility scales with weight + weather correction (pressure altitude, ISA temp
  deviation, headwind/tailwind); tailwind penalties are intentionally stronger than headwind
  credits.
- Total fuel required = block fuel + trim fuel. Endurance compares airborne fuel endurance
  against ETE + reserves.

## 4) External Data and Integrations

- Runtime CSV data sources (fetched via `lib/services/airport_database_service.dart`, cached
  off `Documents` on Windows — see `f2b19ef`):
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv`
- METAR fetch (`lib/services/metar_service.dart`): primary
  `https://aviationweather.gov/api/data/metar?ids=<ICAO>&format=raw`, fallback
  `https://metar.vatsim.net/<ICAO>`.
- SimBrief import (`lib/services/simbrief_service.dart`):
  `https://www.simbrief.com/api/xml.fetcher.php?username=<user>&json=1`.
- Flight Monitor telemetry bridge:
  - `lib/core/sim_bridge_launcher.dart` launches the bundled PyInstaller build of
    `tools/simbridge/msfs_bridge.py` (`windows/simbridge/msfs_bridge/msfs_bridge.exe` relative to
    the app executable) so users don't need Python installed.
  - The bridge exposes telemetry over `ws://localhost:8082`; the app connects via
    `lib/features/flight_monitor/data/services/websocket_client.dart`.
  - `SimBridgeLauncher.startWatching()` polls `tasklist` every 5s for MSFS's own process
    (`FlightSimulator*.exe`, covers 2020/2024) and force-restarts the bridge the moment it
    appears — fixes stale/stuck SimConnect connections when the app is opened before the sim. A
    reduced time-based watchdog in `telemetry_provider.dart` is a secondary safety net only, and
    only ever touches a bridge process this launcher spawned itself (never an externally/manually
    run dev bridge).
- Update check: GitHub Releases API polling, surfaced via `app_header.dart`'s update banner.

## 5) File Map (where to edit what)

- `lib/main.dart` — app entry point: AdMob init, `SimBridgeLauncher.start()` +
  `startWatching()`, window manager setup, theme wiring (`theme`/`darkTheme`/`themeMode`),
  `ProviderScope` root.
- `lib/core/app_colors.dart` — the theme system: `AppColors` `ThemeExtension` with `light`/`dark`
  static instances, resolved via the `context.colors` extension. This is the only place color
  values should be defined; everything else reads through it.
- `lib/core/ui_text.dart` — shared `uiText(context, ...)` JetBrains Mono text style helper.
- `lib/core/sim_bridge_launcher.dart` — SimConnect bridge process lifecycle (start/stop/restart/
  watch). See section 4.
- `lib/core/concorde_constants.dart` / `concorde_logic.dart` — performance/fuel model constants
  and math.
- `lib/core/metar_parser.dart` — METAR string parsing.
- `lib/widgets/efb_flat_card.dart` — shared flat Material card (replaces the old glass container;
  do not reintroduce blur/glassmorphism here).
- `lib/widgets/` (rest) — `efb_card.dart` (titled card wrapper), `efb_text_field.dart`,
  `efb_ad_banner.dart`, `wind_arrow.dart`, `efb_launches_badge.dart`, `entrance_fader.dart`,
  `smooth_scroll_wrapper.dart`.
- `lib/screens/home_screen.dart` — main dashboard/tab shell.
- `lib/screens/widgets/app_header.dart` — logo/title row, theme toggle, support/Discord links,
  update banner.
- `lib/screens/widgets/app_footer.dart` — footer.
- `lib/screens/tabs/flight_planner/` — `flight_plan_section.dart`, `cruise_fuel_section.dart`,
  `performance_calculator_section.dart` (the section this app's design language originated from).
- `lib/screens/tabs/checklists_tab.dart` — interactive checklist UI. `lib/models/checklist_item.dart`
  is the data model; `lib/data/checklist_data.dart` is the actual checklist content (phase/step
  text) — aligned with the Concorde manual's actual procedures as of `2041cd7`, edit steps there.
- `lib/screens/tabs/flight_monitor_tab.dart` — Flight Monitor composition shell.
- `lib/features/flight_monitor/presentation/controllers/telemetry_provider.dart` — the
  `FlightMonitorNotifier`: websocket connection state, recording, playback timeline, watchdog.
- `lib/features/flight_monitor/presentation/widgets/flight_monitor/` — cockpit UI widgets (fuel
  schematic, PFD, EICAS-style support cards, toolbar, logbook).
- `lib/features/flight_monitor/data/services/` — `websocket_client.dart`,
  `flight_recorder_service.dart` (flight log persistence/playback).
- `lib/features/flight_monitor/data/models/telemetry_model.dart` — telemetry frame shape.
- `lib/providers/efb_providers.dart` — global Riverpod providers (theme mode, SimBrief user,
  departure/arrival ICAO, etc.) — matches the `Notifier` + `SharedPreferences`-persisted pattern
  used by `themeModeProvider`.
- `tools/simbridge/msfs_bridge.py` — source for the bundled SimConnect bridge exe (PyInstaller
  build target referenced by `sim_bridge_launcher.dart`).
- `public/changelog/entries.json` — changelog source of truth (drives the standalone changelog
  page and update banner text).
- `.github/workflows/pages.yml` — GitHub Pages deployment (marketing site + changelog).
- `.github/workflows/beta-build.yml`, `.github/workflows/release-build.yml` — Flutter build/
  release pipelines (Windows installer via Inno Setup, macOS DMG, Android APK).

## 6) Build, Run, and Deploy Commands

- Get deps: `flutter pub get`
- Run (desktop): `flutter run -d windows` (or `-d macos`)
- Analyze: `flutter analyze` — must stay clean (no issues), especially after any theme/dead-code
  removal pass.
- Test: `flutter test`
- Build Windows release: `flutter build windows`
- Build macOS release: `flutter build macos`
- Build Android: `flutter build apk` / `flutter build appbundle`
- The bundled bridge exe under `windows/simbridge/` is a separate PyInstaller build of
  `tools/simbridge/msfs_bridge.py` — it is not rebuilt automatically by `flutter build`; check the
  release workflow (`.github/workflows/release-build.yml`) for how/when it's regenerated and
  bundled.

## 7) Completed Features and Timeline

Full raw history is in `public/changelog/entries.json` (the single source of truth — README only
links to it) — this section is a summary, not authoritative.

### Pre-Flutter (React/TypeScript/Tauri era, v0.10 → v2.1.0)

Superseded entirely. See git history / README changelog for detail if archaeology is needed; no
code from this era remains in the repo.

### v3.1.20 — 2026-06-30 — Flutter Migration

Migrated the entire application core from React/TypeScript/Tauri to a unified Flutter codebase:
interactive multi-phase checklists with plumbed takeoff/landing speeds, takeoff reheat toggle,
Alternate (ALT) quick-input, local SimBrief username persistence, GitHub Releases update tracker,
first-close flightsim.to rating prompt, UPI/Patreon donation modal, GitHub Actions release
pipeline (APK/DMG/Windows EXE via Inno Setup).

### Post-migration Flutter work (unreleased / rolling, since v3.1.20)

- SimConnect telemetry bridge (`sim_bridge_launcher.dart` + `tools/simbridge/msfs_bridge.py`)
  bundled so Flight Monitor works without users installing Python.
- Bridge auto-restart on MSFS process detection (`SimBridgeLauncher.startWatching()`) — fixes
  stale connections when the app is opened well before the sim.
- Bridge launch-failure surfacing in the Flight Monitor UI (distinguishing "exe never launched"
  from "bridge up, waiting on SimConnect").
- Airport DB cache moved off `Documents` on Windows.
- Eager default-cruise-FL snapping to known flight direction.
- App-wide retheme: unified `AppColors` light/dark theme system, flat Material cards
  (`EfbFlatCard`) replacing glassmorphism (`EfbGlassContainer`/`AmbientGlow`, both deleted),
  single JetBrains Mono font everywhere, Flight Monitor's separate dark cockpit palette
  (`fm_theme.dart`) removed and folded into the same system.
- Real app icon + polished Windows uninstaller metadata.
- Checklist content aligned with the Concorde manual's actual procedures; added a landing phase.
- Landing-page screenshot showcase carousel + Discord link (web/marketing site).

Keep this list rolling forward — append new notable changes here as they land, don't let it go
stale like the old React-era version of this file did.

## 8) Known Constraints and Gotchas

- The bundled `msfs_bridge.exe` is unsigned (PyInstaller) — antivirus/SmartScreen can quarantine
  it, which looks identical to "bridge up, just waiting on SimConnect" as a bare disconnected
  state unless `SimBridgeLauncher.status`/`lastError` is surfaced in the UI. Preserve that
  distinction if touching this code path.
- `SimBridgeLauncher.restart()` exists because the underlying Python SimConnect wrapper can get
  stuck if it first attempts to connect before MSFS is running — a fresh OS process is the actual
  fix, not a retry within the same process.
- `SimBridgeLauncher` only ever manages a process it spawned itself (`_process`) — never touch or
  kill an externally/manually run dev bridge (`SimBridgeStatus.alreadyRunning`).
- Windows-only features (`tasklist` polling, the bridge exe path resolution) are gated behind
  `defaultTargetPlatform == TargetPlatform.windows` — don't assume they run on macOS/Android/web.
- Runtime nav DB fetch depends on network availability; offline behavior is limited.
- Version is tracked in one place now (`pubspec.yaml`'s `version:`), unlike the old React era
  where it was duplicated across 4 files.
- All colors must resolve through `context.colors` (`AppColors`) — don't reintroduce hardcoded
  `Color(0x...)` literals or a static token class; that's exactly what was just removed.

## 9) Agent Checklist Before and After Changes

### Before coding

- Locate affected logic under the relevant `lib/` subtree (section 5 file map).
- If touching UI, confirm colors/fonts route through `context.colors` / `uiText()`, not hardcoded
  values or a reintroduced static token class.
- If touching `SimBridgeLauncher` or `telemetry_provider.dart`, re-read the "why" comments there
  first — the restart/watchdog logic encodes non-obvious SimConnect behavior.
- Check if the change affects release-visible strings, the version number, or changelog surfaces.

### After coding

- Run `flutter analyze` — must stay clean.
- Run `flutter test`.
- For UI changes, run the app (`flutter run -d windows`) and visually verify in both light and
  dark mode before reporting done.
- If behavior changed for users, update `public/changelog/entries.json` (the sole changelog —
  README only links to it, don't add version history back into README).
- If the version changed, sync `pubspec.yaml`.
- Update this section (7) with a one-line summary of what landed, so it doesn't go stale again.

## 10) Source-of-Truth References

- Product behavior: `lib/core/concorde_logic.dart`, `lib/core/concorde_constants.dart`
- Theme system: `lib/core/app_colors.dart`
- Changelog history: `public/changelog/entries.json`
- Human-readable overview: `README.md`
- Web deployment pipeline: `.github/workflows/pages.yml`
- Desktop/mobile release pipelines: `.github/workflows/beta-build.yml`,
  `.github/workflows/release-build.yml`
