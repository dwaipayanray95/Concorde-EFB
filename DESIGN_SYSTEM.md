# Concorde EFB — Design System Contract

> **Scope**: Standard design tokens, typography, component rules, responsive guidelines, and accessibility (a11y) standards for Concorde EFB across Desktop (Windows/macOS) and Mobile (Android).

---

## 1. Design Philosophy & Aesthetic

Concorde EFB emulates a modern, high-contrast, flat aviation **Electronic Flight Bag (EFB)** and **ARINC 661-inspired cockpit display**.
- **Clarity over Flashiness**: High contrast and zero gratuitous blurs or heavy drop-shadows.
- **Tabular Data Parity**: All figures, instruments, and speeds align vertically without horizontal jitter when values rapidly change.
- **Strict Theme Extension**: All colors route dynamically through `context.colors` (`ThemeExtension<AppColors>`). Never hardcode `Color(0xFF...)` in UI widgets.

---

## 2. Color System (`AppColors`)

Defined in [`lib/core/app_colors.dart`](file:///e:/VSCODE/Concorde-EFB/lib/core/app_colors.dart). Accessible via `context.colors`.

| Token | Semantic Purpose | Dark Value | Light Value |
| :--- | :--- | :--- | :--- |
| `bg` | Application canvas / root background | `#101012` | `#F4F4F5` |
| `surface` | Card background & navigation rail | `#18181B` | `#E4E4E7` |
| `resultsBg` | Inset data readout cards & inner panels | `#202024` | `#FFFFFF` |
| `inputBg` | Text fields & selectable controls | `#141416` | `#FAFAFA` |
| `textPrimary` | Primary headings, values, and gauges | `#FAFAFA` | `#18181B` |
| `textSecondary` | Subheadings, standard body text | `#A1A1AA` | `#52525B` |
| `textDim` | Captions, unselected states, units | `#71717A` | `#71717A` |
| `divider` | Subtle card dividers and borders | `#27272A` | `#E4E4E7` |
| `dividerStrong` | Outer card frames & active borders | `#3F3F46` | `#D4D4D8` |
| `accent` | Signature Aviation Amber lead | `#F59E0B` | `#D97706` |
| `cardAccent` | Signature Aviation Amber lead header | `#F59E0B` | `#D97706` |
| `departure` | Departure highlights & VFR green | `#10B981` | `#059669` |
| `arrival` | Destination & Enroute Amber target | `#F59E0B` | `#D97706` |
| `error` / `errorBg` | Master Warning Red, invalid runways | `#EF4444` | `#DC2626` |
| `mvfr` / `mvfrBg` | Master Caution Amber, marginal weather | `#F59E0B` | `#D97706` |
| `lifr` / `lifrBg` | Low IFR status | `#E879F9` | `#C026D3` |

---

## 3. Spacing & Radius Tokens

Defined in [`lib/core/app_spacing.dart`](file:///e:/VSCODE/Concorde-EFB/lib/core/app_spacing.dart). Standard 4px / 8px baseline rhythm.

### Spacing Tokens
- `AppSpacing.xxs` = `2.0`
- `AppSpacing.xs`  = `4.0`
- `AppSpacing.sm`  = `8.0`
- `AppSpacing.md`  = `12.0`
- `AppSpacing.lg`  = `16.0`
- `AppSpacing.xl`  = `20.0`
- `AppSpacing.xxl` = `24.0`

### Corner Radii
- `AppRadii.xs` = `4.0` (Tags, chips)
- `AppRadii.sm` = `6.0` (Small buttons, input pills)
- `AppRadii.md` = `8.0` (Standard buttons, sub-panels)
- `AppRadii.lg` = `10.0` (Cards, dialogs)
- `AppRadii.xl` = `12.0` (Root cards)

---

## 4. Typography Scale (`AppTypography`)

Defined in [`lib/core/ui_text.dart`](file:///e:/VSCODE/Concorde-EFB/lib/core/ui_text.dart).
The entire app standardizes on **JetBrains Mono** to guarantee tabular number alignment.

| Role | Method | Size | Weight | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Display** | `AppTypography.display(context, ...)` | `20px` | Bold (`w700`) | Modal titles, primary page headers |
| **Section Header** | `AppTypography.sectionHeader(context, ...)` | `14px` | Semibold (`w600`) | Card titles (`FLIGHT PLAN`, `PERFORMANCE`) |
| **Readout** | `AppTypography.readout(context, ...)` | `13px` | Bold (`w700`) | V1/VR/V2 speeds, fuel totals, live Zulu clock |
| **Body** | `AppTypography.body(context, ...)` | `12px` | Regular (`w400`) | Route strings, checklist steps, form labels |
| **Caption** | `AppTypography.caption(context, ...)` | `10px` | Semibold (`w600`) | Status badges, unit labels (`KG`, `NM`, `KT`) |

---

## 5. Layout & Breakpoints

- **Desktop / Tablet Landscape (`>= 720px`)**:
  - Displays the full **Vertical Navigation Rail** ([`EfbNavRail`](file:///e:/VSCODE/Concorde-EFB/lib/widgets/efb_nav_rail.dart)) on the left.
  - Cockpit Status Bar spans the top of the main viewport.
- **Mobile Compact (`< 720px`)**:
  - Navigation rail collapses into a standard bottom `NavigationBar`.
  - Cockpit Status Bar scrolls horizontally with momentum to ensure callsign, route, SimConnect status, and Zulu clock remain accessible without clipping.
  - Screen padding scales down from `20px` to `12px` to maximize usable screen real estate.

---

## 6. Accessibility (a11y) & Mobile Safeguards

1. **Text Scaling Clamping**:
   - OS-level dynamic font scaling is clamped in `MaterialApp.builder`:
     `mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.25);`
   - Prevents fixed cockpit gauge blowouts and `RenderFlex` overflow errors when users have large system text enabled on Android.
2. **Semantics Annotation**:
   - Status indicators (e.g. `SIM LIVE`, Zulu clock, Route pills) must provide `Semantics(label: ...)` descriptions for screen readers.
3. **Touch Targets**:
   - Interactive buttons and navigation items must maintain at least `44×44 dp` touch target bounds on mobile form factors.
