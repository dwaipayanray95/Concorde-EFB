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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-segment tab bar
        Row(
          children: [
            _buildSubTabButton(
              context,
              index: 0,
              label: 'ROUTE & FUEL PLANNING',
              icon: Icons.alt_route,
            ),
            const SizedBox(width: 12),
            _buildSubTabButton(
              context,
              index: 1,
              label: 'PERFORMANCE & SPEEDS',
              icon: Icons.speed,
            ),
          ],
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

    return InkWell(
      onTap: () => setState(() => _activeSubTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.16)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors.accent : colors.dividerStrong.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w900,
                color: isSelected ? colors.accent : colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
