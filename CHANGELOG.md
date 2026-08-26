# Changelog

All notable changes to this project will be documented in this file.

## v3.4.26 (2026-08-26)

### Added
- feat: add GitHub Sponsors links and unify card contrast styling
- feat: build MSFS-pasteable route string with dep/arr runways

### Fixed
- fix: stop tracking generated build artifacts breaking CI changelog push and v3.4.26
- fix: stop tracking generated build artifacts breaking CI changelog push
- fix: treat narrow runway width as a caution, not a hard reject
- fix: remove extra trim fuel entry and add final reserve to fuel calculator

### Other Changes
- v3.4.25
- refactor: remove flight log/recording feature from Flight Monitor
- style: polish flight planner layout and spacing
- Update FUNDING.yml with sponsorship options
- refactor: extract shared TopArcBorder card style and refresh app shell theming
- refactor: rework performance calculator cards and runway/wind indicator
- style: add consistent site nav to changelog and donate pages
- style: tighten ICAO/runway field widths and color the METAR strip by flight category
- chore: upgrade Flutter SDK and bump pub dependencies
- style: add community banner to downloads page

## beta-3.4.15-build45 (2026-08-24)

### Added
- feat: add runway width, crosswind, and airfield altitude limits sourced from BA Concorde Flying Manual
- feat(flight-monitor): rework hero row layout, drop redundant gear/flaps card
- feat: add screenshot showcase carousel to landing page
- feat: watch for MSFS process to auto-restart telemetry bridge & add discord invite

### Fixed
- fix: guarantee landing capture even when tracking starts mid-flight
- fix: align checklist with manual's actual procedures, add landing phase
- fix: Scrolling in checklist was broken
- fix: move airport DB cache off Documents on Windows
- fix: eagerly snap default cruise FL to known flight direction

### Other Changes
- ci: add Discord webhook notification for beta pre-releases
- style: redesign downloads page with side-by-side stable/beta and collapsed history
- chore: remove dead public assets and unused ez-github-scripts config
- ci: rename release/beta installers to ConcordeEFB_vX.Y.Z(- beta_buildNN).exe
- test: add coverage for fuel schematic, providers, runway feasibility, airport DB
- docs: refresh AGENTS.md/working.md for Flutter codebase, dedupe README changelog
- docs: add Discord link to website nav and footer
- chore: remove disclaimer from the bottom of planner and monitor pages

## beta-3.4.4-build2 (2026-08-21)

### Fixed
- fix: surface SimConnect bridge launch failures in Flight Monitor UI

## beta-3.4.3-build1 (2026-08-20)

### Added
- feat: wire real app icon, polish Windows uninstaller metadata
- feat(theme): refine cruise components to EfbFlatCard shadow style, wire window title bar background, and refine LIFR palette
- feat(theme): Phase 5 retheme flight monitor tab and delete fm_theme.dart
- feat(theme): Phase 4 retheme checklists tab
- feat(theme): Phase 3 retheme flight planner tab with bold Material cards
- feat(theme): Phase 2 app shell retheme and remove AmbientGlow
- feat(theme): Phase 1 retheme shared widgets and add theme toggle
- feat(theme): Phase 0 theme system foundation
- feat: replace raster fuel diagram with real vector schematic, live per- tank fill
- feat: wire fuel schematic to real per-tank MSFS telemetry
- feat: rebuild flight monitor tab with real fuel schematic
- feat: rebuild Flight Monitor tab from new design, real 13-tank fuel schematic
- feat: add a proper landing page for the official Concorde EFB website

### Fixed
- fix(ui): seamlessly merge folder tab with card body without gap or misaligned curvature
- fix(ui): unify _LegCard background with EFB calculator and ensure smooth non-chopped rounded corners
- fix(ui): wrap Performance Calculator in EfbCard with cleanly styled inner leg modules
- fix(theme): eliminate nested card-in-card wrapper and restore clean light mode palette hierarchy
- fix: match title bar tint to app theme on macOS
- fix: auto-select longest runway on ICAO change, fix dropdown crash
- fix: recalibrate fuel burn model to real Concorde performance data
- fix: save flight logs next to the install folder, not Documents, on Windows
- fix: correct checklist data and unify triplicated fuel/FL logic; refactor: split flight_planner_tab.dart into flight_planner/ sections

