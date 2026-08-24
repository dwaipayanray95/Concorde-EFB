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
- UPI: Scan the QR Code in the desktop support banner!

---

## ⚠️ Disclaimer
This tool is for flight planning and educational use. Values are heuristic, indicative, and must be validated in-sim. Not affiliated with DC Designs, Microsoft, or any data provider.

---

## 📋 Changelog
See the [in-app/web changelog](public/changelog/index.html) (backed by `public/changelog/entries.json`) for the full version history.
