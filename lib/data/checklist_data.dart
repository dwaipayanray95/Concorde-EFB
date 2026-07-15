import '../models/checklist_item.dart';

class ChecklistPhase {
  final String id;
  final String name;
  const ChecklistPhase({required this.id, required this.name});
}

const List<ChecklistPhase> checklistPhases = [
  ChecklistPhase(id: 'cold_dark', name: 'Cold & Dark Setup'),
  ChecklistPhase(id: 'before_start', name: 'Before Start & Engine Start'),
  ChecklistPhase(id: 'before_takeoff', name: 'Before Takeoff & Taxi'),
  ChecklistPhase(id: 'after_takeoff', name: 'After Takeoff'),
  ChecklistPhase(id: 'cruise_accel', name: 'Cruise & Supersonic Accel'),
  ChecklistPhase(id: 'descent', name: 'Deceleration & Descent'),
  ChecklistPhase(id: 'approach', name: 'Approach'),
];

/// Builds the per-phase checklist item lists. [vSpeedsStr] and [vappStr] are
/// derived from live SimBrief/performance data, so this can't be a plain
/// const map — the FMC steps need to show the actual V-speeds once known.
Map<String, List<ChecklistItem>> buildChecklistData({
  required String vSpeedsStr,
  required String vappStr,
}) {
  return {
    'cold_dark': [
      ChecklistItem(id: 'cd_bat', item: 'Battery Switch', status: 'SPLIT A & B'),
      ChecklistItem(id: 'cd_gnd_pwr', item: 'Ground Power', status: 'ON', note: 'Ground power is highly important for system alignment!'),
      ChecklistItem(id: 'cd_crossfeed', item: 'Fuel Cross Feed Valves', status: 'ON (ALL 4 ENGINES)'),
      ChecklistItem(id: 'cd_bleed', item: 'Engine Bleed Valves', status: 'AUTO'),
      ChecklistItem(id: 'cd_heater', item: 'Engine Heater', status: 'AUTO'),
      ChecklistItem(id: 'cd_visor', item: 'Nose Visor', status: 'DOWN'),
      ChecklistItem(id: 'cd_lights', item: 'Lights & Seatbelts', status: 'ON'),
      ChecklistItem(id: 'cd_antistall', item: 'Anti-Stall Switches', status: 'ON'),
      ChecklistItem(id: 'cd_trim', item: 'Pitch Trim', status: 'CENTER (0.0)', note: 'Normalizes pitch response'),
      ChecklistItem(id: 'cd_fmc', item: 'FMC / Route', status: 'SET DEP/ARR, FLIGHT NO, CRUISE FL, SPEED to 250, & INITIAL ALT', note: 'Refer to manual or import via SimBrief'),
      ChecklistItem(id: 'cd_pos_init', item: 'FMC POS Init', status: 'Main Menu ➔ Set POS'),
      ChecklistItem(id: 'cd_v_speeds', item: 'FMC V-Speeds', status: 'Perf Page ➔ SET $vSpeedsStr'),
    ],
    'before_start': [
      ChecklistItem(id: 'bs_beacon', item: 'Beacon Lights', status: 'ON'),
      ChecklistItem(id: 'bs_pumps', item: 'Fuel Pumps', status: 'ON'),
      ChecklistItem(id: 'bs_eng_start', item: 'Engine Start Selectors', status: 'START', note: 'Standard Concorde Sequence: 3, 4, 2, 1 or 3, 2, 1, 4'),
      ChecklistItem(id: 'bs_throttle', item: 'Throttle Levers', status: 'IDLE'),
      ChecklistItem(id: 'bs_csd_on', item: 'CSD Generators 1-4', status: 'ON', note: 'Engage once engines are stabilized'),
      ChecklistItem(id: 'bs_gnd_pwr_off', item: 'Ground Power', status: 'OFF / DISCONNECT'),
    ],
    'before_takeoff': [
      ChecklistItem(id: 'bt_controls', item: 'Flight Controls', status: 'CHECKED'),
      ChecklistItem(id: 'bt_visor', item: 'Nose Visor', status: '5° (TAXI/TAKEOFF)'),
      ChecklistItem(id: 'bt_reheat', item: 'Reheat Selectors', status: 'ARMED'),
      ChecklistItem(id: 'bt_lights', item: 'Landing Lights', status: 'AS REQUIRED'),
      ChecklistItem(id: 'bt_speed_arm', item: 'Speed Arming', status: 'Select IAS ACQ Button'),
      ChecklistItem(id: 'bt_ap_at_off', item: 'Autopilot / Autothrottle', status: 'DISENGAGED'),
    ],
    'after_takeoff': [
      ChecklistItem(id: 'at_gear', item: 'Landing Gear', status: 'UP'),
      ChecklistItem(id: 'at_autothrottle', item: 'Autothrottle', status: 'ON'),
      ChecklistItem(id: 'at_reheat_off', item: 'Reheats (Afterburners)', status: 'OFF'),
      ChecklistItem(id: 'at_visor', item: 'Nose Visor', status: 'UP'),
    ],
    'cruise_accel': [
      ChecklistItem(id: 'ca_reheat', item: 'Reheats (Afterburners)', status: 'ENGAGE (1 & 4, then 2 & 3)', note: 'Cap at 25 min'),
      ChecklistItem(id: 'ca_cg', item: 'Fuel Transfer (CG Management)', status: 'PUMP AFT (Tanks 9 & 11)', note: 'Target 59% MAC at Mach 2.0'),
      ChecklistItem(id: 'ca_ap', item: 'Autopilot / Max Climb', status: 'ENGAGED'),
    ],
    'descent': [
      ChecklistItem(id: 'de_reheat', item: 'Reheats', status: 'OFF'),
      ChecklistItem(id: 'de_throttle', item: 'Throttles', status: 'SET SPEED & SELECT IAS ACQ (or IDLE / RETRACT)'),
      ChecklistItem(id: 'de_cg', item: 'Fuel Transfer (CG Management)', status: 'PUMP FORWARD', note: 'Target 53% MAC before landfall'),
    ],
    'approach': [
      ChecklistItem(id: 'ap_speed', item: 'Approach Speed', status: 'SET $vappStr'),
      ChecklistItem(id: 'ap_visor', item: 'Nose Visor', status: 'DOWN (17.5°)', note: 'Move to 5° or 17.5° depending on speed/glideslope'),
      ChecklistItem(id: 'ap_gear', item: 'Landing Gear', status: 'DOWN', note: 'Extend below 270 KIAS'),
    ],
  };
}
