# Concorde EFB (MSFS 2020/2024 · DC Designs)
A lightweight, high-fidelity Electronic Flight Bag (EFB) built for planning supersonic DC Designs Concorde flights in Microsoft Flight Simulator 2020 and 2024.


I’m Ray, a flight enthusiast who loves flying the Concorde. I have no formal coding background — this app exists thanks to a frankly excruciating amount of late-night tinkering, trial-and-error, and stubborn curiosity. If you find it useful, show some love. 💙

Made with love by [@theawesomeray](https://instagram.com/theawesomeray)

---

## ✨ Features
- **Interactive Multi-Phase Checklists**: Full checklist sequences for all phases of flight (Cold & Dark to Shutdown) with dynamic takeoff and landing speed readings from your active flight plan.
- **Manual Distance Input (NM)**: Paste your route distance from SimBrief/your planner for calculations.
- **Supersonic Fuel Model**: Segmented Climb, Acceleration, Cruise-climb, and Descent phases with altitude-aware fuel burn factors.
- **Safety Alerts**: Live MTOW/MLW validations, landing/takeoff runway feasibility checks, alternate routing distances, and significant tailwind warnings.
- **Dynamic Alternate Routing (ALT)**: Change your alternate airport directly in the Cruise & Fuel panel for instant block fuel recalculation.
- **METAR & Environmental Corrections**: Live QNH, temperature (OAT/ISA deviation), and headwind/crosswind components automatically factored into takeoff/landing runs.
- **Updater & Exit Prompts**: Integrated GitHub Releases tracker alerts you of new updates, and a prompt helps you rate the app 5-stars on flightsim.to upon first exit.

---

## 🧭 Using the App
1. Enter your **Departure**, **Arrival**, and **Alternate** ICAOs.
2. Select your runways from the auto-parsed dropdown (the app will suggest the longest runway automatically).
3. Input your planned route distance.
4. Customize your Cruise FL, Taxi fuel, Contingency, and reserves.
5. Click **Fetch METARs** to download live weather info.
6. Toggle the **Takeoff Reheat** switch to see how dry takeoffs affect your performance.
7. Follow the **Checklists** tab to guide your flight crew from gate to gate.

---

## 📦 Tech Stack
- **Framework**: Flutter (Dart) for smooth performance on desktop, mobile, and web.
- **State Management**: Riverpod for clean reactive state wiring.
- **Persistence**: SharedPreferences.
- **Installers**: Inno Setup (Windows) & DMG packaging (macOS).
- **CI/CD**: GitHub Actions workflows to compile release builds on-demand.

---

## 🙏 Support the project
If this helped you plan a slick supersonic hop, consider supporting:
- Patreon: [Support Ray on Patreon](https://www.patreon.com/c/theawesomeray)
- UPI: `dwaipayanray95@ptaxis` (Scan the QR Code in the desktop support banner!)

---

## ⚠️ Disclaimer
This tool is for flight planning and educational use. Values are heuristic, indicative, and must be validated in-sim. Not affiliated with DC Designs, Microsoft, or any data provider.

---

## Changelog
Current version: v3.1.20

### v3.1.20 — 2026-06-30
- **Flutter Migration**: Migrated the entire application core from React/TypeScript/Tauri to a unified, highly optimized Flutter codebase.
- **Multi-Phase Checklists**: Added an interactive Checklists tab covering Cold & Dark, Cockpit Prep, Engine Start, Takeoff, Decel & Descent, Approach, and After Landing.
- **Speed Plumbed Checklist Integration**: Embedded dynamic takeoff ($V_1$, $V_R$, $V_2$) and landing ($V_{APP}$) speeds directly into the relevant checklist steps.
- **Takeoff Reheat (Afterburner) Option**: Added a switch toggle to calculate runway takeoff runs and feasibility with or without reheaters (dry takeoff).
- **Alternate (ALT) Input**: Placed a direct Alternate ICAO field in the Cruise & Fuel Management section for quick routing and fuel adjustments.
- **Local Persistence**: Remembers your SimBrief username across application launches.
- **Update Tracker**: Integrates with the GitHub Releases API to show a top-banner notification when a newer release is published on GitHub.
- **First Close Interceptor**: Prompts desktop users to rate the app on flightsim.to upon their first exit.
- **UPI QR Code & Patreon**: Added a donation choices modal displaying a scan-to-pay UPI QR code alongside Patreon shortcuts.
- **GitHub Actions Releases**: Setup `.github/workflows/flutter-build.yml` to compile release-ready APKs, DMGs, and Windows EXE Installers (built with Inno Setup and uninstallers) on-demand.

### v2.1.0 — 2026-02-16
- Release version bumped globally to v2.1.0 (app, npm package, Cargo manifest, and Tauri config).
- Removed in-app build marker display; app now shows only the semantic version.
- Desktop external links fixed by enabling Tauri opener plugin and permissions.
- Fuel model: Implement Concorde-style cruise-climb mission profile (climb + accel + segmented cruise-climb + descent) and use it for ETE/trip fuel/endurance math.
- Performance: Add METAR-corrected runway requirement model (QNH, OAT/ISA, headwind/tailwind) for takeoff/landing feasibility.
- Ops safety: Add Operational Alerts panel for fuel deficit, alternate risk, MTOW/MLW exceedance, runway shortfall, and tailwind warnings.

### v0.85
- Auto cruise FL recommendation based on inferred eastbound/westbound direction (DEP→ARR).
- Non-RVSM cruise FL validation/snapping above FL410 (e.g., FL410E / FL430W … up to FL590).
- Enforce Concorde cruise ceiling (max FL590) with clearer clamping behavior.

### v0.84
- Infer eastbound/westbound direction from route bearing and validate Non-RVSM cruise FLs.

### v0.83
- Runway selection fixes so users can select the ATC-assigned runway from dropdowns.
- Add fuel capacity warning when requested fuel exceeds Concorde tank capacity.
- Update landing speed heuristics (VLS/VAPP) to be more Concorde-appropriate.
- Updated README to include full changelog.
- Uniform versioning and changelog tracking throughout the app.

### v0.82
- README refresh and initial public changelog.

### v0.81 — 2025-11-10
- Fix: White-screen from duplicate App export; introduced ErrorBoundary.
- CI: GitHub Pages build stabilized (TypeScript strict fixes, Vite config).
- Types: Moved papaparse ambient types into a proper .d.ts shim; removed inline module augmentation.
- Polish: Minor UI and input validation tweaks.

### v0.80 — 2025-11-10
- Repo bootstrap: Vite + React + TypeScript + Tailwind wired.
- Added GitHub Actions workflow for Pages.

### v0.79
- GitHub Pages deployment pipeline added (build → upload artifact → deploy).

### v0.78
- App structure cleanup: single default export (ConcordeEFB) to avoid HMR/SSR collisions.
- Dev server white-screen resolved; safer imports and state initialization.

### v0.77
- Fix: Unbalanced JSX in “Planned Distance” card (missing closing tag).

### v0.76
- Fix: SyntaxError: Unterminated regular expression by replacing newline split with /\r?\n/.

### v0.75
- Logic: Departure feasibility now uses actual TOW (OEW + full pax + entered fuel) rather than always MTOW.
- Fuel logic: Endurance check = ETE + reserves (contingency + final + alternate). Accounts for airborne fuel (block − taxi).
- Performance: Added V1 / VR / V2 (takeoff) and VLS / VAPP (landing) via √weight scaling models.
- Fuel panel: Added Trim Tank Fuel and Total Fuel Required = Block + Trim.
- Alternate planning: ARR→ALT distance and alternate fuel integrated into block calculation.

### v0.71
- Weather: METAR fetch with AviationWeather primary and VATSIM fallback.
- Runway: Auto-select longest runway; compute headwind/crosswind components.

### v0.70 — “Canvas” feature set
- Manual planned distance (NM) entry (no auto route expansion for accuracy).
- Departure & landing feasibility with reasons (required vs available).
- All units metric (kg, m). Crosswind/headwind shown.
- Added diagnostics/self-tests (distance sanity, fuel monotonicity, feasibility, etc.).

### v0.60
- Routing: Waypoint tokeniser. Later deprecated.

### v0.40
- Core math: Great-circle distance, climb/descent heuristics, altitude-sensitive burn factor.

### v0.20
- Prototype UI: Basic inputs for ICAO, FL, fuel; first pass block-fuel math.

### v0.10
- Proof-of-concept commit: Project skeleton and initial calculations.
