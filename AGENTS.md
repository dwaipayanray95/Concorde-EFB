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
- Current version: `5.14.1+91` in `pubspec.yaml` (`version: name+buildNumber`). Keep this and the
  `public/changelog/entries.json` in sync — README no longer carries its own changelog, it just
  links to that page.
- **Versioning rule (mandatory for every agent):** every change that alters user-visible behavior
  bumps the version using semantic versioning `MAJOR.MINOR.PATCH`, and ALWAYS increments the
  `+buildNumber` by 1:
  - PATCH (`4.0.0` -> `4.0.1`): bug fixes, copy/text tweaks, small visual fixes.
  - MINOR (`4.0.1` -> `4.1.0`): new features or new UI, backwards-compatible calculation changes.
  - MAJOR (`4.1.0` -> `5.0.0`): only when the owner asks, or for breaking changes (e.g. removed
    features, changed saved data formats, reworked core models).
  Do NOT put the version number in git commit messages (the version lives in `pubspec.yaml` and
  the changelog; commit subjects just describe the change).
  Add a matching `public/changelog/entries.json` entry titled `vX.Y.Z — <summary>` in the same
  commit. Pure refactors/tests/docs with no user-visible change don't bump.
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

These are heuristic/indicative models, not certified performance data. Where the **DC Designs
Concorde manual** (https://downloads.justflight.com/support/manuals/DCDESIGNSCONCORDEMANUAL.pdf --
the sim this app targets) gives a number, it wins; the code comments cite it. Core constants live in
`lib/core/concorde_constants.dart`; the math lives in `lib/core/concorde_logic.dart`.

- MTOW `185,070 kg`, MLW `111,130 kg`, MZFW `92,080 kg`, fuel capacity `95,681 kg`, OEW `78,700 kg`.
  Full pax `100` x `84 kg` + full fuel stays under MTOW, so MTOW can't be exceeded by payload alone.
- Weights (`ConcordeLogic.computeWeights`): ZFW = OEW + pax; fuel on board = min(block + extra,
  capacity); ramp = ZFW + FOB; TOW = ramp - taxi; LW = TOW - trip.
- Trip fuel (`buildCruiseMissionProfile`) = sum of phases, each fuel flow x phase time:
  takeoff allowance 2 t + subsonic climb to FL240 (manual: reheat on at FL240/M0.95, off at M1.7) (26 t/h, 2,000 fpm, 360 kt GS) -> transonic accel
  FL280->FL500 (16 min, 220 nm, 60 t/h) -> Mach 2.04 cruise-climb FL500->selected FL (TAS ~1,170 kt;
  21 t/h at FL500 tapering to 17.5 t/h at FL600) -> decel/descent (3 nm/1000 ft + 30 nm, 8.5 t/h).
  Below FL410 (or if the sector is too short for supersonic) the profile is subsonic M0.95 at 15 t/h,
  with the FL capped to what the distance allows. Golden test: LHR-JFK 3,150 nm -> ~71 t, ~3h13
  (`test/golden_flight_test.dart`). Keep it passing when touching any fuel constant.
- Alternate fuel = subsonic diversion profile (no takeoff allowance) + 1 t missed approach.
  Endurance: trip lasts the ETE, the rest burns at 12 t/h holding; required = ETE + reserves at holding.
- **Distances are always ROUTE distances (owner rule).** Never use the airport-to-airport great
  circle for fuel, time, TOD or ETA. Sources, in order: SimBrief `route_distance` / the sum of
  imported route legs (`RouteMath.polylineNm`, fixes from SimBrief navlog or `.pln` WorldPosition,
  stored in `plannedRouteProvider`); live remaining distance = `RouteMath.remainingAlongRouteNm`
  along `routePolylineProvider`. Only when no fixes exist fall back to great circle x
  `routeFactorProvider` (planned/GC ratio) or `estimatedRouteDistanceNm` (GC x 1.04 + 40 nm).
  Alternate: SimBrief alternate `distance` if present, else the estimate.
- Cruise FL: clamped to `[0, 590]`; above FL410 snapped to Non-RVSM sets (Eastbound `410, 450,
  490, 530, 570`; Westbound `430, 470, 510, 550, 590`), direction inferred from DEP→ARR bearing.
- Runway: takeoff distance = 2,743 m (DC manual, MTOW/SL/ISA/no wind) x (TOW/MTOW)^2 (x1.35 without reheat); landing = 2,200 m x
  (LW/MLW)^1.15; then + pressure-alt / temperature / wind / surface (wet +15%, contaminated +30%
  takeoff / +40% landing) corrections. Hard limits: 30 kt crosswind (gust-inclusive), 10 kt tailwind
  (gust-inclusive), airfield altitude; VRB wind = worst case; missing wind is flagged, not calm.
