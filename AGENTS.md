# Concorde EFB Agent Context

This file is a high-context handoff for future coding agents working in this repo.
It captures what the app does, what has been built over time, where key logic lives,
and what to watch before editing.

## 1) Project Snapshot (current state)

- Product: `Concorde EFB` (Electronic Flight Bag for DC Designs Concorde in MSFS 2020/2024).
- Platforms:
  - Web app (GitHub Pages).
  - Desktop app (Tauri v2, Windows MSI target).
- Current in-app version constants:
  - `APP_VERSION = "2.0.2"` and `BUILD_MARKER = "281225-2"` in `src/ConcordeEFB.tsx`.
- Tauri package version:
  - `2.0.2` in `src-tauri/tauri.conf.json`.
- Important version mismatch:
  - `package.json` and `src-tauri/Cargo.toml` still show `1.1.0` (legacy value).
  - Runtime UI + Tauri config show `2.0.2`.
- Main implementation:
  - `src/ConcordeEFB.tsx` (monolithic; UI + business logic + integrations + tests).

## 2) What the App Does

At a high level, the app plans Concorde flights with operationally useful estimates:

- Flight planning:
  - DEP/ARR/ALT ICAO input.
  - Route input and route-distance estimation.
  - Manual planned distance override (source of truth for calculations).
  - Cruise FL handling with Concorde ceiling and Non-RVSM rules.
  - SimBrief import for OFP data.
- Fuel planning:
  - Mission profile split into climb, accel, cruise-climb, and descent.
  - Trip fuel, taxi, contingency, final reserve, alternate fuel.
  - Optional trim tank fuel.
  - Endurance vs ETE+reserves validation.
- Performance and runway checks:
  - Takeoff and landing required runway length estimates.
  - Weight-sensitive speed references (`V1`, `VR`, `V2`, `VLS`, `VAPP`).
  - METAR/elevation/weather-aware correction factors.
- Weather/runway awareness:
  - Fetches METAR with fallback source.
  - Parses wind, QNH, temp, visibility, weather summary, and flight category.
  - Computes runway-relative headwind/crosswind.
  - Auto-picks longest runway (user can override).
- Ops safety:
  - Operational Alerts panel for fuel, alternate, weight-limit, runway, and tailwind risks.
- Diagnostics:
  - Built-in self-tests for core math and behavior sanity.
- UX/system:
  - Dark/light themes with persistence.
  - Changelog and donate static pages.
  - Tauri update availability check banner.

## 3) Core Behavior and Formula Summary

These are heuristic/indicative models, not certified performance data.

- Core constants in `src/ConcordeEFB.tsx`:
  - MTOW `185,066 kg`
  - MLW `111,130 kg`
  - Fuel capacity `95,681 kg`
  - OEW `78,700 kg`
  - Full pax count `100`
  - Default pax mass `84 kg`
  - Nominal cruise TAS `1164 kt` (Mach `2.04`)
  - Base burn `24.45 kg/NM`
  - Climb burn factor `1.7`
  - Descent burn factor `0.5`
  - Reheat cap `25 min`
  - Runway references:
    - Takeoff: `11800 ft` converted to meters (`~3597 m`) at MTOW baseline.
    - Landing: `2200 m` at MLW baseline.

- Mission profile (`buildCruiseMissionProfile()`):
  - Builds climb, optional accel, segmented cruise-climb, and descent.
  - Returns total time, trip fuel, average cruise TAS, and average cruise burn.

- Cruise FL logic:
  - FL clamped to `[0, 590]`.
  - Above FL410, snapped to Non-RVSM sets:
    - Eastbound: `410, 450, 490, 530, 570`
    - Westbound: `430, 470, 510, 550, 590`
  - Direction inferred from DEP->ARR initial bearing.
  - Auto-FL recommendation uses planned distance and minimum cruise-time targets.

- Runway feasibility:
  - Takeoff/landing requirement scales with weight + weather correction.
  - Correction inputs:
    - pressure altitude (QNH + runway elevation)
    - ISA temperature deviation
    - headwind/tailwind component
  - Tailwind penalties are intentionally stronger than headwind credits.

