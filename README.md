# Concorde EFB (MSFS 2020/2024 · DC Designs)

A lightweight, browser-based electronic flight bag for planning DC Designs Concorde flights in Microsoft Flight Simulator 2020 and 2024.

I’m Ray, a flight enthusiast who loves the Concorde. I have no formal coding background — this app exists thanks to a frankly excruciating amount of late-night tinkering, trial-and-error, and stubborn curiosity. If you find it useful, show some love. 💙

Made with love by [@theawesomeray](https://github.com/theawesomeray)

---

## ✨ What it does
- **Manual distance input (NM):** Paste your route distance from SimBrief/your planner for accuracy.
- **Altitude-aware fuel model:** Climb/Cruise/Descent segments; altitude burn factor; taxi fuel; contingency; final reserve; and alternate fuel (ARR → ALT).
- **Trim tank fuel:** Total fuel required = Block + Trim.
- **Endurance logic:** Compares fuel endurance vs ETE + reserves (what really matters).
- **Weight-aware performance:** Computes indicative V1 / VR / V2, and landing VLS / VAPP using √weight scaling.
- **Feasibility checks:** Departure and landing runway length checks at computed TOW/LW; shows why it’s not feasible.
- **Runway winds:** Fetch METARs and see headwind/crosswind components per selected runway.
- **Smart runway pick:** Auto-selects the longest runway at dep/arr (you can override).
- **Self-tests:** Built-in diagnostics for sanity checks.

Built for MSFS 2020/2024 and the DC Designs Concorde. Not affiliated with DC Designs or Microsoft. Use for planning only — verify in-sim.

---

## 🧭 Using the App
1. Enter Departure and Arrival ICAOs.
2. Pick the suggested (longest) runway, or choose another.
3. Paste your planned distance (NM) from your flight planner.
4. Set Cruise FL, Taxi fuel, Contingency %, Final reserve, optional Alternate ICAO, and Trim tank fuel.
5. Click **Fetch METARs** to auto-parse runway headwind/crosswind.
6. Review:
   - Total time (ETE) vs Fuel endurance (must cover ETE + reserves).
   - Departure/Landing feasibility with required vs available distances.
   - Indicative V1/VR/V2 and VLS/VAPP.

Always cross-check with the aircraft manual and your own procedures.

---

## 📦 Tech
- React + TypeScript + Vite
- Tailwind CSS
- PapaParse (CSV parsing)
- Data sources:
  - Airports/Runways: [OurAirports](https://ourairports.com/data/)
  - METARs: [AviationWeather.gov](https://aviationweather.gov/data/api/#/Data/dataMetars) (primary) and [VATSIM METAR](https://metar.vatsim.net/) (fallback)

---

## 💬 Feature requests / feedback
Ping me on Discord: **@theawesomeray**. I’m always up for improving this!

---

## 🙏 Support the project
If this helped you plan a slick supersonic hop, consider buying me a coffee:
- UPI: `upi://pay?pa=YOUR_UPI_ID_HERE&pn=Ray&cu=INR`

(Replace `YOUR_UPI_ID_HERE` with your actual UPI handle.)

Every bit of support keeps me motivated to keep polishing this for the Concorde community. ✈️💙

---

## ⚠️ Disclaimer
This tool is for flight planning and educational use. Values are heuristic, indicative, and must be validated in-sim. No warranties. Not affiliated with DC Designs, Microsoft, or any data provider.

---

## 📄 License
Copyright © 2025 Ray ([@theawesomeray](https://github.com/theawesomeray)).
All rights reserved. Contact me for reuse or distribution.