### Other Changes
- style: fix borders in performance calculator
- style: bigger runway and wind indicator now
- style(ui): new light / dark ui. dropped glass ui and stuff
- style(theme): update accent to deep violet #651FFF
- style(ui): pop amber folder tab above card without top card background bleed
- style(ui): render card title as a popping folder tab
- style(ui): render card flightstrip as compact bold flat accent with white text
- style(ui): unify entire card background to solid colors.surface
- style(ui): render card title on attached colored flightstrip header
- style(ui): rename navigation tabs to PLANNER, CHECKLISTS, and MONITOR
- style(theme): adjust light mode canvas background to refined dark charcoal gray #1E212B
- style(theme): deepen card surface to #D0D7E6 for enhanced contrast
- style(theme): set slate card surface with white inner controls for high contrast
- style(theme): set dark absolute app background in light mode with crisp header contrast
- style(theme): separate dark card surface from crisp white inner input and panel containers
- style(theme): deepen light mode card surface to medium slate tone
- style(theme): darken light mode card surface and nested containers for stronger depth
- style(theme): deepen light mode background layers for better card contrast
- style(ui): match Performance Calculator card header to other flight planner cards
- chore(theme): Phase 6 delete ui_tokens.dart, efb_glass_container.dart, and finalize dead code removal
- style(ui): rework perf calc card, now shows when takeoff possible without reheat
- style(ui): rework Cruise and fuel management card
- refactor: move nav tabs into header row, drop header stats
- ci: add on-demand Beta-Build workflow for test releases
- ci: consolidate release pipeline into a single Release-Build workflow
- refactor: simplify fuel schematic card to single-line legend, no overlays
- ci: rebuild GitHub Pages deploy as isolated changelog+donate pipeline
- chore: update scripts again

## test-1 (2026-07-16)

### Added
- feat: bundle SimConnect bridge into app and fix telemetry bugs
- feat: add ez-github-scripts
- feat(animations): anchor global header statically and assign value keys to force tab transition playbacks
- feat(animations): extend entrance fader slide duration and double staggered delays for a more deliberate cascade
- feat(animations): apply staggered entrance delays to separate layout widgets
- feat(animations): integrate EntranceFader staggered slide and fade-in animations on tab loads
- feat(windows): programmatically force Impeller rendering engine at Win32 startup
- feat(changelog): merge github releases directly into the timeline
- feat: add changelog link integration and update entries for Release v3.2.0
- feat: added Flight Monitor tab via simconnect
- feat: add reheat toggle for take off
- feat: auto update notifications
- feat: added checklist for the concorde
- feat: set default launch window size and cleanup
- feat: complete Flutter port of Concorde EFB UI and logic
- feat: METAR corrected RW perf calcs & implement concorde climb cruise profile

### Fixed
- fix flight monitor tab and add .mds for agents
- fix(changelog): restrict official release tag to dynamic api releases only
- fix download options on the external page
- fix: download update button
- fix: complete final UI, font, and layout polishing
- fix: restore side-by-side performance cards and verify ICAO inputs
- fix: fuel endurance now dynamically calculates fuel endurance as per burn rate
- Fixed Fuel Endurance calculation logic

### Other Changes
- chore: fix workflow
- ci: fix broken Windows build pipeline in GitHub Actions
- update dependancies
- refactor: split files so its easier to maintain the codebase
- code fixes & airport db is now local so app works offline as well
- perf(scrolling): configure BouncingScrollPhysics and fix Windows terminate exit delay
- perf(telemetry): isolate dial gauges with RepaintBoundary for 240Hz buttery UI performance
- refine changelog page to identify official releases
- Modify changelog entry titles for clarity
- redesign changelog landing page
- rename model classes and stuff
- add monetization
- add monetag
- added donate and monetization scope for the app
- added auto changelog generator on github
- Update changelog with new Flight Monitor System entry
- ci: deploy static changelog files only when on flutter branch
- Delete src-tauri/gen/schemas directory
- chore: add build ignores to .gitignore, fix warnings, and adjust hover card styles
- METAR auto fetch and refresh options
- improved landing and take off performance calculations with real METAR info from airports
- added donate feature
- add uninstallation script
- creat git actions to build the app online
- remove old code and fix text field and update route logic
- refined the checklist more
- Loads of UI/UX, perf, logic and math changes
- chore: integrate bump-version npm package and bump app version
- update RW and wind display UI
- overhaul UI with glassmorphism
- add in a version tag for user in app
- Update the app with new fonts
- port EFB Launches counter to the new app
- layout fixes
- chore: clean up repo by ignoring build artifacts
- update to v2.1.0

