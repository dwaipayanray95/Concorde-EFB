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
  ChecklistPhase(id: 'landing', name: 'Landing'),
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
      ChecklistItem(
        id: 'cd_bat',
        item: 'Battery Switch',
        status: 'SPLIT A & B',
      ),
      ChecklistItem(
        id: 'cd_parking_brake',
        item: 'Parking Brake Lever',
        status: 'SET',
      ),
      ChecklistItem(
        id: 'cd_gnd_pwr',
        item: 'Ground Power',
        status: 'ON',
        note:
            'Ground power is highly important for system alignment! (manual step 1 of engine start)',
      ),
      ChecklistItem(id: 'cd_heater', item: 'Engine Heater', status: 'AUTO'),
      ChecklistItem(id: 'cd_visor', item: 'Nose Visor', status: 'DOWN'),
      ChecklistItem(id: 'cd_lights', item: 'Lights & Seatbelts', status: 'ON'),
      ChecklistItem(
        id: 'cd_antistall',
        item: 'Anti-Stall Switches',
        status: 'ON',
      ),
      ChecklistItem(
        id: 'cd_trim',
        item: 'Pitch Trim',
        status: 'CENTER (0.0)',
        note: 'Normalizes pitch response',
      ),
      ChecklistItem(
        id: 'cd_fmc',
        item: 'FMC / Route',
        status:
            'SET DEP/ARR, FLIGHT NO, CRUISE FL, SPEED to 250, & INITIAL ALT',
        note: 'Refer to manual or import via SimBrief',
      ),
      ChecklistItem(
        id: 'cd_pos_init',
        item: 'FMC POS Init',
        status: 'Main Menu ➔ Set POS',
      ),
      ChecklistItem(
        id: 'cd_v_speeds',
        item: 'FMC V-Speeds',
        status: 'Perf Page ➔ SET $vSpeedsStr',
      ),
    ],
    // Engine-start sequence below follows the manual's own numbered
    // procedure ("Starting the Engines", engineer's station) exactly,
    // steps 2-8 -- step 1 (Ground Power ON) is covered in Cold & Dark above.
    'before_start': [
      ChecklistItem(id: 'bs_beacon', item: 'Beacon Lights', status: 'ON'),
      ChecklistItem(
        id: 'bs_battery_esp',
        item: 'Battery ESP Switches',
        status: 'BOTH ON',
      ),
      ChecklistItem(
        id: 'bs_epu',
        item: 'EPU Switch',
        status: 'ON',
        note: 'Look for the blue "Selected" light to illuminate',
      ),
      ChecklistItem(
        id: 'bs_bleed_air',
        item: 'Bleed Air Switches',
        status: 'ALL ON',
      ),
      ChecklistItem(
        id: 'bs_lp_valves',
        item: 'Low Pressure Valves',
        status: 'ON (OPEN)',
        note: 'Red covers lowered',
      ),
      ChecklistItem(
        id: 'bs_jettison_crossfeed',
        item: 'Jettison Cross-feed Knobs',
        status: 'IN-LINE',
        note: 'Black knobs with grey top and white lines',
      ),
      ChecklistItem(
        id: 'bs_pumps',
        item: 'Engine Feed Pumps',
        status: 'ALL ON',
      ),
      ChecklistItem(
        id: 'bs_eng_start',
        item: 'Engine Re-Light Switches',
        status: 'ON, ONE AT A TIME',
        note:
            'Community-standard sim sequence: 3, 4, 2, 1 (individual engine order not specified by the manual)',
      ),
      ChecklistItem(
        id: 'bs_monitor',
        item: 'Engine Temps & Pressures',
        status: 'MONITOR DURING START',
      ),
      ChecklistItem(id: 'bs_throttle', item: 'Throttle Levers', status: 'IDLE'),
      ChecklistItem(
        id: 'bs_csd_on',
        item: 'CSD Generators 1-4',
        status: 'ON',
        note: 'Engage once engines are stabilized',
      ),
      ChecklistItem(
        id: 'bs_gnd_pwr_off',
        item: 'Ground Power',
        status: 'OFF / DISCONNECT',
      ),
    ],
    'before_takeoff': [
      ChecklistItem(
        id: 'bt_controls',
        item: 'Flight Controls',
        status: 'CHECKED',
      ),
      ChecklistItem(
        id: 'bt_visor',
        item: 'Nose Visor',
        status: '5° (TAXI/TAKEOFF)',
      ),
      ChecklistItem(id: 'bt_reheat', item: 'Reheat Selectors', status: 'ARMED'),
      ChecklistItem(
        id: 'bt_lights',
        item: 'Landing Lights',
        status: 'AS REQUIRED',
      ),
      ChecklistItem(
        id: 'bt_speed_arm',
        item: 'Speed Arming',
        status: 'Select IAS ACQ Button',
      ),
      ChecklistItem(
        id: 'bt_ap_at_off',
        item: 'Autopilot / Autothrottle',
        status: 'DISENGAGED',
      ),
      ChecklistItem(
        id: 'bt_throttle_check',
        item: 'Throttles (Line-Up)',
        status: 'ADVANCE TO N2 80%',
        note:
            'Check temperatures and pressures before advancing to takeoff power',
      ),
      ChecklistItem(
        id: 'bt_parking_brake',
        item: 'Parking Brake',
        status: 'RELEASE',
        note:
            'Release before advancing throttles to max power/reheat for the takeoff roll',
      ),
    ],
    'after_takeoff': [
      ChecklistItem(id: 'at_gear', item: 'Landing Gear', status: 'UP'),
      ChecklistItem(id: 'at_autothrottle', item: 'Autothrottle', status: 'ON'),
      ChecklistItem(
        id: 'at_reheat_off',
        item: 'Reheats (Afterburners)',
        status: 'OFF',
      ),
      ChecklistItem(id: 'at_visor', item: 'Nose Visor', status: 'UP'),
    ],
    'cruise_accel': [
      ChecklistItem(
        id: 'ca_reheat',
        item: 'Reheats (Afterburners)',
        status: 'ENGAGE (1 & 4, then 2 & 3)',
        note: 'Cap at 25 min',
      ),
      ChecklistItem(
        id: 'ca_cg',
        item: 'Fuel Transfer (CG Management)',
        status: 'PUMP AFT (Tanks 9 & 11)',
        note: 'Target 59% MAC at Mach 2.0',
      ),
      ChecklistItem(
        id: 'ca_ap',
        item: 'Autopilot / Max Climb',
        status: 'ENGAGED',
      ),
    ],
    'descent': [
      ChecklistItem(
        id: 'de_nav',
        item: 'NAV / ILS Setup',
        status: 'SET DEST ILS, THEN VOR/DME FREQ',
        note: 'At Time of Descent, ~600 NM / ~200 NM from destination',
      ),
      ChecklistItem(id: 'de_reheat', item: 'Reheats', status: 'OFF'),
      ChecklistItem(
        id: 'de_mach',
        item: 'AFCS Mach',
        status: 'REDUCE TO 1.5',
        note:
            'Descend ~2,000 fpm toward FL360; watch CoG trim through the high-drag envelope',
      ),
      ChecklistItem(
        id: 'de_throttle',
        item: 'Throttles',
        status: 'RETARD AT M1.5 (~350 KIAS), IDLE AT FL360',
        note: 'Descent rate increases to 4,000-8,000 fpm as configured',
      ),
      ChecklistItem(
        id: 'de_subsonic',
        item: 'Airspeed',
        status: 'SUBSONIC (M0.95) BY FL300, THEN 250 KT AT FL100',
        note: 'Recheck fuel balance is sufficient to reach destination',
      ),
      ChecklistItem(
        id: 'de_cg',
        item: 'Fuel Transfer (CG Management)',
        status: 'PUMP FORWARD',
        note: 'Target 54% MAC before landfall',
      ),
    ],
    'approach': [
      ChecklistItem(
        id: 'ap_speed',
        item: 'Approach Speed',
        status: 'SET $vappStr',
      ),
      ChecklistItem(
        id: 'ap_visor',
        item: 'Nose Visor',
        status: 'DOWN (12.5°)',
        note: 'Move to 5° or 12.5° depending on speed/glideslope',
      ),
      ChecklistItem(
        id: 'ap_gear',
        item: 'Landing Gear',
        status: 'DOWN',
        note:
            'Extend below 270 KIAS / M0.7 (BA Concorde Flying Manual Vol II, 01.01.02)',
      ),
    ],
    'landing': [
      ChecklistItem(
        id: 'ld_autoland',
        item: 'Autoland',
        status: 'SELECT LAND (AFCS)',
        note: 'At 200 KIAS; maintain aft-biased CG similar to takeoff',
      ),
      ChecklistItem(
        id: 'ld_autothrottle',
        item: 'Autothrottle',
        status: 'DISENGAGE BELOW 2,000 FT',
        note: 'Hold ~85% N2, ~12° nose-up, ~500 fpm descent',
      ),
      ChecklistItem(
        id: 'ld_autopilot',
        item: 'Autopilot',
        status: 'DISENGAGE AT 250 FT RADALT',
        note: 'Manual control for the flare',
      ),
      ChecklistItem(
        id: 'ld_flare',
        item: 'Flare',
        status: 'CLOSE THROTTLES ~30 FT',
        note:
            'Ease back to counter ground effect "float"; forward stick may be needed to set the nosewheel down',
      ),
      ChecklistItem(
        id: 'ld_reverse',
        item: 'Reverse Thrust',
        status: 'ENGAGE AT NOSEWHEEL TOUCHDOWN',
        note: 'Max dry power in reverse buckets, combined with wheel brakes',
      ),
      ChecklistItem(
        id: 'ld_parking_brake',
        item: 'Parking Brake Lever',
        status: 'SET',
        note:
            'Once clear of the runway. The manual does not detail a full engine/systems shutdown sequence beyond this -- its own in-sim checklist covers that, which this app cannot read',
      ),
    ],
  };
}
