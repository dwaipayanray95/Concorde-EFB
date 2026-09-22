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
| `bg` | Application canvas / root background | `#090C15` | `#EDF1F8` |
| `surface` | Card background & navigation rail | `#131926` | `#D0D7E6` |
| `resultsBg` | Inset data readout cards & inner panels | `#1B2232` | `#FFFFFF` |
| `inputBg` | Text fields & selectable controls | `#101420` | `#F2F5FC` |
| `textPrimary` | Primary headings, values, and gauges | `#F0F4FF` | `#0A0D18` |
| `textSecondary` | Subheadings, standard body text | `#CBD5E1` | `#2D3748` |
| `textDim` | Captions, unselected states, units | `#64748B` | `#64748B` |
| `divider` | Subtle card dividers and borders | `#2A354A` | `#CBD5E1` |
| `dividerStrong` | Outer card frames & active borders | `#384660` | `#94A3B8` |
| `accent` | Interactive links, focus rings, buttons | `#4F86F7` | `#2563EB` |
| `departure` | Departure airport highlights & VFR green | `#10B981` | `#059669` |
| `arrival` | Destination highlights & SimConnect green | `#38BDF8` | `#0284C7` |
| `error` / `errorBg` | IFR status, warnings, invalid runways | `#EF4444` | `#DC2626` |
| `mvfr` / `mvfrBg` | Marginal VFR & waiting status | `#3B82F6` | `#2563EB` |
| `lifr` / `lifrBg` | Low IFR status | `#D946EF` | `#C026D3` |

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