- Speeds (DC manual): V1/VR/V2 = 170/190/220 kt at MTOW scaled by sqrt(W/MTOW) (V1 -8 wet / -15
  contaminated); VREF 195 kt at MLW scaled by sqrt(W/MLW) (manual approach range 150-207 kt);
  VAPP = VREF + clamp(half headwind + gust, 5..20).
- CG (DC manual p.78 chart, `lib/core/live_flight_math.dart`): fwd/aft limits and ideal CG vs Mach
  (ideal ~53.5 % subsonic, 55 % at M0.95, 59 % at M2). Max taxi weight 187,000 kg.
- NOT in the DC manual (kept from the BA Flying Manual / estimates): 30 kt crosswind, 10 kt
  tailwind, no-reheat 155 t gate and x1.35 factor, wet/contaminated factors, landing distance base.

## 4) External Data and Integrations

- Runtime CSV data sources (fetched via `lib/services/airport_database_service.dart`, cached
  off `Documents` on Windows — see `f2b19ef`):
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv`
  - `https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv`
- METAR fetch (`lib/services/metar_service.dart`): primary `https://metar.vatsim.net/<ICAO>`
  (the app targets VATSIM), then aviationweather.gov, then the NOAA/NWS text feed. Total failure
  throws `MetarUnavailableException` (UI shows OFFLINE). Providers auto-refresh every 10 min.
- SimBrief import (`lib/services/simbrief_service.dart`):
  `https://www.simbrief.com/api/xml.fetcher.php?username=<user>&json=1`.
