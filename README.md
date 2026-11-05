# Concorde EFB

An Electronic Flight Bag (EFB) for the DC Designs Concorde in Microsoft Flight Simulator 2020 and 2024. It helps you plan a flight (route, fuel, weights, runways, speeds), follow checklists, and watch live telemetry from the sim.

The app is an **indicative planning tool**, not certified data. Always check numbers against the DC Designs manual and in the sim.

Made by [@theawesomeray](https://instagram.com/theawesomeray). I'm a flight enthusiast, not a professional programmer, so the documentation tries to explain things in plain language. If something is unclear, that's a documentation bug, so please say so.

---

## What it does

| Area | What you get |
|---|---|
| **Flight plan** | Departure, arrival and alternate airports; runway pick; route distance; cruise flight level (FL); call sign, registration, passengers |
| **Import** | SimBrief OFP (by username), and `.pln`, vPilot `.vfp` and route XML files |
| **Fuel** | Trip, taxi, contingency, alternate, final reserve and extra fuel; block fuel; endurance check |
| **Weights** | Zero fuel, ramp, take-off and landing weight, checked against limits |
| **Performance** | Take-off and landing runway need, with weather corrections; V1 / VR / V2 and VREF / VAPP speeds |
| **Weather** | Live METAR for departure and arrival (wind, QNH, temperature, visibility, flight category) |
| **Dispatch banner** | One GO / CAUTION / NO-GO summary of every planner check |
| **Checklists** | Interactive checklists from Cold & Dark through Shutdown, with your V-speeds shown where needed |
| **Flight Monitor** | Live telemetry from MSFS: engines, fuel, CG, attitude, speeds, gear, alerts, and an MFD strip with predicted fuel at destination |
| **Logbook** | Automatic flight log (block times, track, touchdown rating), with notes and export. Desktop is the master copy and phones sync from it over Wi-Fi |
| **Phones and tablets** | Android app (internal beta test) can show Flight Monitor by connecting over Wi-Fi to the desktop app |

For where every number comes from and which assumptions it relies on, read **[docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md)**.

---

## Getting started

### Desktop (Windows, primary)
1. Download the latest installer from the [Releases page](https://github.com/dwaipayanray95/Concorde-EFB/releases) and run it. The installer replaces the previous version and keeps your settings.
2. Start the app. Planning works straight away (it needs internet for airport data and weather).
3. For Flight Monitor, start MSFS and open the **MONITOR** tab. The app launches its bundled SimConnect bridge automatically. See [Troubleshooting](#troubleshooting).

### Phones and tablets (Android)
1. Join the Android beta using the links in Settings or the Monitor tab's invite prompt.
2. Flight Monitor needs the **desktop app running on the sim PC**, on the same Wi-Fi as your phone. Turn on *Share over Wi-Fi* in the desktop app, then pick the bridge on the phone (or type the IP and the 6-digit pairing code).

---

## Using the planner

1. **Airports**: enter departure (DEP), arrival (ARR) and alternate (ALT) ICAO codes, e.g. `EGLL`, `KJFK`, `KBOS`.
2. **Runways**: the app picks a sensible runway automatically from the current wind (no tailwind first, then a manageable crosswind, then the longest). You can override it. A SimBrief import sets runways for you.
3. **Route**: a SimBrief import fills in the route distance, flight level and alternate. Otherwise type the planned distance in nautical miles (NM). The app picks a cruise level for you when the distance changes.
4. **Fuel**: check taxi, contingency %, final reserve and any extra fuel. *Reset fuel* restores the defaults.
5. **Weather**: METARs refresh every 10 minutes. If the weather service can't be reached you'll see **OFFLINE**; press retry.
6. **Reheat**: the *takeoff reheat* switch shows how a dry (no afterburner) takeoff changes the runway and weight picture.
7. **Dispatch banner**: GO means every check passed. CAUTION means something needs a look (for example, no alternate). NO-GO means a hard limit is broken.
8. **Checklists**: follow the phases in order. Speeds from the planner appear in the relevant steps.

---

## Limitations (read this)

- **Indicative numbers.** Fuel burn, climb, descent and runway figures come from simple models calibrated to published Concorde figures and the DC Designs manual. They're not certified data and don't account for every sim setting, weather or ATC routing.
- **Some limits are estimates.** The thrust-lapse exponent in the runway density correction, the wet and contaminated runway factors and the 30 kt crosswind limit are not in the DC Designs manual. They're marked as estimates in [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md).
- **No wind in the trip fuel.** Trip fuel and time assume still air. Use your SimBrief figures for real-world wind.
- **Flight Monitor needs the sim PC.** Phones can't talk to MSFS directly; they get data from the desktop bridge.
- **Internet needed for some features.** Airport data is downloaded once and cached; METARs and SimBrief import always need internet.

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| Monitor shows no data, or the bridge fails to start | The bridge is `msfs_bridge.exe`, which is unsigned, so antivirus or SmartScreen can block it. Allow it. Windows may ask you to allow `msfs_bridge` on Private networks; say yes. The bridge log is at `%LOCALAPPDATA%\ConcordeEFB\simbridge.log`. |
| Bridge is up but there's no telemetry | MSFS may not be running, or no flight is loaded yet. SimConnect only sends data once a flight is loaded. |
| Phone can't find the desktop | Same Wi-Fi network? Firewall allowing the app on Private networks? Some Android devices block the discovery broadcast; typing the desktop's IP address works regardless. |
| Phone says **Pairing code rejected by the PC** | Wrong 6-digit code. Check the code shown on the desktop's Wi-Fi card. |
| Weather shows **OFFLINE** | The METAR sources can't be reached (VATSIM, aviationweather.gov, NOAA). Check your internet and retry. |
| Airport not found | The ICAO may be mistyped, or the airport may be missing from the OurAirports database. |

---

## For developers

Flutter (Dart) app for Windows (primary), macOS, Android and a static website. Start with:

- [AGENTS.md](AGENTS.md): the project handoff for coding agents (file map, rules, timeline)
- [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md): data sources and calculation assumptions
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md): UI conventions
- [docs/WINDOWS_SIGNING.md](docs/WINDOWS_SIGNING.md), [docs/ANDROID_SIGNING.md](docs/ANDROID_SIGNING.md), [docs/PLAY_STORE.md](docs/PLAY_STORE.md): release and store setup

Common commands:

```bash
flutter pub get        # install packages
flutter analyze        # must stay clean
flutter test           # run tests (includes the LHR-JFK golden fuel test)
flutter run -d windows # run the desktop app
```

Tech stack: Flutter, Riverpod (state), SharedPreferences (settings), Inno Setup (Windows installer), GitHub Actions (builds). The telemetry bridge is a Python script (`tools/simbridge/msfs_bridge.py`) packaged with PyInstaller.

---

## Support the project
- Patreon: [Support Ray on Patreon](https://www.patreon.com/c/theawesomeray)
- UPI: scan the QR code in the desktop support banner.

## License
Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Copyright 2026 Dwaipayan Narayan Ray.

## Disclaimer
Not affiliated with DC Designs, Microsoft, Just Flight, or any data provider. Planning values are indicative and must be validated in the sim.

## Changelog
See the [in-app/web changelog](public/changelog/index.html) (source: `public/changelog/entries.json`).
