use super::BridgeState;
use chrono::Utc;
use simconnect::{SimConnect, SimConnectRecv};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const RETRY_DELAY: Duration = Duration::from_secs(2);
const KG_PER_LB: f64 = 0.453_592_37;

#[allow(clippy::too_many_arguments)]
#[derive(Default, Clone, Copy)]
struct DataFrame {
  altitude_ft: f64,
  ias_kt: f64,
  gs_kt: f64,
  mach: f64,
  vs_fpm: f64,
  on_ground: f64,
  eng1_on: f64,
  eng2_on: f64,
  eng3_on: f64,
  eng4_on: f64,
  fuel_total_lb: f64,
  weight_lb: f64,
  flightplan_total_nm: f64,
  flightplan_remaining_nm: f64,
}

#[derive(Default, Clone)]
struct StateCache {
  last_on_ground: bool,
  takeoff_roll_time_utc: Option<String>,
  fuel_start_kg: Option<f64>,
}

pub fn spawn(state: Arc<Mutex<BridgeState>>) {
  thread::spawn(move || loop {
    if let Err(err) = run_simconnect_loop(state.clone()) {
      eprintln!("SimConnect error: {err}");
      thread::sleep(RETRY_DELAY);
    }
  });
}

fn run_simconnect_loop(state: Arc<Mutex<BridgeState>>) -> anyhow::Result<()> {
  let mut sim = SimConnect::new("Concorde EFB Bridge")?;

  sim.add_to_data_definition(0, "PLANE ALTITUDE", "Feet")?;
  sim.add_to_data_definition(0, "AIRSPEED INDICATED", "Knots")?;
  sim.add_to_data_definition(0, "GROUND VELOCITY", "Knots")?;
  sim.add_to_data_definition(0, "AIRSPEED MACH", "Mach")?;
  sim.add_to_data_definition(0, "VERTICAL SPEED", "Feet per minute")?;
  sim.add_to_data_definition(0, "SIM ON GROUND", "Bool")?;
  sim.add_to_data_definition(0, "GENERAL ENG COMBUSTION:1", "Bool")?;
  sim.add_to_data_definition(0, "GENERAL ENG COMBUSTION:2", "Bool")?;
  sim.add_to_data_definition(0, "GENERAL ENG COMBUSTION:3", "Bool")?;
  sim.add_to_data_definition(0, "GENERAL ENG COMBUSTION:4", "Bool")?;
  sim.add_to_data_definition(0, "FUEL TOTAL QUANTITY WEIGHT", "Pounds")?;
  sim.add_to_data_definition(0, "TOTAL WEIGHT", "Pounds")?;
  sim.add_to_data_definition(0, "GPS FLIGHT PLAN TOTAL DISTANCE", "Nautical miles")?;
  sim.add_to_data_definition(0, "GPS FLIGHT PLAN DISTANCE", "Nautical miles")?;

  sim.request_data_on_sim_object(0, 0, 0, 0)?;

  let mut cache = StateCache::default();
  let mut last_dispatch = Instant::now();

  loop {
    match sim.get_next_dispatch()? {
      SimConnectRecv::SimObjectData(data) => {
        let frame: DataFrame = data.into();
        last_dispatch = Instant::now();
        update_snapshot(&state, &mut cache, frame);
      }
      _ => {
        if last_dispatch.elapsed() > Duration::from_secs(2) {
          sim.request_data_on_sim_object(0, 0, 0, 0)?;
          last_dispatch = Instant::now();
        }
        thread::sleep(Duration::from_millis(20));
      }
    }
  }
}

fn update_snapshot(state: &Arc<Mutex<BridgeState>>, cache: &mut StateCache, frame: DataFrame) {
  let on_ground = frame.on_ground > 0.5;
  let engines_on = frame.eng1_on > 0.5 || frame.eng2_on > 0.5 || frame.eng3_on > 0.5 || frame.eng4_on > 0.5;
  let fuel_total_kg = frame.fuel_total_lb * KG_PER_LB;
  let weight_kg = frame.weight_lb * KG_PER_LB;

  if engines_on && cache.fuel_start_kg.is_none() {
    cache.fuel_start_kg = Some(fuel_total_kg);
  }

  let fuel_burn_kg = cache
    .fuel_start_kg
    .map(|start| (start - fuel_total_kg).max(0.0));

  if cache.last_on_ground && !on_ground {
    // Liftoff clears any prior touchdown data.
    if let Ok(mut guard) = state.lock() {
      guard.snapshot.touchdown_fpm = None;
    }
  }

  if !cache.last_on_ground && on_ground {
    if let Ok(mut guard) = state.lock() {
      guard.snapshot.touchdown_fpm = Some(frame.vs_fpm);
    }
  }

  if on_ground && frame.gs_kt > 35.0 && cache.takeoff_roll_time_utc.is_none() {
    cache.takeoff_roll_time_utc = Some(Utc::now().format("%H:%MZ").to_string());
  }

  let phase = if !engines_on {
    "Waiting"
  } else if on_ground && frame.gs_kt < 5.0 {
    "Engine Start"
  } else if on_ground && frame.gs_kt < 35.0 {
    "Taxiing"
  } else if on_ground {
    "Takeoff Roll"
  } else if frame.altitude_ft < 10_000.0 && frame.vs_fpm > 500.0 {
    "Climb"
  } else if frame.vs_fpm < -500.0 {
    "Descent"
  } else {
    "Cruising"
  };

  cache.last_on_ground = on_ground;

  if let Ok(mut guard) = state.lock() {
    guard.snapshot.altitude_ft = Some(frame.altitude_ft);
    guard.snapshot.ias_kt = Some(frame.ias_kt);
    guard.snapshot.gs_kt = Some(frame.gs_kt);
    guard.snapshot.mach = Some(frame.mach);
    guard.snapshot.vs_fpm = Some(frame.vs_fpm);
    guard.snapshot.fuel_total_kg = Some(fuel_total_kg);
    guard.snapshot.fuel_burn_kg = fuel_burn_kg;
    guard.snapshot.weight_kg = Some(weight_kg);
    guard.snapshot.flightplan_total_nm = Some(frame.flightplan_total_nm);
    guard.snapshot.flightplan_remaining_nm = Some(frame.flightplan_remaining_nm);
    guard.snapshot.phase = Some(phase.to_string());
    guard.snapshot.takeoff_roll_time_utc = cache.takeoff_roll_time_utc.clone();
  }
}