- Flight Monitor telemetry bridge:
  - `lib/core/sim_bridge_launcher.dart` launches the bundled PyInstaller build of
    `tools/simbridge/msfs_bridge.py` (`windows/simbridge/msfs_bridge/msfs_bridge.exe` relative to
    the app executable) so users don't need Python installed.
  - The bridge exposes telemetry over `ws://localhost:8082`; the app connects via
    `lib/features/flight_monitor/data/services/websocket_client.dart`.
  - **Wi-Fi link for phones/tablets (v5.1.0):** SimConnect only works on the sim PC, so mobile
    gets data from the desktop app's bridge over the LAN. Desktop toggle (`lanShareProvider`,
    persisted, loaded into `SimBridgeLauncher.lanEnabled/pairingCode` by
    `loadLanShareIntoLauncher()` in `main.dart` before the first launch) restarts the bridge with
    env `SIMBRIDGE_LAN=1` + `SIMBRIDGE_CODE=<6 digits>`: it binds `0.0.0.0:8082`, lets localhost
    in freely, closes non-local clients without `?code=` with WS close code **4401**, and
    broadcasts a UDP beacon on **8083** (`{"app":"concorde-efb-bridge",...}`). Mobile:
    `discoveredBridgesProvider` listens for beacons, `remoteBridgeProvider` (persisted host+code)
    feeds `FlightMonitorNotifier`'s URL; `BridgeStatus.pairingRejected` surfaces 4401. All in
    `lib/features/flight_monitor/data/services/lan_link.dart`; UI in `wifi_link_card.dart`.
    Verified end-to-end against the real bridge script (Linux, no SimConnect).
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
- `.github/workflows/build.yml` — the single manual (`workflow_dispatch`) build/release pipeline:
  Windows/Android/macOS checkboxes + mode debug/profile/release. debug/profile -> pre-release
  `pre-<ver>-build<N>-<mode>` (notes = diff since previous pre-release); release -> `v<ver>` tag
  created from pubspec (notes = diff since previous `v*`, draft by default, main only, needs a
  changelog entry). Windows always ships via Inno Setup (`/DAppVer /DBuildDir /DOutName`) with a
  fresh PyInstaller `msfs_bridge.exe`. Notes: `actions/ai-release-notes` (Gemini, offline fallback).
  `.github/workflows/pr-checks.yml` — PR size label/secret scan/licence check.

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
  build workflow (`.github/workflows/build.yml`) for how/when it's regenerated and
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
- Tablet-style EFB cockpit overhaul: Left-hand vertical navigation rail (`EfbNavRail`), avionics operational status bar (`CockpitStatusBar`) with real-time live UTC Zulu clock, SimConnect telemetry badge, consolidated cockpit settings popover, flight deck identity pills (call sign, registration, pax) with theme accents, relocated mission phase time strip in Flight Plan card, and sub-tabbed Flight Planner (`Route & Fuel` vs `Performance & Speeds`) optimized for 1200x700 tablet landscape resolution.
- Design System & Mobile Responsiveness: Established `DESIGN_SYSTEM.md` contract, standardized 4px/8px layout tokens (`AppSpacing`/`AppRadii` in `lib/core/app_spacing.dart`), added semantic type scale (`AppTypography` in `lib/core/ui_text.dart`), implemented OS-level `textScaler` clamping (0.85 - 1.25) in `main.dart` to prevent mobile overflow stripes, adaptive mobile bottom-bar shell in `home_screen.dart`, horizontal-scrolling a11y `CockpitStatusBar` with `Semantics` tags, and an interactive in-app component gallery (`DesignLabScreen` in `lib/design_system/design_lab.dart`).
- Monochromatic Aviation Amber Redesign: Restyled app-wide palette with Signature Aviation Amber (`#F59E0B` dark / `#D97706` light) and true neutral monochromatic surfaces (`#101012` dark carbon / `#18181B` surface / `#202024` inset results; `#F4F4F5` light zinc / `#E4E4E7` surface / `#FFFFFF` readout), completely eliminating blue/slate undertones. Amber lead established for card accents, navigation items, focus rings, and arrival route targets. Material 3 squircle amber indicators on `EfbNavRail`, amber indicator pips on `EfbCard` titlebars, 1px precision bezel borders on cards, amber focus rings on form inputs, and high-contrast V-Speed tiles with unit badges.
- Authentic Printed Fuel Release Strip: Redesigned the fuel breakdown calculator in `CruiseAndFuelSection` into an authentic cockpit ACARS / dispatch thermal printout strip with serrated/perforated paper edges (`_PerforatedEdgePainter`), dot-matrix leaders (`_DotLeaderPainter`), dashed/double-line thermal print rules, dispatch telemetry header, and stamped `TOTAL REQUIRED` readout block.
- Precision Avionics Card Bezels: Dropped the bulky curved top yellow/amber band (`TopArcBorder`) across all cards. Implemented precision 1px anodized bezels (`10px` tight corner radius), integrated recessed titlebars (`#141417` dark / `#EBEBEF` light), 12px amber indicator pips, hairline separators, and status-sensitive warning borders for true premium EFB cockpit aesthetics.
- MFD Bezel Segmented Softkeys: Overhauled the Flight Planner sub-tab buttons into an authentic cockpit MFD segmented softkey strip (`38px` fixed height, `6px` radius chassis, hairline division rules, micro amber indicator underlines, and high-contrast tracked text).
- Unpacked Performance Calculator Cards & Renamed Sub-Tab: Renamed sub-tab to `PERFORMANCE CALCULATOR` (active button illuminated in solid amber with dark text), removed redundant outer enclosing `EfbCard` from `PerformanceCalculatorSection`, making `DEPARTURE / TAKEOFF` and `ARRIVAL / LANDING` standalone side-by-side avionics cards with responsive column fallback on narrow viewports.
- Concorde Performance No-Go Decision Presentation: Replaced aggressive 4-corner red card borders with clean neutral avionics bezels, added authentic cockpit push-button style annunciators (`PERF LIMIT EXCEEDED` in high-contrast solid red pill with warning icon), targeted red border highlight on offending runway dropdowns with `LENGTH DEFICIT` label, and a dedicated `DISPATCH DECISION: PERFORMANCE NO-GO` alert telemetry box detailing exact shortfalls (runway length deficit in meters, MTOW exceedance, crosswind limits) and available margins.
- Bold Solid Amber Navigation Selection: Upgraded `_NavRailItem` in `lib/widgets/efb_nav_rail.dart` and the mobile `NavigationBar` in `lib/screens/home_screen.dart` from faint outline washes to bold solid amber tiles (`colors.accent`) with high-contrast dark charcoal (`#101012`) text and icons, harmonizing the entire application with the MFD softkey button styling.
- Checklist Phase List Bold Solid Selection: Restyled the phase selector tiles in `ChecklistsTab` (`lib/screens/tabs/checklists_tab.dart`) to solid amber fills with dark charcoal text/badges for the active phase, unifying phase selection with the app-wide MFD navigation design language.
- Streamlined Checklist Header & Layout: Converted checklist panels to precision 10px avionics bezels, replaced the oversized 32px-padded header with a compact 40px integrated titlebar and amber pip, right-aligned response status detents connected by authentic dot-matrix leaders (`_DotLeaderPainter`), and condensed the FMC route checklist challenge/response status to prevent right-edge overflow.
- Uniform EfbNavRail Amber Highlight Dimensions: Fixed inconsistent highlight pill widths and heights in `_NavRailItem` by applying `width: double.infinity` and fixed `height: 56` with centered alignment inside the horizontal padding, ensuring `PLAN`, `CHECK`, and `MONITOR` share an identical 60x56px rounded squircle geometry regardless of label character count.
- Solid Aviation Amber Flight Deck Identity Strip: Upgraded `_buildHeaderPill` in `CockpitStatusBar` (`lib/screens/widgets/cockpit_status_bar.dart`) so that once flight data is loaded (SimBrief OFP or route initialized), `CALL SIGN`, `REG`, and `PAX` smoothly animate into bold solid aviation amber fills (`colors.accent`) with high-contrast dark charcoal text (`#101012`), subtle amber elevation glow, and quiet standby appearance (`--`) when unloaded.
- Right-Aligned Live Zulu / UTC Clock: Anchored the live Zulu clock pill permanently to the right edge of the `CockpitStatusBar` using an outer `Row` with `Expanded` scrollable telemetry container on the left, ensuring the master time reference is always visible and right-aligned across all viewport widths.
- Precision Avionics AppFooter & MFD Softkeys: Overhauled `AppFooter` (`lib/screens/widgets/app_footer.dart`), `EfbAdBanner` (`lib/widgets/efb_ad_banner.dart`), and `EfbLaunchesBadge` (`lib/widgets/efb_launches_badge.dart`) into precision 10px anodized avionics bezels. Replaced rounded yellow bubble outlines with authentic 6px MFD segmented softkeys (`VIEW CHANGELOG`, `JOIN DISCORD`, `GITHUB SPONSOR`) with icons and interactive amber hover illumination, an amber aviation heart icon, and a bold solid amber `DONATE NOW` button with `#101012` dark text, plus high-contrast dark text on the launches counter.
- Android Compatibility & Startup Crash Fixes: Resolved Gradle Java 25 (`25.0.3`) incompatibility by pinning `org.gradle.java.home` to JDK 21, fixed cross-drive Windows path relativity errors on `buildDirectory`, added the required AdMob `APPLICATION_ID` metadata to `AndroidManifest.xml`, and guarded desktop-only `window_manager` calls (`ensureInitialized`, `addListener`, `removeListener`) in `main.dart` and `home_screen.dart` to allow the mobile UI to mount past the splash screen.
- Mobile Landscape Orientation Lock: Enforced landscape-only orientation (`sensorLandscape` in `AndroidManifest.xml` and `SystemChrome.setPreferredOrientations` in `main.dart`) for Android and iOS mobile/tablet devices, guaranteeing the EFB interface stays locked horizontally like a cockpit MFD or game display.

