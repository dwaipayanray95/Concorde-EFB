# Working Context - Concorde EFB (Flutter Migration)

This file tracks the active tasks, architecture, and current state of the Concorde EFB project for development agents.

## 1. Project Overview & Current State
The project is a **Flutter-based rewrite/migration** of the Concorde Electronic Flight Bag (EFB), originally built in React/TypeScript with Tauri.
* **Platform Support**: Supports Web (GitHub Pages), Desktop (Windows/macOS/Linux via Flutter window manager), and Mobile (Android/iOS with AdMob integration).
* **Active Branch**: `flutter`
* **Current Core files**:
  * [lib/main.dart](file:///E:/VSCODE/Concorde-EFB/lib/main.dart) - Application entry point. Sets up the window manager, AdMob, theme, and wraps the app in a Riverpod `ProviderScope`.
  * [lib/core/ui_tokens.dart](file:///E:/VSCODE/Concorde-EFB/lib/core/ui_tokens.dart) - Custom UI styling constants (colors, margins, shapes).
  * [lib/screens/home_screen.dart](file:///E:/VSCODE/Concorde-EFB/lib/screens/home_screen.dart) - Main dashboard layout.
  * [lib/services/](file:///E:/VSCODE/Concorde-EFB/lib/services/) - Contains APIs for SimBrief import, METAR data fetches, etc.
  * [lib/features/flight_monitor/](file:///E:/VSCODE/Concorde-EFB/lib/features/flight_monitor/) - SimConnect flight monitor including a real-time CG envelope widget (`CgEnvelopeWidget`).

## 2. Recent Actions & Commits
* Ran `git reset --hard origin/flutter` and `git pull` to synchronize with upstream commits.
* Resolved upstream dependencies (`fl_chart` / packaging configurations).
* Fixed warning issues in [lib/providers/efb_providers.dart](file:///E:/VSCODE/Concorde-EFB/lib/providers/efb_providers.dart) related to redundant null checks on non-nullable `runway.heading`.
* Reduced the hover border opacity and glow shadow spread/blur in [lib/widgets/efb_glass_container.dart](file:///E:/VSCODE/Concorde-EFB/lib/widgets/efb_glass_container.dart) to make hover highlight on cards subtle.
* Confirmed that `flutter analyze` runs with **No issues found!**
* Fixed a large commit push failure by resetting the local commit, adding `node_modules/` and `src-tauri/target/` build files to [.gitignore](file:///E:/VSCODE/Concorde-EFB/.gitignore), and pushed a clean, light commit successfully.

## 3. Immediate Next Steps
* Monitor the integration of the flight monitor features with MSFS SimConnect.
* Continue styling and verifying page-by-page parity with original React/Tauri functionality.
* Run tests to verify logic models and fuel/performance estimations.

## 4. Key Rules
* Always refer to the original React version constraints (`src/ConcordeEFB.tsx`) and rule constraints in [AGENTS.md](file:///E:/VSCODE/Concorde-EFB/AGENTS.md).
* Keep this `working.md` file updated right before ending a quota/turn so subsequent agents can seamlessly pick up.
