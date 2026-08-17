import 'package:flutter/material.dart';
import '../../widgets/entrance_fader.dart';
import '../widgets/app_footer.dart';
import 'flight_planner/flight_plan_section.dart';
import 'flight_planner/cruise_fuel_section.dart';
import 'flight_planner/performance_calculator_section.dart';

/// Flight Planner tab: flight plan / SimBrief import, cruise & fuel
/// management, and the takeoff/landing performance calculator.
///
/// Split across lib/screens/tabs/flight_planner/ — see that folder for the
/// FLIGHT PLAN, CRUISE & FUEL MANAGEMENT, and PERFORMANCE CALCULATOR cards.
class FlightPlannerTab extends StatelessWidget {
  const FlightPlannerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntranceFader(
          key: const ValueKey('plan-row'),
          delay: const Duration(milliseconds: 100),
          child: const Column(
            children: [
              FlightPlanSection(),
              SizedBox(height: 32),
              CruiseAndFuelSection(),
            ],
          ),
        ),
        const SizedBox(height: 32),
        EntranceFader(
          key: const ValueKey('perf-section'),
          delay: const Duration(milliseconds: 220),
          child: const PerformanceCalculatorSection(),
        ),
        const SizedBox(height: 64),
        EntranceFader(
          key: const ValueKey('footer'),
          delay: const Duration(milliseconds: 340),
          child: const AppFooter(),
        ),
      ],
    );
  }
}