- Fuel and alerts:
  - `Total fuel required = Block fuel + Trim fuel`.
  - Endurance compares airborne fuel endurance against `ETE + reserves`.
  - Alerts include:
    - endurance deficit
    - alternate risk
    - MTOW/MLW exceedance
    - takeoff/landing runway shortfall
    - significant tailwind warning

## 4) External Data and Integrations

- Runtime CSV data sources:
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv`

- METAR fetch:
  - Primary: `https://aviationweather.gov/api/data/metar?ids=<ICAO>&format=raw`
  - Fallback: `https://metar.vatsim.net/<ICAO>`

- SimBrief import:
  - `https://www.simbrief.com/api/xml.fetcher.php?username=<user>&json=1`
  - Parses ICAOs, runways, route, alternate, distance, cruise FL, METAR lines,
    callsign, registration, pax count, and pax weight.

- Tauri updater:
  - Endpoint in `src-tauri/tauri.conf.json`:
    - `https://github.com/dwaipayanray95/Concorde-EFB/releases/latest/download/latest.json`
  - UI checks availability and shows banner/version, but does not auto-install.

## 5) File Map (where to edit what)

- `src/ConcordeEFB.tsx`
  - Main app UI and all planner logic.
  - First file to inspect for feature edits and bug fixes.
- `src/App.tsx`
  - Thin wrapper that renders `ConcordeEFB`.
- `src/main.tsx`
  - React root mount.
- `src/index.css`
  - Theme and shared component styling.
- `src/uiTokens.ts`
  - Shared class tokens for UI sections.
- `public/changelog/entries.json`
  - Raw changelog source of truth (changelog page data).
- `public/changelog/index.html`
  - Standalone changelog viewer.
- `public/donate/index.html`
  - Standalone donation page.
- `src-tauri/tauri.conf.json`
  - Desktop metadata, updater endpoint, bundling target, window config.
- `.github/workflows/pages.yml`
  - GitHub Pages deployment for `main` (stable) and `beta`.
- `.github/workflows/tauri-release.yml`
  - Windows Tauri release workflow for `v*` tags.

## 6) Build, Run, and Deploy Commands

- Local dev (web): `npm run dev`
- Typecheck: `npm run typecheck`
- Build targets:
  - `npm run build:web` for GitHub Pages base `/Concorde-EFB/`
  - `npm run build:beta` for beta subpath `/Concorde-EFB/beta/`
  - `npm run build:tauri` for desktop relative base `./`
  - `npm run build` currently aliases `build:tauri`
- Tauri CLI passthrough: `npm run tauri`
- Changelog seed from git log: `npm run changelog:seed`

## 7) Completed Features and Timeline

This section summarizes what has been built. Full raw history is in:
- `public/changelog/entries.json`
- `README.md` changelog

### Early foundation (v0.10 -> v0.71)

- v0.10:
  - Initial project skeleton and first calculations.
- v0.20:
  - Prototype UI and first-pass block-fuel math.
- v0.40:
  - Great-circle distance and altitude-sensitive fuel heuristic foundations.
- v0.60:
  - Initial route tokenization approach (later superseded by manual-distance-led flow).
- v0.70:
  - Manual planned distance model.
  - Departure/landing feasibility with reasons.
  - Metric unit normalization.
  - Runway wind components.
  - Diagnostics/self-test framework.
- v0.71:
  - METAR fetch (AviationWeather + VATSIM fallback).
  - Longest runway auto-selection.

### Performance and ops maturity (v0.75 -> v0.85)

- v0.75:
  - Takeoff feasibility moved to actual computed TOW.
  - Endurance check tied to ETE + reserves.
  - Weight-scaled speed references (`V1/VR/V2`, `VLS/VAPP`).
  - Trim tank integration in total fuel required.
  - Alternate ARR->ALT fuel integration.
- v0.76 to v0.78:
  - Runtime fixes (regex issue, JSX issue, export/white-screen issues).
- v0.79 to v0.82:
  - GitHub Pages pipeline stabilization and changelog hygiene.