## v2.1.0 (2025-12-29)

### Other Changes
- Rename site visits to EFB launches
- Prefer live METARs after SimBrief import / simbrief metar data not very reliable
- Update changelog for v2.0.2

## v2.0.2 (2025-12-28)

### Fixed
- Fix input focus and bump version to 2.0.2

### Other Changes
- Update build marker to 281225-2
- Merge beta into main
- Update Cargo lockfile
- Configure updater for production
- denote beta branch during testing
- Add Tauri updater and update notification
- update changelog

## v2.0.1 (2025-12-28)

### Added
- feat(metar): refine strips layout and chips
- feat(metar): show runway elevation in METAR strips

### Fixed
- fix(metar): correct runway wind arrow orientation
- Fix Donate link to honor base URL across pages

### Other Changes
- v2.0.1-RC10
- Merge branch 'beta' into main
- style(metrics): align ETE + Reserves card content
-  style(time): add spacing between values and unit suffixes
- change beta 10 to RC10 because release ready now
- Merge branch 'beta' into main
- update changelog and close beta 10
- New featuresimbrief): add in pax count
- start working on beta 10
- update to v2.0.1 build 281226-B9-Stable
- Merge beta into main
- update to beta9
- hangelog:seed script to regenerate entries.json
- seed raw changelog entries from git history
- Add GitHub Pages donate page and hook in-app link
- update build marker and footer links
- refine efb ui, metar visuals, and simbrief workflow

## v2.0.1-beta6 (2025-12-28)

### Added
- feat(simbrief): split callsign into callsign + aircraft registration in UI
- feat(simbrief): inject dep/arr runway tokens into imported route string (VIDP/27 … OMDB/30R)
- feat(simbrief): auto-fill DEP/ARR METAR on import to populate wind components

### Fixed
- fix(ci): dedupe pages workflow and stabilize main/beta gh-pages deploy

### Other Changes
- v2.0.1 build: 281225-0126
- Merge branch 'main' of github.com:dwaipayanray95/Concorde-EFB
- Merge beta into main
- Add light mode and improve light UI contrast
- Bump build marker
- Improve light-mode contrast
- added and fixed light UI mode, added a toggle too
- Initial commit: working towards a light UI
- Merge pull ui-rework/v1: Brand new UI and loads of new features
-  Add diagnostics details toggle and update utility actions
- remove Reheat:OK panel instead add a safety line with warning logic
-  Polish cruise timing row and enforce landing limits
- update ui for T/O and LDG perf panels
- Introduce Performance Calculator
- added glow to certain ui elements & cleanup bg
- First rebuild at UI
- change local host for web testing
- Merge new features from feature/simbrief-import
- center the texts in the middle of the boxes
- add a call sign and arcft rgstrn box and gave them some colours
- split call sign and registration into two units
- starting work on newer
- Merge beta changes for v1.1.2 from build 2612251804
- pre-release v1.1.2 2612251804
- changing deployment method #1 - cleaning main tree
- try not to delete beta builds while deploying

## v1.1.2 (2025-12-26)

### Fixed
- fix(ts): remove .tsx extensions from imports (CI typecheck)
- fix deploying beta builds online for testing
- Fix planned-distance recalculation + decouple SimBrief estimated distance
- fix(route): prevent manual planned distance edits from overwriting imported/estimated route distance; improve SimBrief status labels
- fix(ui): bundle header app icon for GitHub Pages

### Other Changes
- changing deployment method #2 - update pages.yml
- changing deployment method #1 - cleaning beta tree
- ci(beta): use npm install to avoid lockfile drift breaking deploy
- update version to v1.1.2 and added build numbering
- push version to v1.1.1
- Update build number to track beta instead of globally
- chore(ui): remove Auto-FL debug panel and disable FL debug mode
- removed useless .js causing conflicts and added auto FL calculation from simbrief
- auto-calculating FL logic
- tried fixing app-icon not showing in web version
- added app icon in app

## v1.1 (2025-12-26)

### Added
- FEATURE: implemented support to import data from simbrief
- feat(simbrief): auto-fill alternate ICAO on import
- feat(route): add optional fixes DB + safer SimBrief token parsing to improve distance estimates
- feat(route): add route paste + distance estimate that auto-fills planned distance (still editable)

### Fixed
- fix(ui): match route box height to estimated distance card
- fix(dev): remove duplicate default export shims in App.js
- fix(route): move route card above dep/arr without touching legacy JS files
- fixing jsx compiling errors
- fix(route): disambiguate duplicate navaids, move route card to top, simplify UI
- fix(build): restore valid package.json + repair vite config for beta build

