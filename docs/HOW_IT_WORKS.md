# How Concorde EFB works

This document explains **where the app's data comes from** and **what each calculation assumes**. It is written for pilots and non-programmers. Code locations are given in brackets for developers.

The golden rule: **the app is a planning aid.** Every figure is indicative. Where the DC Designs Concorde manual gives a number, the manual wins. If the app and the manual disagree, use the manual and tell the developer.

---

## 1. Where the data comes from

| Data | Source | Used for | When it's fetched |
|---|---|---|---|
| Airports, runways, elevations, navaids | [OurAirports](https://ourairports.com) open data (CSV files on GitHub) | Airport lookup, runway lengths, widths, headings, elevations | Once, then cached on your PC (`%LOCALAPPDATA%` on Windows) [`lib/services/airport_database_service.dart`] |
| Live weather (METAR) | 1. VATSIM METAR service, 2. aviationweather.gov, 3. NOAA/NWS text feed. First one to answer wins | Wind, QNH, temperature, visibility, flight category, runway condition hint | Every 10 minutes while watched, and when you change an airport [`lib/services/metar_service.dart`] |
| SimBrief flight plan | SimBrief XML/JSON API, using your SimBrief username | Route distance, navlog fixes, cruise level, alternate, call sign, registration, passengers, runways | When you press import [`lib/services/simbrief_service.dart`] |
| Flight plan files | `.pln` (Microsoft Flight Simulator), `.vfp` (vPilot), route XML | Same as SimBrief, from a file on disk [`lib/services/flight_plan_import_service.dart`] |  When you open the file |
| Live aircraft data | MSFS through SimConnect, via a bundled bridge (`msfs_bridge.exe`) on `ws://localhost:8082` | Flight Monitor: engines, fuel, attitude, speeds, gear, position, altitude | Continuously while the bridge is running [`lib/core/sim_bridge_launcher.dart`, `tools/simbridge/msfs_bridge.py`] |
| Phone telemetry | The desktop bridge over your home Wi-Fi (port 8082; discovery beacon on UDP 8083) | Same as above, on Android | Continuously, when paired [`lib/features/flight_monitor/data/services/lan_link.dart`] |
| Ads | Google AdMob (and Google UMP for EEA consent) | Banner ads on Android | Android only [`lib/services/ad_consent_service.dart`] |
| Visitor counter | visitorbadge.io | Footer launch counter | Once per session |
| Update check | GitHub Releases API (`/releases/latest`) | "Update available" banner | Periodically [`lib/core/app_links.dart`, `lib/screens/widgets/app_header.dart`] |

**What the app does not use:**
- No live ATC, traffic or AI data.
- No wind aloft, no forecast weather. Only the current METAR.
- No sim data is sent to any server. Telemetry stays on your PC and your local Wi-Fi.

**Everything you enter is stored only on your device** (SharedPreferences for settings; the logbook in the app's data folder). Settings are kept in `%APPDATA%` on Windows.

---

## 2. Aircraft constants

These are fixed numbers in [`lib/core/concorde_constants.dart`].

| Item | Value | Source |
|---|---|---|
| Max take-off weight (MTOW) | 185,070 kg | BA Concorde Flying Manual / DC Designs |
| Max landing weight (MLW) | 111,130 kg | same |
| Max zero fuel weight (MZFW) | 92,080 kg | same (shown for reference; not checked by the app) |
| Max ramp (taxi) weight | 187,000 kg | DC Designs manual |
| Fuel capacity | 95,681 kg | Aircraft spec used in the app |
| Empty weight (OEW) | 78,700 kg | Aircraft spec used in the app |
| Passenger mass | 84 kg each, 100 passengers by default | Estimate |
| Take-off speeds at MTOW | V1 170 / VR 190 / V2 220 kt | DC Designs manual |
| VREF at MLW | 195 kt | DC Designs manual (approach speeds 150-207 kt) |
| Maximum landing gear speed (VLE) | 270 kt | Used by the gear-speed alert |
| MMO | Mach 2.04 | BA Flying Manual |
| Take-off runway at MTOW, sea level, ISA, no wind, reheat | 2,743 m | DC Designs manual worked example |
| Landing runway at MLW | 2,200 m | Estimate |
| Max crosswind | 30 kt (gusts included) | BA Flying Manual (*not* in DC Designs manual) |
| Max tailwind | 10 kt (gusts included) | BA Flying Manual (*not* in DC Designs manual) |
| Min runway width | 150 ft (caution only) | BA Flying Manual |
| Airfield elevation limits | -1,000 ft to 8,000 ft | BA Flying Manual |

**Defaults when you start the app:** departure EGLL, arrival KJFK, alternate KBOS, planned distance 3,000 NM, 100 passengers, taxi fuel 2,500 kg, contingency 5 %, final reserve 6,000 kg (30 min hold), reheat on.

---

## 3. Distances: always route distance

The app **never** uses the airport-to-airport straight line for fuel, time, top of descent or ETA. Distances are taken in this order:

1. **SimBrief** route distance, or the total of the imported route legs.
2. **Imported route fixes** (SimBrief navlog or `.pln` waypoints) are joined into a polyline, which gives the remaining distance during flight.
3. **If there are no fixes:** great-circle distance multiplied by the planned-to-great-circle ratio. The estimate for two airports alone is `great circle x 1.04 + 40 NM` (4 % for airways, 40 NM for SID/STAR).
4. **Alternate:** the SimBrief alternate distance if present, otherwise the estimate above.

Note: the polyline is shorter than SimBrief's route distance because SimBrief includes SID and STAR legs the navlog doesn't list. The live progress calculation scales for this. [`lib/core/route_math.dart`, `lib/features/flight_monitor/presentation/controllers/live_nav_provider.dart`]

---

## 4. Cruise flight level (FL)

- **Supersonic is preferred.** The app picks the highest supersonic level (FL410 or above) that the sector distance can fit. The distance needed for each level comes from `minSupersonicDistanceNm`: climb to FL240, plus 220 NM transonic acceleration, plus at least 100 NM of Mach 2 cruise, plus descent.
- **Subsonic sectors** (too short for supersonic): the highest subsonic level that fits, around FL290 (M0.95) by default. Subsonic levels follow the semicircular rule (eastbound odd thousands, westbound even), so the level is snapped to match your direction.
- **Non-RVSM supersonic levels** are used above FL410:
  - Eastbound: 410, 450, 490, 530, 570
  - Westbound: 430, 470, 510, 550, 590
- **Direction** is worked out from the great-circle bearing from departure to arrival (under 180° is east).
- **SimBrief's flight level** is only used to override the subsonic choice, never the supersonic one.
- **Force supersonic** is not available (it was removed at the owner's request).

[`lib/core/concorde_logic.dart` `plannedCruiseFl`]

---

## 5. Fuel and trip

Trip fuel is the sum of phase burns. Each phase is **fuel flow x time**, with time = distance / ground speed. **Still air is assumed**: no wind is included in trip time or trip fuel.

| Phase | Assumption | Fuel flow (4 engines) |
|---|---|---|
| Take-off allowance | 2,000 kg, added to departure only | (reheat roll and initial climb) |
| Subsonic climb | 2,000 ft/min average, 360 kt ground speed, to FL240 | 26,000 kg/h |
| Transonic acceleration | 16 min, 220 NM, FL240 to FL500 | 60,000 kg/h |
| Mach 2 cruise-climb | Equal distance in 20 FL steps from FL500 to the selected level. True airspeed ~1,170 kt | 21,000 kg/h at FL500, tapering linearly to 17,500 kg/h at FL600 |
| Subsonic cruise (below FL410) | M0.95 | 15,000 kg/h |
| Descent and approach | Distance = altitude / 300 + 30 NM. Ground speed 480 kt above FL410, 330 kt below | 8,500 kg/h |

Other fuel figures:

- **Holding:** 12,000 kg/h. Used for endurance and reserves.
- **Missed approach allowance:** 1,000 kg, added to the alternate.
- **Taxi:** an input (default 2,500 kg). It is burned before take-off.
- **Contingency:** an input percentage of trip fuel (default 5 %).
- **Final reserve:** an input (default 6,000 kg, a 30 min hold).
- **Alternate fuel:** a subsonic diversion profile at FL290 with no take-off allowance, plus the 1,000 kg missed approach allowance. Alternates over 500 NM are flagged as beyond sensible diversion range.
- **Block fuel** = trip + taxi + contingency + alternate + final reserve. Extra fuel is added on top.
- **Capacity:** fuel above 95,681 kg can't be loaded. The app flags an over-capacity NO-GO.

**Golden test:** an LHR-JFK sector of about 3,150 NM should give roughly 71 t trip fuel and about 3 h 13 min. This is checked by `test/golden_flight_test.dart`. If you change any fuel constant, that test must still pass.

**Endurance:** trip fuel lasts the trip time. Any fuel left over is converted to time at 12,000 kg/h. The app shows endurance, the time required (trip + contingency + alternate + reserve at holding rate), and a NO-GO if endurance falls short.

**Accuracy:** these are calibrated estimates for a planning tool. They do not model the DC Designs fuel system, real climb profiles, weather, temperature effects or ATC restrictions.

---

## 6. Weights

- **Zero fuel weight** = empty weight + passengers.
- **Ramp weight** = zero fuel + fuel on board (capped at capacity).
- **Take-off weight (TOW)** = ramp - taxi fuel.
- **Landing weight (LW)** = TOW - trip fuel (never below zero fuel).

Limits checked: TOW against MTOW (185,070 kg), ramp against max taxi (187,000 kg), LW against MLW (111,130 kg).

---

## 7. Speeds

**Take-off (V1, VR, V2):** the stall-based speeds scale with the square root of weight relative to MTOW.

- V2 = 220 kt x sqrt(TOW / MTOW), at least 185 kt
- VR = 190 kt x sqrt(TOW / MTOW), at least 165 kt, never above V2
- V1 = 170 kt x sqrt(TOW / MTOW), at least 130 kt, never above VR
- On a **wet** runway V1 is reduced by 8 kt; on a **contaminated** runway by 15 kt.

**Landing:**

- VREF = 195 kt x sqrt(LW / MLW), at least 145 kt
- VAPP = VREF + half the steady headwind + the gust increment, limited to between +5 and +20 kt

These are **indicative**. Always use the manual's speed tables and your own checks.

---

## 8. Runway performance

### Take-off
- **Base distance:** 2,743 m x (TOW / MTOW)², which means distance grows with the square of weight.
- **Without reheat:** base x 1.35. Above 155 t the app shows a NO-GO for a no-reheat take-off. (The 155 t gate and the 1.35 factor are **estimates**; the DC Designs manual doesn't give them.)

### Landing
- **Base distance:** 2,200 m x (LW / MLW)^1.15.

### Corrections (applied to the base distance)

| Factor | Take-off | Landing |
|---|---|---|
| Pressure altitude | +1.2 % per 1,000 ft (limited to -8 % to +35 %) | +0.7 % per 1,000 ft |
| Temperature above or below ISA | +1 % per °C above ISA, -0.4 % per °C below | +0.5 % per °C above, -0.2 % per °C below |
| Headwind | -1 % per kt, max -20 % | -1 % per kt, max -15 % |
| Tailwind | +3 % per kt, max +50 % | +4 % per kt, max +65 % |
| Wet runway | +15 % | +15 % |
| Contaminated runway | +30 % | +40 % |

The total factor is never below 0.7. Wet and contaminated surfaces use estimated factors, not manual data.

### Hard limits (NO-GO)
- Crosswind above 30 kt, gusts included
- Tailwind above 10 kt, gusts included
- Airfield elevation outside -1,000 to 8,000 ft
- Runway too short for the required distance

### Cautions (not NO-GO)
- Runway narrower than 150 ft
- Wind unknown (no METAR). The app **flags** this, it does not assume calm
- Wet or contaminated runway selected

### Runway selection
The app picks the departure runway in this order: no tailwind; then crosswind 15 kt or less; then the longest. Once you choose a runway or import a SimBrief plan, your choice is kept for that airport until you change airports.

**Variable wind (VRB):** the app assumes the worst case, full speed as both tailwind and crosswind.

**Runway condition (AUTO):** taken from the METAR text (e.g. rain or snow codes). You can force DRY, WET or CONTAMINATED.

[`lib/core/concorde_logic.dart` `takeoffFeasibleM`, `landingFeasibleM`, `runwayLengthCorrectionFactor`]

---

## 9. Dispatch banner

The banner combines every check into one state:

- **NO-GO** (red): fuel over capacity, endurance below required, TOW above MTOW, ramp above max taxi, LW above MLW, runway too short, crosswind or tailwind too strong, airfield outside limits, no-reheat take-off above 155 t.
- **CAUTION** (amber): wind unknown, wet or contaminated runway, no alternate, alternate the same as arrival, alternate not found, alternate beyond 500 NM, cruise level capped because the sector is short.
- **GO**: none of the above.

---

## 10. Weather (METAR)

- The app reads the wind (direction, speed, gusts), QNH, temperature, visibility and cloud from the METAR text.
- **Flight category** (VFR, MVFR, IFR, LIFR) uses the standard visibility and ceiling rules. The worse of the two wins.
- Failure to get a METAR shows **OFFLINE** with a retry button. The app never shows "calm" weather when it has no data.
- Raw METAR text is always visible.

---

## 11. Flight Monitor (live telemetry)

Telemetry comes from the bridge (see section 1). The app:

- Shows engines, fuel, CG and trim advice (based on the Mach-dependent CG corridor digitised from the DC Designs manual's chart), attitude, altitude, speeds, gear and nose state.
- **Phase** is worked out from height above ground (from the airport elevation, not the sim's altimeter), vertical speed and the sim's on-ground flag: ground, climb, reheat acceleration, cruise or descent.
- **Predicted fuel at destination** uses the phase's fuel flow (30-second average of the real fuel flow). Cruise uses the planned cruise flow until the phase changes.
- **Altitude** on the PFD is indicated altitude (matches the cockpit altimeter). Height and planning maths use true altitude.
- **Alerts** include MACH > MMO, gear speed, CG limits, gear up below 250 kt, DESCEND NOW, fuel below final reserve at destination, and no alternate fuel at destination. Alerts beep. Some can be dismissed for a while.

These predictions are **simplified**. Treat them as a second opinion, not as the autopilot's view.

### Touchdown rating

Landing rating comes from the touchdown rate of descent and vertical G ([`lib/features/logbook/domain/landing_rating.dart`]):

| Rating | Rate (ft/min) |
|---|---|
| BUTTER | under 120 |
| SMOOTH | 120 to 239 |
| FIRM | 240 to 399 |
| HARD | 400 to 599 |
| INSPECTION | 600 or more, or 2.6 G or more |

The lower bands are indicative only. Concorde has no real flare, so "firm" is normal for her.

---

## 12. Logbook

- **Start of flight:** engines running on the ground.
- **Take-off:** leaves the ground and passes 80 kt.
- **Touchdown:** back on the ground, with the rate and G from the bridge. Bounces within 5 seconds are merged. A go-around is recorded if the aircraft is airborne again for more than 15 seconds.
- **End of flight:** all engines off on the ground for 3 seconds.
- Track points are saved every 5 seconds (time, position, altitude, ground speed).

**Storage:** each flight is one JSON file in the app's data folder (`logbook/` inside the application support folder). Export to CSV or JSON from the LOG tab.

**Phone sync:** the desktop is the master copy. Phones pull and push over the bridge. Deleting a flight on a phone while offline can bring it back on the next sync (a known gap).

---

## 13. Checklists

Checklists are in [`lib/data/checklist_data.dart`] and follow the Concorde manual's procedures. Speeds from the planner appear inside the steps (V1, VR, V2 on take-off; VREF and VAPP on landing). The Flight Monitor can highlight the phase you're in.

---

## 14. Privacy and networks

| Network call | Purpose |
|---|---|
| metar.vatsim.net, aviationweather.gov, tgftp.nws.noaa.gov | Weather |
| raw.githubusercontent.com (OurAirports CSVs) | Airport data |
| www.simbrief.com | Flight plan import |
| api.github.com | Update check |
| visitorbadge.io | Launch counter |
| Google AdMob and UMP | Ads and consent (Android) |
| Your LAN only | Phone to desktop telemetry |

The full policy is at `public/privacy/index.html`. If a new network call is added, update that page.

---

## 15. Known limitations and open questions

- **Estimates:** the 155 t no-reheat gate, the 1.35 no-reheat factor, the wet and contaminated factors, the 30 kt crosswind and 10 kt tailwind limits, and the landing runway base are not in the DC Designs manual.
- **No wind** in trip time or fuel.
- **Single-engine and abnormal cases** are not modelled.
- **Code comment mismatch (for developers):** the comment on `takeoffFeasibleM` in `lib/core/concorde_logic.dart` still says the base was "anchored at 3,597 m", but the constant used is 2,743 m. The number used is the one in this document. The comment should be fixed.

---

## 16. Where to change things

| To change | Edit |
|---|---|
| Fuel flows, weights, runway base, speed references | `lib/core/concorde_constants.dart` |
| Fuel, speed and runway math | `lib/core/concorde_logic.dart` |
| Distance and route math | `lib/core/route_math.dart` |
| Live phase, fuel prediction, CG | `lib/core/live_flight_math.dart`, `lib/features/flight_monitor/presentation/controllers/live_nav_provider.dart` |
| Alerts | `lib/features/flight_monitor/presentation/controllers/live_alerts_provider.dart` |
| Checklist text | `lib/data/checklist_data.dart` |
| Weather parsing | `lib/core/metar_parser.dart` |
| Data sources | `lib/services/` |

When you change a number, update this document and [`AGENTS.md`](../AGENTS.md) in the same change, and keep `flutter test` passing (especially the golden test).