- SimConnect Bridge Rewrite: `tools/simbridge/msfs_bridge.py` now calls SimConnect.dll directly via ctypes (one data definition, `PERIOD_SIM_FRAME` push, dispatch thread handling OPEN/QUIT/EXCEPTION, heartbeat via `RequestSystemState`, auto-reconnect in-process) instead of the polling Python-SimConnect wrapper; sends `{"type":"status"}` + `{"type":"telemetry"}` frames; bundled with `--noconsole --add-binary SimConnect.dll` (the DLL was previously missing from the PyInstaller build). `SimBridgeLauncher` now supervises/respawns the process and kills a hung leftover `msfs_bridge.exe`; MSFS-launch restart removed (`startWatching` is a no-op). Logs to `%LOCALAPPDATA%\ConcordeEFB\simbridge.log`.

- Fuel & performance model overhaul (v3.7.0): phase-based trip fuel calibrated to real sectors with a golden test, subsonic/short-sector fallback, subsonic alternate profile + alternate warnings, capacity-aware endurance, TOW excludes taxi, typed `WeightSummary`/`TakeoffSpeeds`/`LandingSpeeds`, 10 kt tailwind limit, gust/VRB handling, missing-wind flag, AUTO/DRY/WET/CONTAM runway condition, W^2 takeoff distance, recalibrated V-speeds, longest-runway departure default, route-distance estimate for file imports, METAR auto-refresh/age/weather summary, shared runway-env provider, `flutter analyze` in beta CI.
- v4.0.0: fuel release strip header shows real flight data (call sign/route, source, FL, distance, ETE, FUEL OK/SHORT stamp); METAR strip reorganised into category row + equal-width readout row, age spelled out below the strip (`formatMetarAge`); semantic versioning rule added (section 1).
- v4.1.0: planner `DispatchBanner` driven by `dispatchSummaryProvider` (all NO-GO/caution checks in one place); raw METAR always visible. Flight Monitor: `MfdStrip` (phase, dist to dest, TOD, ETA, fuel at dest vs reserve+alt, annunciators) using `lib/core/live_flight_math.dart` (`predictToDestination`, Mach-dependent `cgLimitsForMach` — indicative, verify vs DC Designs manual); fixed gear/droop decoding (bridge sends 0-1 fractions, see `TelemetryModel.gearLabel`/`droopLabel`); smoothed actual fuel flow (30 s EMA) + latched `TouchdownRecord` in `FlightMonitorNotifier`; removed dead `GearFlapsDroopCard`.
- v4.2.0: privacy policy page (`public/privacy/index.html`, deployed by `pages.yml`, `AppLinks.privacy`, footer PRIVACY link); Google UMP consent via `lib/services/ad_consent_service.dart` -- AdMob is initialised only after consent (`adsReady`), started post-first-frame from `main.dart`; footer AD PRIVACY OPTIONS shown when UMP requires it. Keep the privacy page's "online services" table in sync whenever a new network call is added. Supersonic-over-land feature dropped by the owner (people fly it on VATSIM).
- v4.3.0: route distances everywhere -- `lib/core/route_math.dart` (polyline length, remaining-along-route), route fixes imported from SimBrief navlog (`SimBriefService.navlogFixes`) and `.pln` `<WorldPosition>` (`FlightPlanImportService.parseWorldPosition`), `plannedRouteProvider`/`routePolylineProvider`/`routeFactorProvider`, `alternateRouteDistanceProvider`; MFD strip uses remaining route distance; `predictToDestination` now takes `distToDestNm`.
- v4.4.0: wind-aware default runway (`bestRunwayId`: no tailwind > crosswind <= 15 kt > longest; `_RunwayIdNotifier` auto-follows METAR until a manual/SimBrief pick, reset on ICAO change); `WindArrow` coloured by gust-inclusive components vs limits; phone layout (`isShort` < 560 px height in `home_screen.dart`: status bar scrolls with content / hidden on checklists; compact `EfbNavRail` < 440 px; collapsible `DispatchBanner`; checklist phase strip < 900 px wide; cruise card stacks < 900 px); compact Flight Plan card (single row + route chip with distance/ETE); ENDURANCE MARGIN stat; identity pills only when a flight is loaded; Flight Monitor: `HeroPfdRow` is now one compact data bar, fuel schematic + CG/engines/burn side column, env/G/touchdown row; `liveChecklistPhaseProvider` drives checklist auto-select + dimming. UI screenshot harness: `tool/ui_screenshots/` -- use it to verify layout changes (light/dark, desktop + phone) since `flutter run -d windows` isn't available to cloud agents.
- v4.5.0: `CockpitStatusBar` always shows CALL SIGN/REG/PAX plus planned TOTAL/CLB (climb+transonic accel)/CRZ/DES times from `missionProfileProvider`; `DispatchBanner` is a flat solid-colour block placed above the Planner/Performance sub-tab selector; Privacy Policy + Ad Privacy Options live in the nav-rail Settings dialog (removed from the footer); Design Lab removed from Settings (`lib/design_system/design_lab.dart` kept only for its test).
- v5.0.0 (owner-requested major): status bar compacted to one row at >= 1024 px (labels C/S, REG, PAX, ETE, CLB, CRZ, DES; SIM LIVE pill removed -- sim status is the `EfbNavRail` dot only); fuel strip stamp is `OVER CAPACITY` / `FUEL SHORT` / `FUEL OK`; stat subtexts wrap to 2 lines; route chip shows only the route; `AppFooter` is just `EfbAdBanner` (links live in Settings; `efb_launches_badge.dart` no longer shown).
- v5.1.0: Flight Monitor over Wi-Fi for Android/iOS phones and tablets (see section 4 "Wi-Fi link"); `WifiLinkCard` at the top of the Monitor tab (desktop: share toggle + IP + pairing code; mobile: discovery chips, IP + code, status/rejection); iOS `NSLocalNetworkUsageDescription`; privacy page updated. Screenshot harness supports `--dart-define=TARGET=windows` for desktop-only UI.
- v5.2.0: Flight Monitor redesign -- `_CockpitLayout` in `flight_monitor_tab.dart`: MFD strip, `FlightProgressBar`, `PfdPanel` (`pfd_panel.dart`: ADI CustomPainter + speed/alt columns, HDG/gear/nose/G) beside `EnginesPanel`, fuel schematic beside `CgTrimCard` (Mach corridor, target = fwd + 60% of corridor, TRANSFER advice, trim tanks 9+10 / 11) + fuel burn, environment + touchdown row; stacks below 900 px. Shared `liveNavProvider` (`controllers/live_nav_provider.dart`) computes phase/flow/FOB/route prediction for MFD strip + progress bar. New theme tokens `adiSky`/`adiGround`. Removed `HeroPfdRow`, `CgCard`, `EnginesReheatCard`, `GForceCard`.
- v5.3.0: numbers from the DC Designs manual -- CG corridor + ideal CG digitised from its chart (`cgTargetForMach`), V1/VR 170/190 at MTOW, VREF 195 at MLW, takeoff base 2,743 m, transonic accel from FL240, max taxi 187 t dispatch check, `GEAR UP — BELOW 250 KT` annunciator, checklist reheat/transfer steps.
- v5.4.0: alert chimes -- live alerts moved out of `MfdStrip` into `liveAlertsProvider` (`controllers/live_alerts_provider.dart`, `LiveAlert(text, critical)`); `alertChimeProvider` (`controllers/alert_chime.dart`, watched in `HomeScreen` so it runs on every tab) plays ONE chime per newly-appearing alert via `audioplayers` (`assets/sounds/warning.wav` two-tone for critical, `caution.wav` single tone), most severe wins, 10 s re-arm against flicker, persisted mute (`alert_chimes_enabled`); toggle on the MFD strip + Settings (with test buttons). Chime WAVs are synthesised originals. Audio is skipped under `flutter test`. Add new alerts to `liveAlertsProvider`, never to a widget.
- v5.5.0: `LiveAlert.repeatEvery` -- urgent warnings (MACH > MMO, GEAR SPEED, CG AFT/FWD LIMIT, GEAR UP — BELOW 250 KT) re-chime every 2 s, DESCEND NOW every 12 s, others once; 500 ms repeat timer in `AlertChimeNotifier`; warning.wav regenerated louder (same tones, tanh limiter, -0.3 dBFS).
- v5.5.1: height above ground comes from the airport DB, not the bridge (owner preference): `TelemetryModel.heightAboveGround(fieldElevationFt:)` = MSL altitude - departure/arrival elevation. Used by the gear-up alert (arrival), TOD/ETA descent distance (arrival) and `classifyBurnPhase` (departure, plus the sim's `onGround` flag, new optional param).
- v5.5.2: version display/update check read `pubspec.yaml` via `package_info_plus` (`appVersionProvider` in `lib/core/app_version.dart`; no hardcoded Dart version); Inno Setup takes `/DAppVer=` from CI.
- v5.5.3: Inno installer wipes the previous install (`[InstallDelete]`, guarded by `IsExistingInstall`) and uninstall removes `{app}`; settings live in `%APPDATA%` (SharedPreferences) so they survive. 
- v5.5.4: airport-DB cache moved out of the install folder to `getApplicationCacheDirectory()` (%LOCALAPPDATA% on Windows; temp-dir fallback) -- Program Files is read-only for the unelevated app. Never write next to the exe.
- v5.5.5: AdMob ids injected, not hardcoded: banner unit via `--dart-define=ADMOB_BANNER_ID` (release only; debug/profile always Google test ads), app id via `ADMOB_APP_ID` env -> manifest placeholder `admobAppId`. CI reads GitHub repo *variables* (ids are public).
- v5.5.6: Android/Linux application id is `com.theawesomeray.concorde_efb` (matches the AdMob app + Play listing; Kotlin package moved). Windows `CompanyName` and macOS/iOS bundle ids intentionally still `com.dwaipayanray95...` -- the Windows one names the %APPDATA% settings folder, changing it would reset users' settings.
- v5.5.7: AdMob app id now applies to ALL Android build types (UMP consent message is tied to it); only the banner unit differs (release = real, else Google test). Adaptive anchored banner. `--dart-define=UMP_TEST_DEVICE=<hash>` simulates an EEA user in non-release builds to test the consent form.
- v5.5.8: real AdMob ids hardcoded (public): app `ca-app-pub-9702367158265323~7847975433` in `android/app/build.gradle.kts` (all build types), banner unit `.../2117136608` in `efb_ad_banner.dart` (release builds ONLY; debug/profile always Google's test unit). No repo variables needed.
- v5.5.9: phone UI zoom: `PhoneUiScaler` (`lib/core/ui_scale.dart`, `kPhoneUiScale = 0.85`, one number to tune) in `MaterialApp.builder` lays the app out on a 1/scale larger virtual canvas on Android/iOS phones (shortest side < 600 dp); `UiScale.of(context)` exposes the factor -- the AdMob banner counter-scales itself (native views can't be shrunk) and requests its width in real dp. Settings dialog is `scrollable`. Breakpoints using `MediaQuery` see the VIRTUAL size.
- v5.6.0: `TelemetryModel.flightLoaded` (not at 0,0 and fuel > 500 kg) gates `liveNavProvider` + `liveAlertsProvider` -- MSFS menu/loading frames produce no alerts/chimes; CG alerts armed by `allEnginesRunning` (bridge sends per-engine `engineFuelFlowKgH`, > 150 kg/h each; older bridges: total > 1,000 kg/h) or airborne; tap an MFD alert pill -> `AlertChimeNotifier.silence(text)` mutes it 10 s, re-chimes if still active. Chimes are local per device.
- v5.6.1: bridge sends `roll = -PLANE BANK DEGREES` (sim is + = left; app/ADI use + = right; old recordings stay mirrored); CG alerts armed only airborne > 10,000 ft above the departure field (replaces the engines-running gate; `allEnginesRunning` kept but unused); `liveNavProvider` predicts fuel at dest with the planned cruise flow (`cruiseFLProvider`) until phase is cruise/descent, and fuel alerts arm only in cruise/descent.
- v5.7.0: `takeoffCgTargetPct = 56` / `cgCorridorArmFt = 10000` in `live_flight_math.dart` (owner-provided takeoff CG); `CgTrimCard` (now a ConsumerWidget) shows TAKEOFF TARGET 56.0 and no limit advice on the ground / below 10,000 ft above the departure field; CG alerts use the same threshold.
- v5.8.0: `ConcordeLogic.plannedCruiseFl(distanceNm, direction:, simbriefFl:)` (owner rule): highest Non-RVSM FL >= 410 whose `minSupersonicDistanceNm` fits, else SimBrief `general.initial_altitude`/100 capped by `maxSubsonicFlForDistance` (and < FL410); applied on SimBrief import (direction from OFP origin/destination pos). Planner stat `FUEL ENDURANCE` = endurance h, subtext ETE + reserves + margin (margin is 0 unless extra fuel, since FOB = required block).
- v5.8.1: subsonic branch of `plannedCruiseFl` = max(SimBrief FL, suggested) capped at maxFit; suggested = min(maxFit, FL290) with semicircular parity below FL410 (`_snapSubsonicDown`: E odd, W even).
- v5.8.2: `CruiseFLNotifier.autoPlan(distanceNm, sourceFl:, direction:)` wraps `plannedCruiseFl`; called on SimBrief import, file import (`ParsedFlightPlan.cruiseAltFt`/100) and every planned-distance edit (no source FL).
- v5.8.3: `liveNavProvider` scales remaining-along-polyline by plannedDistance / polylineNm (navlog fixes skip SID/STAR legs, so the polyline is shorter than SimBrief route_distance) -- progress is 0 at the gate.
- v5.9.0: `DispatchBanner` GO shows a quick-figures row (V1/VR/V2, TOW, FUEL, FL, DEP RWY, LW, VAPP, ARR RWY; hidden in compact phone mode); width < 150 ft no longer a dispatch caution (perf cards still flag it); cruise FL field ignores empty/< 100 input; `LiveNav.progress` = 0 on the ground until past half the route.
- v5.9.1: clean GO puts the quick figures inline in the banner row (`_figures`); with cautions they stay on a second row.
- v5.10.0: `forceSupersonicProvider` (not persisted; switch under the FL box, toggling re-runs `autoPlan`): `plannedCruiseFl`/`buildCruiseMissionProfile(forceSupersonic:)` drop the 100 nm minimum Mach 2 cruise from `minSupersonicDistanceNm(minCruiseNm:)`. Dispatch quick figures add `CRZ M<mach> · <TAS> KT` for `mission.targetCruiseFl`; FL figure is the flown (target) level; DEP/ARR labels shortened.
- v5.10.1: force-supersonic switch + logic removed at the owner's request (UI looked bad); CRZ speed on the dispatch strip kept.
- v5.11.0: `dismissedAlertsProvider` (`DismissedAlertsNotifier`, in `live_alerts_provider.dart`) + `clearableAlerts = {'DESCEND NOW'}`: tapping a clearable MFD pill dismisses it (filtered out of `liveAlertsProvider`) until `liveNavProvider` phase leaves cruise; other pills keep 10 s silence.
- v5.12.0: gear-up alert split (all need gear UP, airborne, V/S < -300, `pred.distToDestNm`, height above arrival elevation): `GEAR UP — CHECK GEAR` amber once (<= 30 nm, < 5,000 ft, < 250 kt) / `GEAR UP — TOO LOW` red every 2 s (<= 10 nm, < 2,000 ft, < 220 kt); both in `clearableAlerts`, `DismissedAlertsNotifier` re-arms per alert (DESCEND NOW when phase leaves cruise, gear alerts when gear != UP or V/S > +500).
- v5.12.1: Android launcher label is `Concorde EFB` (was the raw `concorde_efb`). Play Store listing copy, data-safety answers and graphics live in `docs/PLAY_STORE.md` + `store/google-play/`.
- v5.13.0: `EfbTextField` never rewrites text while focused (clearing a number box used to inject "0" before the caret -> 3000 typed became 30000), resyncs on blur; `resetFuelInputs(ref)` + RESET FUEL button on the Cruise & Fuel card (taxi/contingency/final reserve/extra back to defaults); file/manual imports without an alternate clear the old ALT (SimBrief already did).
- v5.13.1: SimBrief import moved to `_applySimBrief` in `flight_plan_section.dart`; every OFP field read via `_str()` (SimBrief JSON makes empty elements `{}`, which used to throw mid-import and leave stale distance/FL/ALT); distance/FL/ALT applied first, airports last; failures shown in a snackbar.
- v5.13.2: Departure/Arrival ICAO setters no longer call `resetToAuto()` on the runway notifier (it re-entered `_RunwayIdNotifier` via its airport listener -> CircularDependencyError, the real cause of the half-finished SimBrief import); the notifier's `ref.listen(airport)` handles the reset.
- v5.14.0: vPilot `.vfp` import (`FlightPlanImportService.parseVfp`, attributes on `<FlightPlan/>`; tried first in `parseAnyXml`); `decodeFile` handles UTF-16/BOM; macOS entitlements gained `com.apple.security.files.user-selected.read-only` (file_picker needs it under the sandbox).
- v5.14.1: every plan import (`_applySimBrief`, `_applyParsedPlan`) invalidates `extraFuelProvider` (extra back to 0); taxi/contingency/reserve persist.

Keep this list rolling forward — append new notable changes here as they land, don't let it go
stale like the old React-era version of this file did.

### Deferred backlog (agreed with the owner, not started)

- No-reheat takeoff thresholds (155 t gate, x1.35 factor) remain estimates -- the DC Designs manual
  doesn't give them (checked v5.3.0).
- Play Console data-safety form (declare advertising ID / device data via AdMob).
- AdMob: publish the GDPR message (Privacy & messaging), finish the payments profile, link the app
  to its Play listing once live, host `app-ads.txt` on the developer-site domain root.
- Crash reporting.
- Persist flight plan / fuel inputs / checklist progress across restarts.
- Android release signing is wired (`android/app/build.gradle.kts`, `build.yml`; owner setup steps in `docs/ANDROID_SIGNING.md`; needs the 4 `ANDROID_*` GitHub secrets). Windows signing is wired for SignPath Foundation (`build.yml` windows job: signs `concorde_efb.exe` + `msfs_bridge.exe` before Inno, then the installer; release mode only; OFF until `SIGNPATH_API_TOKEN` secret + `SIGNPATH_ORGANIZATION_ID` variable exist; owner steps in `docs/WINDOWS_SIGNING.md`). It needs the SignPath Foundation application approved (the repo is Apache-2.0: `LICENSE` + `NOTICE`; the bundled Microsoft `SimConnect.dll` is the one non-open component SignPath may ask about). Still open: macOS notarization (Apple Developer ID) -- all three platforms' signing are separate from each other.
- Wi-Fi link: some Android devices filter UDP broadcasts (needs a `WifiManager.MulticastLock`
  platform channel if discovery proves unreliable -- manual IP entry works regardless).
- Feature ideas: CG / trim-tank transfer planner, live planned-vs-actual fuel, telemetry-driven
  checklist auto-advance, exportable takeoff/landing card, kg/lb toggle, TAF + alternate weather.

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
- The website (`public/`) must stay ad-free and tracker-free: the privacy policy promises it and Play/AdMob
  review the site. No ad-network scripts (Monetag/A-ADS etc. were removed). Every page links to the privacy
  page and the privacy page links back home; keep it that way. Nav rows must wrap (`flex-wrap`) so phones
  don't scroll sideways.
- Never commit machine-specific paths (e.g. `org.gradle.java.home=C:/Users/...` in
  `android/gradle.properties` -- it broke macOS/CI Android builds). JDK is chosen per machine via
  `flutter config --jdk-dir <path>` or `~/.gradle/gradle.properties`.
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
- Bump the version per the versioning rule in section 1 (`pubspec.yaml` + changelog entry).
- Update this section (7) with a one-line summary of what landed, so it doesn't go stale again.

## 10) Source-of-Truth References

- Product behavior: `lib/core/concorde_logic.dart`, `lib/core/concorde_constants.dart`
- Theme system: `lib/core/app_colors.dart`
- Changelog history: `public/changelog/entries.json`
- Human-readable overview: `README.md`
- Web deployment pipeline: `.github/workflows/pages.yml`
- Desktop/mobile build + release pipeline: `.github/workflows/build.yml`