- v0.83:
  - Runway selection fixes.
  - Fuel-capacity warning.
  - Landing speed heuristic tuning.
- v0.84:
  - Eastbound/westbound inference and Non-RVSM validation.
- v0.85:
  - Auto cruise FL recommendation.
  - FL590 cap and snapping behavior tightened.

### Transition to desktop + SimBrief expansion (v1.x period, Dec 2025)

- Tauri migration and desktop packaging stabilization.
- Route paste + estimated distance workflow improvements.
- SimBrief import added and expanded:
  - DEP/ARR/ALT, route, runways, METAR fill, callsign/registration, pax extraction.
- Planned distance protection:
  - Manual planned distance no longer overwritten by route auto-estimates.
- CI and deploy fixes:
  - Build/deploy hardening across Pages and desktop release workflows.

### v2 cycle

- v2.0.1 (2025-12-28):
  - Major UI overhaul and readability improvements.
  - Light mode contrast pass + mode toggle.
  - Expanded SimBrief import coverage.
  - Route planning and distance workflow refinements.
  - Performance/fuel/METAR UX expansion.
  - Diagnostics retained and expanded.

- v2.0.2 (2025-12-28):
  - In-app Tauri updater notification banner.
  - Updater permissions and endpoint configuration.
  - Input focus-loss fix.
  - Build marker update to `281225-2`.

### Unreleased (logged in changelog as of 2026-02-08)

- Cruise-climb mission profile now directly drives ETE/trip/endurance calculations.
- METAR/elevation-aware takeoff/landing requirement corrections.
- Operational Alerts panel for fuel, alternate, weight, runway, and tailwind constraints.

### Commit-wave notes from raw changelog

- 2025-12-24:
  - FL editing and Non-RVSM behavior refinements; FL590 clamp fixes.
- 2025-12-25:
  - Heavy build/deploy hardening; route distance and token parsing improvements; Tauri config cleanup.
- 2025-12-26:
  - SimBrief import branch merged and expanded rapidly (route tokens, METAR autofill, callsign/registration split).
- 2025-12-27:
  - Performance calculator and runway safety UX pass.
- 2025-12-28:
  - UI polish, light mode, release prep, updater integration.
- 2026-02-08:
  - New operational model and alerts tracked as unreleased.

## 8) Known Constraints and Gotchas

- `src/ConcordeEFB.tsx` is large and tightly coupled; local edits can ripple.
- Planned Distance is intentionally the source of truth for performance/fuel math.
- Route-estimated and SimBrief distances are context signals; manual distance remains authoritative.
- Non-RVSM snapping above FL410 is intentional and covered by self-tests.
- Runtime nav DB fetch depends on network/CORS availability; offline behavior is limited.
- `src/App.css` and `src/vite.config.ts` appear legacy; verify real usage before cleanup.
- Version values are duplicated across files and can drift (`src/ConcordeEFB.tsx`, `tauri.conf`, `package.json`, `Cargo.toml`).

## 9) Agent Checklist Before and After Changes

### Before coding

- Locate affected logic in `src/ConcordeEFB.tsx` and inspect nearby derived-state/useEffect interactions.
- Confirm whether the change affects both web and desktop base-path behavior.
- Check if change affects release-visible strings, versions, or changelog surfaces.

### After coding

- Run at least `npm run typecheck`.
- Build target(s):
  - `npm run build:web` for web-facing edits.
  - `npm run build:tauri` for desktop-facing edits.
- If behavior changed for users, update `public/changelog/entries.json`.
- If version/build marker changed, sync:
  - `src/ConcordeEFB.tsx` (`APP_VERSION`, `BUILD_MARKER`)
  - `src-tauri/tauri.conf.json`
  - `README.md` version/changelog section

## 10) Source-of-Truth References

- Product behavior: `src/ConcordeEFB.tsx`
- Changelog history: `public/changelog/entries.json`
- Human-readable overview: `README.md`
- Web deployment pipeline: `.github/workflows/pages.yml`
- Desktop release pipeline: `.github/workflows/tauri-release.yml`
