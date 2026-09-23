import 'package:flutter/material.dart';
import '../../widgets/entrance_fader.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../widgets/app_footer.dart';
import 'flight_planner/flight_plan_section.dart';
import 'flight_planner/cruise_fuel_section.dart';
import 'flight_planner/performance_calculator_section.dart';

/// Flight Planner tab: sub-segmented between [ROUTE & FUEL] and [PERFORMANCE & SPEEDS]
/// for optimal landscape tablet display without overwhelming vertical scrolling.
class FlightPlannerTab extends StatefulWidget {
  const FlightPlannerTab({super.key});

  @override
  State<FlightPlannerTab> createState() => _FlightPlannerTabState();
}

class _FlightPlannerTabState extends State<FlightPlannerTab> {
  int _activeSubTab = 0; // 0: Route & Fuel, 1: Performance & Speeds

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Authentic Cockpit MFD Bezel Segmented Softkey Strip
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 38,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: isDark ? 0.6 : 0.8),
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSubTabButton(
                context,
                index: 0,
                label: 'ROUTE & FUEL PLANNING',
                icon: Icons.alt_route,
              ),
              Container(
                width: 1,
                height: 24,
                color: colors.dividerStrong.withValues(alpha: isDark ? 0.4 : 0.6),
              ),
              _buildSubTabButton(
                context,
                index: 1,
                label: 'PERFORMANCE & SPEEDS',
                icon: Icons.speed,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

        // Sub-tab content
        if (_activeSubTab == 0) ...[
          EntranceFader(
            key: const ValueKey('subtab-route-fuel'),
            delay: const Duration(milliseconds: 60),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlightPlanSection(),
                SizedBox(height: 20),
                CruiseAndFuelSection(),
                SizedBox(height: 20),
                AppFooter(),
              ],
            ),
          ),
        ] else ...[
          EntranceFader(
            key: const ValueKey('subtab-perf-speeds'),
            delay: const Duration(milliseconds: 60),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PerformanceCalculatorSection(),
                SizedBox(height: 20),
                AppFooter(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubTabButton(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
  }) {
    final colors = context.colors;
    final isSelected = _activeSubTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _activeSubTab = index),
        hoverColor: colors.resultsBg.withValues(alpha: 0.4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          color: isSelected
              ? (isDark ? const Color(0xFF222227) : const Color(0xFFFFFFFF))
              : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected ? colors.accent : colors.textDim,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: uiText(
                      context,
                      size: 10.5,
                      weight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Precision Amber Active Indicator Line
              Container(
                height: 2.0,
                width: isSelected ? 24.0 : 0.0,
                decoration: BoxDecoration(
                  color: isSelected ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