### Other Changes
- cleanup beta versioning and update version numbering to v1.1 (v1.1.0)
- merge(beta): bring SimBrief import + route UI into main
- Merge pull request #1 from dwaipayanray95/feature/simbrief-import
- cleaned up the route box and deleted non required informations
- inital commit: working branch to import simbrief data
- chore: ignore tauri/target and other build artifacts
- make sure app is building via .tsx and not older .js
- Commit message: fix(route): move Route card inside ConcordePlannerCanvas to resolve TS undefined names
- add beta tag to the beta page
- trying to fix beta build errors
- update pages again
- update pages.yml for beta staging
- update pages.yml to accomodate beta deployment
- updates pages.yml to accomodate for beta testing app
- update pages.yml for beta branch
- update pages.yml to not delete beta
- Test signing keys
- Test commit
- deploy beta branch
- Update GitHub Pages workflow for main and beta branches
- chore(ci): deploy main and beta to GitHub Pages

## v1.0.0 (2025-12-26)

### Fixed
- fix(tauri): repair tauri.conf.json (valid JSON + MSI config)
- fix(tauri): fix invalid tauri.conf.json (msi-only + v1.0.0)
- Fix app not showing up once launched
- fix(build): add tailwind deps for CI build
- Fix tauri build errors
- fix building via tauri
- fix(tauri): repair package.json JSON + add tauri scripts

### Other Changes
- build only .msi instead of .exe as well
- lock installation path so that the app is always installed at the same place
- update version to 1.0.0 in concordeefb.js
- Add new app icon  - wohoo
- chore(release): bump to v1.0.0 and update app/window title
- Commit message: fix(build): unify scripts; make npm run build tauri-safe
- Commit message: fix(tauri): use relative Vite base for desktop to prevent white screen
- chore(rc): fix tauri v2 config + sync deps/lockfile for CI builds
- chore: sync package-lock with package.json
- chore(rc): migrate tauri config to v2 + set unique identifier
- tracking windows releases as RC until stable
- chore(tauri): add windows release workflow
- update pages.yml for beta staging
- update yages.yml to accomodate for beta testing
- Add GitHub Actions workflow for stable deployment
- chore(issues): rename issue template; remove auto-label workflow
- bug and feature update page automation update
- Unified features and bug requests
- cleanup the feature request form a bit
- Part 1: Add external user to request features (for flightsim.to)

## v0.85 (2025-12-25)

### Added
- feat(v0.85): auto FL recommendation + non-RVSM FL validation + fix runway dropdown selection
- feat(v0.84): infer east/west direction and validate non-RVSM cruise FLs
- feat: initial Concorde EFB working locally
- feat: wire Tailwind and scaffold Concorde EFB

### Fixed
- fix(ui): make auto-selected Non-RVSM notice green + rename counter label to SITE VISITS
- fix(counter): replace CountAPI opens counter with visitorbadge SVG badge (no CORS)
- fix(tests): make altitudeBurnFactor heuristic stable (FL450≈1.20, FL600≈1.00) while keeping UI FL limits
- fix(fl): make FL editable, allow <300, enforce Non-RVSM snapping, auto-pick compliant default FL
- fix: another attempt at clamping FL590 and reflecting updated versioning number
- fix: clamp cruise FL to max FL590 + show clamp notice; ensure auto-FL respects max
- Fix: Attempt 3/'
- fix: trying deploying in a different manner
- Fix: Another Attempt #2
- fix: rewrote a few things hope it works
- fix: another attempt
- fix: trying to make this deployable via github
- fix(ci): silence TS in EFB, add papaparse module decl, restore Vite config
- fix: restore proper Vite config and base path
- fix: set Vite base to /Concorde-EFB/ and update remote

### Other Changes
- remove goatcounter script
- trying add CountAPI to count the number of users using the EFB.
- Hygiene fixes and updated the readme with changelog and future plan
- Updated the correct file for v0.85 changes to reflect
- chore(release): bump app version to v0.83 — update header, index.html, README, and built JS
- chore: fix runway selection, add fuel capacity warning, and retune Concorde landing speeds
- Update README with try link and author social media
- Updated to v0.82 overall fixes here and there
- 0.81 now its online added a ReadME and a few text additions in the app
- ci: build with vite (skip tsc) to unblock Pages
- Add GitHub Actions workflow for GitHub Pages deployment

