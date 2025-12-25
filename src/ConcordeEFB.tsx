// Concorde EFB — Canvas v0.7 (for DC Designs, MSFS 2024)
// What’s new in v0.7
// • Manual distance input (NM) — users paste planner distance; no auto route math for accuracy.
// • Alternate ICAO → ARR→ALT distance & alternate fuel added into Block.
// • Trim Tank Fuel (kg) added; **Total Fuel Required = Block + Trim**.
// • Landing feasibility added (arrival) + departure feasibility — now display **reasons** when NOT feasible (required vs available, deficit).
// • METAR fetch more robust: tries AviationWeather API, then VATSIM fallback.
// • All units metric (kg, m); longest-runway autopick; crosswind/headwind components.
// • Self-tests cover manual-distance sanity, fuel monotonicity, feasibility sanity.
import React, { useEffect, useMemo, useState } from "react";
import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
} from "react";
import Papa from "papaparse";

const APP_VERSION = "0.85-beta";

// Public, no-auth “opens” counter via an SVG badge.
// The badge request itself increments the counter, so every app open updates it.
// (This is intentionally simple and works on GitHub Pages without CORS issues.)
const OPENS_COUNTER_PATH = "https://dwaipayanray95.github.io/Concorde-EFB/";
const OPENS_BADGE_SRC =
  "https://api.visitorbadge.io/api/visitors" +
  `?path=${encodeURIComponent(OPENS_COUNTER_PATH)}` +
  "&label=SITE%20VISITS" +
  "&labelColor=%23111a2b" +
  "&countColor=%230ea5e9" +
  "&style=flat" +
  "&labelStyle=upper";

// User should be able to enter FL below 300 (e.g. low-level segments), but Concorde max is still capped.
const MIN_CONCORDE_FL = 0;
const MAX_CONCORDE_FL = 590;

// Non-RVSM flight levels for Concorde above FL410 (user-provided rule-of-thumb)
const NON_RVSM_MIN_FL = 410;

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function clampCruiseFL(input: number): number {
  const v = Number.isFinite(input) ? input : 0;
  // Allow entry below 300 by clamping only to [0..MAX]
  return clampNumber(Math.round(v), MIN_CONCORDE_FL, MAX_CONCORDE_FL);
}

type DirectionEW = "E" | "W";

function initialBearingDeg(lat1: number, lon1: number, lat2: number, lon2: number): number {
  // https://www.movable-type.co.uk/scripts/latlong.html (standard formula)
  const φ1 = toRad(lat1);
  const φ2 = toRad(lat2);
  const Δλ = toRad(lon2 - lon1);
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  const θ = Math.atan2(y, x);
  // Normalize to [0..360)
  return (θ * 180) / Math.PI >= 0 ? ((θ * 180) / Math.PI) % 360 : (((θ * 180) / Math.PI) % 360) + 360;
}

function inferDirectionEW(dep: AirportInfo | undefined, arr: AirportInfo | undefined): DirectionEW | null {
  if (!dep || !arr) return null;
  const brg = initialBearingDeg(dep.lat, dep.lon, arr.lat, arr.lon);
  // Eastbound roughly 000-179, Westbound 180-359
  return brg < 180 ? "E" : "W";
}

function nonRvsmValidFLs(direction: DirectionEW): number[] {
  // Pattern provided by user:
  // East: 410, 450, 490, 530, 570
  // West: 430, 470, 510, 550, 590
  const start = direction === "E" ? 410 : 430;
  const levels: number[] = [];
  for (let fl = start; fl <= MAX_CONCORDE_FL; fl += 40) levels.push(fl);
  return levels;
}

function snapToNonRvsm(fl: number, direction: DirectionEW): { snapped: number; changed: boolean } {
  if (!Number.isFinite(fl)) return { snapped: NON_RVSM_MIN_FL, changed: true };
  const clamped = clampCruiseFL(fl);
  if (clamped < NON_RVSM_MIN_FL) return { snapped: clamped, changed: clamped !== fl };

  const valid = nonRvsmValidFLs(direction);
  if (valid.includes(clamped)) return { snapped: clamped, changed: clamped !== fl };

  // Snap to nearest valid level
  let best = valid[0];
  let bestDiff = Math.abs(valid[0] - clamped);
  for (const v of valid) {
    const d = Math.abs(v - clamped);
    if (d < bestDiff) {
      best = v;
      bestDiff = d;
    }
  }
  return { snapped: best, changed: true };
}

function recommendedCruiseFL(direction: DirectionEW): number {
  // Keep the app’s original intent (high cruise) but make it compliant.
  const target = 580;
  const { snapped } = snapToNonRvsm(target, direction);
  return snapped;
}

type RunwayInfo = {
  id: string;
  heading: number;
  length_m: number;
};

type AirportInfo = {
  name: string;
  lat: number;
  lon: number;
  runways: RunwayInfo[];
};

type AirportIndex = Record<string, AirportInfo>;

type NavaidInfo = {
  ident: string;
  lat: number;
  lon: number;
  type: string;
  name: string;
};

type NavaidIndex = Record<string, NavaidInfo>;

type RoutePoint = {
  label: string;
  lat: number;
  lon: number;
};

type RouteResolution = {
  points: RoutePoint[];
  recognized: {
    procedures: string[];
    airways: string[];
    unresolved: string[];
  };
};

type MetarParse = {
  wind_dir_deg: number | null;
  wind_speed_kt: number | null;
  wind_gust_kt: number | null;
};

type MetarFetchSuccess = {
  ok: true;
  raw: string;
  source: string;
};

type MetarFetchFailure = {
  ok: false;
  error: string;
};

type MetarFetchResult = MetarFetchSuccess | MetarFetchFailure;

type ProfileSegment = {
  time_h: number;
  dist_nm: number;
};

type BlockFuelInputs = {
  tripKg: number;
  taxiKg: number;
  contingencyPct: number;
  finalReserveKg: number;
  alternateNM: number;
  burnKgPerNm: number;
};

type BlockFuelBreakdown = {
  trip_kg: number;
  taxi_kg: number;
  contingency_kg: number;
  final_reserve_kg: number;
  alternate_kg: number;
  block_kg: number;
};

type ReheatSummary = {
  requested_min: number;
  cap_min: number;
  within_cap: boolean;
};

type RunwayFeasibility = {
  required_length_m_est: number;
  runway_length_m: number;
  feasible: boolean;
};

type WindComponentSummary = {
  headwind_kt: number | null;
  crosswind_kt: number | null;
};

type TakeoffSpeeds = {
  V1: number;
  VR: number;
  V2: number;
};

type LandingSpeeds = {
  VLS: number;
  VAPP: number;
};

type SelfTestResult = {
  name: string;
  pass: boolean;
  err?: string;
  value?: unknown;
  values?: Record<string, unknown>;
};

const toRad = (deg: number): number => (deg * Math.PI) / 180;
const nmFromKm = (km: number): number => km * 0.539957;
const ftToM = (ft: number | string | null | undefined): number => {
  const value =
    typeof ft === "number"
      ? ft
      : parseFloat((ft ?? "").toString().trim() || "0");
  return value * 0.3048;
};

function greatCircleNM(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R_km = 6371.0088;
  const phi1 = toRad(lat1),
    phi2 = toRad(lat2);
  const dphi = toRad(lat2 - lat1);
  const dlambda = toRad(lon2 - lon1);
  const a =
    Math.sin(dphi / 2) ** 2 +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlambda / 2) ** 2;
  return nmFromKm(2 * R_km * Math.asin(Math.sqrt(a)));
}

const CONSTANTS = {
  weights: {
    mtow_kg: 185066,
    mlw_kg: 111130,
    fuel_capacity_kg: 95681,
    oew_kg: 78700,
    pax_full_count: 100,
    pax_mass_kg: 95,
  },
  speeds: { cruise_mach: 2.04, cruise_tas_kt: 1164 },
  fuel: {
    burn_kg_per_nm: 24.45,
    climb_factor: 1.7,
    descent_factor: 0.5,
    reheat_minutes_cap: 25,
  },
  runway: {
    min_takeoff_m_at_mtow: Math.round(11800 * 0.3048),
    min_landing_m_at_mlw: 2200,
  },
} as const;

function altitudeBurnFactor(cruiseFL: number): number {
  // This factor is a *heuristic* for how fuel burn improves with higher cruise levels.
  // Keep it stable for the self-test expectations (FL450 ≈ 1.20, FL600 ≈ 1.00),
  // while still allowing the UI to clamp Concorde's actual cruise ceiling elsewhere.

  const input = Number.isFinite(cruiseFL) ? cruiseFL : 580;

  // For the heuristic model, clamp to a sensible range so low/invalid FLs don't explode,
  // and tests that probe FL600 remain meaningful.
  const fl = Math.max(300, Math.min(650, input));

  const x = (fl - 450) / (600 - 450);
  return 1.2 - 0.2 * Math.max(0, Math.min(1, x));
}
function cruiseTimeHours(
  distanceNM: number,
  tasKT: number = CONSTANTS.speeds.cruise_tas_kt
): number {
  if (tasKT <= 0) throw new Error("TAS must be positive");
  return distanceNM / tasKT;
}
function estimateClimb(
  cruiseAltFt: number,
  avgFpm: number = 2500,
  avgGSkt: number = 450
): ProfileSegment {
  const tH = Math.max(cruiseAltFt, 0) / Math.max(avgFpm, 100) / 60;
  const dNM = tH * Math.max(avgGSkt, 200);
  return { time_h: tH, dist_nm: dNM };
}
function estimateDescent(
  cruiseAltFt: number,
  avgGSkt: number = 420,
  bufferNM: number = 30
): ProfileSegment {
  const dRule = Math.max(cruiseAltFt, 0) / 300;
  const dist = dRule + bufferNM;
  const tH = dist / Math.max(avgGSkt, 200);
  return { time_h: tH, dist_nm: dist };
}
function blockFuelKg({
  tripKg,
  taxiKg,
  contingencyPct,
  finalReserveKg,
  alternateNM,
  burnKgPerNm,
}: BlockFuelInputs): BlockFuelBreakdown {
  const burn = burnKgPerNm ?? CONSTANTS.fuel.burn_kg_per_nm;
  const altKg = Math.max(alternateNM ?? 0, 0) * burn;
  const contKg = tripKg * Math.max(Number(contingencyPct || 0) / 100, 0);
  const total =
    tripKg + (taxiKg || 0) + contKg + (finalReserveKg || 0) + altKg;
  return {
    trip_kg: tripKg,
    taxi_kg: taxiKg || 0,
    contingency_kg: contKg,
    final_reserve_kg: finalReserveKg || 0,
    alternate_kg: altKg,
    block_kg: total,
  };
}
function reheatGuard(climbTimeHours: number): ReheatSummary {
  const requestedMin = Math.round(climbTimeHours * 60);
  const cap = CONSTANTS.fuel.reheat_minutes_cap;
  return {
    requested_min: requestedMin,
    cap_min: cap,
    within_cap: requestedMin <= cap,
  };
}
function takeoffFeasibleM(
  runwayLengthM: number,
  takeoffWeightKg: number
): RunwayFeasibility {
  const mtow = CONSTANTS.weights.mtow_kg;
  const baseReq = CONSTANTS.runway.min_takeoff_m_at_mtow;
  const ratio = Math.max(Math.min(takeoffWeightKg / mtow, 1.2), 0.5);
  const required = baseReq * ratio;
  return {
    required_length_m_est: required,
    runway_length_m: runwayLengthM,
    feasible: runwayLengthM >= required,
  };
}
function landingFeasibleM(
  runwayLengthM: number,
  landingWeightKg: number
): RunwayFeasibility {
  const mlw = CONSTANTS.weights.mlw_kg;
  const baseReq = CONSTANTS.runway.min_landing_m_at_mlw;
  const ratio = Math.max(Math.min((landingWeightKg || mlw) / mlw, 1.3), 0.6);
  const required = baseReq * Math.pow(ratio, 1.15);
  return {
    required_length_m_est: required,
    runway_length_m: runwayLengthM,
    feasible: runwayLengthM >= required,
  };
}

function parseMetarWind(raw: string): MetarParse {
  const re = new RegExp("(VRB|\\d{3})(\\d{2})(G(\\d{2}))?KT");
  const m = raw.match(re);
  if (!m)
    return { wind_dir_deg: null, wind_speed_kt: null, wind_gust_kt: null };
  const dirToken = m[1],
    spd = parseInt(m[2], 10),
    gst = m[4] ? parseInt(m[4], 10) : null;
  const dirDeg = dirToken === "VRB" ? null : parseInt(dirToken, 10);
  return { wind_dir_deg: dirDeg, wind_speed_kt: spd, wind_gust_kt: gst };
}
function windComponents(
  windDirDeg: number | null,
  windSpeedKt: number | null,
  runwayHeadingDeg: number
): WindComponentSummary {
  if (windDirDeg == null || windSpeedKt == null)
    return { headwind_kt: null, crosswind_kt: null };
  const theta = (((windDirDeg - runwayHeadingDeg) % 360) + 360) % 360;
  const rad = toRad(theta);
  const head = windSpeedKt * Math.cos(rad);
  const cross = Math.abs(windSpeedKt * Math.sin(rad));
  return {
    headwind_kt: Math.round(head * 10) / 10,
    crosswind_kt: Math.round(cross * 10) / 10,
  };
}
async function fetchMetarByICAO(icao: string): Promise<MetarFetchResult> {
  const primary = `https://aviationweather.gov/api/data/metar?ids=${icao}&format=raw`;
  const fallback = `https://metar.vatsim.net/${icao}`;
  try {
    const r = await fetch(primary, { mode: "cors" });
    const text = await r.text();
    const rawLine = (text.split(/\r?\n/)[0] || "").trim();
    if (rawLine) return { ok: true, raw: rawLine, source: "aviationweather" };
  } catch {
    // Ignore and fall back
  }
  try {
    const r2 = await fetch(fallback, { mode: "cors" });
    const t2 = await r2.text();
    const line = (t2.split(/\r?\n/)[0] || "").trim();
    if (line) return { ok: true, raw: line, source: "vatsim" };
    return { ok: false, error: `No METAR text returned for ${icao}` };
  } catch (e2) {
    return { ok: false, error: `METAR fetch failed for ${icao}: ${String(e2)}` };
  }
}

const AIRPORTS_CSV_URL =
  "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv";
const RUNWAYS_CSV_URL =
  "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv";
const NAVAIDS_CSV_URL =
  "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv";
type AirportCsvRow = {
  ident?: string;
  latitude_deg?: string;
  longitude_deg?: string;
  name?: string;
};

type RunwayCsvRow = {
  airport_ident?: string;
  length_m?: string;
  length_ft?: string;
  le_ident?: string;
  he_ident?: string;
  le_heading_degT?: string;
  he_heading_degT?: string;
};

type NavaidCsvRow = {
  ident?: string;
  latitude_deg?: string;
  longitude_deg?: string;
  type?: string;
  name?: string;
};

function buildWorldAirportDB(
  airportsCsvText: string,
  runwaysCsvText: string
): AirportIndex {
  const airportsRows = Papa.parse<AirportCsvRow>(airportsCsvText, {
    header: true,
    skipEmptyLines: true,
  }).data;
  const runwaysRows = Papa.parse<RunwayCsvRow>(runwaysCsvText, {
    header: true,
    skipEmptyLines: true,
  }).data;

  const airportsMap: AirportIndex = {};
  for (const a of airportsRows) {
    const ident = (a?.ident || "").trim().toUpperCase();
    if (!ident || ident.length !== 4) continue;
    const lat = parseFloat(a?.latitude_deg ?? "");
    const lon = parseFloat(a?.longitude_deg ?? "");
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    airportsMap[ident] = airportsMap[ident] || {
      name: a?.name || ident,
      lat,
      lon,
      runways: [],
    };
  }
  for (const r of runwaysRows) {
    const airportIdent = (r?.airport_ident || "").trim().toUpperCase();
    const airport = airportsMap[airportIdent];
    if (!airport) continue;
    const lengthMValue = r?.length_m ? Number(r.length_m) : Number.NaN;
    const parsedLength =
      Number.isFinite(lengthMValue) && lengthMValue > 0
        ? lengthMValue
        : ftToM(r?.length_ft ?? null);
    const lengthM =
      Number.isFinite(parsedLength) && parsedLength > 0 ? Math.round(parsedLength) : 0;
    const leIdent = (r?.le_ident || "").trim().toUpperCase();
    const heIdent = (r?.he_ident || "").trim().toUpperCase();
    const leHdg = Number(r?.le_heading_degT);
    const heHdg = Number(r?.he_heading_degT);
    if (leIdent)
      airport.runways.push({
        id: leIdent,
        heading: Math.round(Number.isFinite(leHdg) ? leHdg : 0),
        length_m: lengthM,
      });
    if (heIdent)
      airport.runways.push({
        id: heIdent,
        heading: Math.round(Number.isFinite(heHdg) ? heHdg : 0),
        length_m: lengthM,
      });
  }
  return airportsMap;
}

function buildNavaidsDB(navaidsCsvText: string): NavaidIndex {
  const rows = Papa.parse<NavaidCsvRow>(navaidsCsvText, {
    header: true,
    skipEmptyLines: true,
  }).data;

  const navaids: NavaidIndex = {};

  for (const r of rows) {
    const ident = (r?.ident || "").trim().toUpperCase();
    if (!ident) continue;

    const lat = parseFloat(r?.latitude_deg ?? "");
    const lon = parseFloat(r?.longitude_deg ?? "");
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;

    // OurAirports has duplicates for some idents; keep the first one we see.
    if (navaids[ident]) continue;

    navaids[ident] = {
      ident,
      lat,
      lon,
      type: (r?.type || "NAVAID").toString(),
      name: (r?.name || ident).toString(),
    };
  }

  return navaids;
}

const LATLON_RE = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const AIRWAY_RE = /^[A-Z]{1,2}\d{1,3}$/;
const PROCEDURE_RE = /^(DCT|SID[A-Z0-9-]*|STAR[A-Z0-9-]*|VIA|VECTOR)$/;

function parseRouteString(str: string): string[] {
  if (!str) return [];
  return str
    .split(/\s+/)
    .map((s) => s.trim().toUpperCase())
    .filter(Boolean);
}
function resolveRouteTokens(
  tokens: string[],
  airportsIndex: AirportIndex,
  navaidsIndex: NavaidIndex
): RouteResolution {
  const points: RoutePoint[] = [];
  const recognized: RouteResolution["recognized"] = {
    procedures: [],
    airways: [],
    unresolved: [],
  };
  for (const t of tokens) {
    if (PROCEDURE_RE.test(t)) {
      recognized.procedures.push(t);
      continue;
    }
    if (AIRWAY_RE.test(t)) {
      recognized.airways.push(t);
      continue;
    }
    const latlon = LATLON_RE.exec(t);
    if (latlon) {
      points.push({
        label: t,
        lat: parseFloat(latlon[1]),
        lon: parseFloat(latlon[2]),
      });
      continue;
    }
    if (t.length === 4 && airportsIndex?.[t]) {
      const a = airportsIndex[t];
      points.push({ label: t, lat: a.lat, lon: a.lon });
      continue;
    }
    if (navaidsIndex?.[t]) {
      const n = navaidsIndex[t];
      points.push({ label: t, lat: n.lat, lon: n.lon });
      continue;
    }
    recognized.unresolved.push(t);
  }
  return { points, recognized };
}
function computeRouteDistanceNM(
  depInfo: AirportInfo,
  arrInfo: AirportInfo,
  routePoints: RoutePoint[]
): number {
  const seq: RoutePoint[] = [
    { lat: depInfo.lat, lon: depInfo.lon, label: "DEP" },
    ...routePoints,
    { lat: arrInfo.lat, lon: arrInfo.lon, label: "ARR" },
  ];
  let sum = 0;
  for (let i = 0; i < seq.length - 1; i += 1) {
    sum += greatCircleNM(seq[i].lat, seq[i].lon, seq[i + 1].lat, seq[i + 1].lon);
  }
  return sum;
}

function pickLongestRunway(runways: RunwayInfo[] | null | undefined): RunwayInfo | null {
  if (!runways || runways.length === 0) return null;
  return runways.reduce<RunwayInfo>(
    (best, r) => ((r.length_m || 0) > (best.length_m || 0) ? r : best),
    runways[0]
  );
}

type CardProps = {
  title: ReactNode;
  children: ReactNode;
  right?: ReactNode;
};

const Card = ({ title, children, right }: CardProps) => (
  <section className="bg-slate-900/70 border border-slate-700 rounded-2xl p-5 shadow-xl">
    <div className="flex items-center justify-between mb-3">
      <h2 className="text-xl font-semibold">{title}</h2>
      {right}
    </div>
    {children}
  </section>
);

type RowProps = {
  children: ReactNode;
  cols?: 2 | 3 | 4;
};

const Row = ({ children, cols = 2 }: RowProps) => (
  <div
    className={`grid gap-3 ${
      cols === 3 ? "grid-cols-3" : cols === 4 ? "grid-cols-4" : "grid-cols-2"
    }`}
  >
    {children}
  </div>
);

type LabelProps = {
  children: ReactNode;
};

const Label = ({ children }: LabelProps) => (
  <label className="text-xs text-slate-400 block mb-1">{children}</label>
);

type InputProps = InputHTMLAttributes<HTMLInputElement>;

const Input = ({ className, ...props }: InputProps) => (
  <input
    {...props}
    className={`w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${
      className ?? ""
    }`.trim()}
  />
);

type SelectProps = SelectHTMLAttributes<HTMLSelectElement>;

const Select = ({ className, ...props }: SelectProps) => (
  <select
    {...props}
    className={`w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${
      className ?? ""
    }`.trim()}
  />
);

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "ghost";
};

const Button = ({ children, variant = "primary", className, ...props }: ButtonProps) => (
  <button
    {...props}
    className={`px-4 py-2 rounded-xl font-semibold ${
      variant === "primary"
        ? "bg-sky-400 text-slate-900"
        : "bg-slate-800 text-slate-100 border border-slate-600"
    } hover:brightness-105 ${className ?? ""}`.trim()}
  >
    {children}
  </button>
);

type StatPillProps = {
  label: string;
  value: string;
  ok?: boolean;
};

function StatPill({ label, value, ok = true }: StatPillProps) {
  return (
    <div
      className={`px-2 py-1 rounded-full text-xs font-mono border ${
        ok
          ? "border-emerald-500/40 text-emerald-300"
          : "border-rose-500/40 text-rose-300"
      }`}
    >
      {label}: <span className="font-bold">{value}</span>
    </div>
  );
}

type HHMMProps = {
  hours: number;
};

function HHMM({ hours }: HHMMProps) {
  const totalMinutes = Math.round(hours * 60);
  const hh = Math.floor(totalMinutes / 60);
  const mm = totalMinutes % 60;
  return (
    <span>
      {hh}h {mm}m
    </span>
  );
}

function approxEqual(a: number, b: number, tol = 1e-3): boolean {
  return Math.abs(a - b) <= tol;
}
function runSelfTests(): SelfTestResult[] {
  const results: SelfTestResult[] = [];
  try {
    results.push({
      name: "cruiseTimeHours(1164,1164)=1h",
      pass: approxEqual(cruiseTimeHours(1164, 1164), 1.0),
    });
  } catch (e) {
    results.push({ name: "cruiseTimeHours throws", pass: false, err: String(e) });
  }
  try {
    const f1 = altitudeBurnFactor(450);
    const f2 = altitudeBurnFactor(600);
    results.push({
      name: "altitudeBurnFactor bounds",
      pass: f1 >= 1.19 && f1 <= 1.21 && f2 >= 0.99 && f2 <= 1.01,
      values: { f1, f2 },
    });
  } catch (e) {
    results.push({ name: "altitudeBurnFactor throws", pass: false, err: String(e) });
  }
  try {
    const nm = greatCircleNM(51.4706, -0.4619, 40.6413, -73.7781);
    results.push({
      name: "greatCircleNM EGLL-KJFK ~ 3k NM",
      pass: nm > 2500 && nm < 3500,
      value: nm,
    });
  } catch (e) {
    results.push({ name: "greatCircleNM throws", pass: false, err: String(e) });
  }
  try {
    const m = ftToM(11800);
    results.push({ name: "ftToM(11800) ≈ 3597", pass: Math.abs(m - 3596.64) < 0.5, value: m });
  } catch (e) {
    results.push({ name: "ftToM throws", pass: false, err: String(e) });
  }
  try {
    const rh = reheatGuard(24 / 60);
    results.push({ name: "reheatGuard 24min within cap", pass: rh.within_cap === true, value: rh });
  } catch (e) {
    results.push({ name: "reheatGuard throws", pass: false, err: String(e) });
  }
  try {
    const comps = windComponents(0, 20, 90);
    results.push({
      name: "windComponents 90° crosswind ≈ 20 kt",
      pass: Math.abs((comps.crosswind_kt ?? 0) - 20) < 0.1,
      value: comps,
    });
  } catch (e) {
    results.push({ name: "windComponents throws", pass: false, err: String(e) });
  }
  try {
    const lr = pickLongestRunway([
      { id: "A", heading: 0, length_m: 2800 },
      { id: "B", heading: 90, length_m: 3600 },
      { id: "C", heading: 180, length_m: 3200 },
    ]);
    results.push({ name: "pickLongestRunway chooses 3600 m", pass: lr?.id === "B", value: lr });
  } catch (e) {
    results.push({ name: "pickLongestRunway throws", pass: false, err: String(e) });
  }
  try {
    const feas = takeoffFeasibleM(4000, CONSTANTS.weights.mtow_kg);
    results.push({ name: "T/O feasible @ 4000 m, MTOW", pass: feas.feasible === true, value: feas });
  } catch (e) {
    results.push({ name: "takeoffFeasibleM throws", pass: false, err: String(e) });
  }
  try {
    const p = parseMetarWind("XXXX 101650Z VRB05KT 9999");
    results.push({ name: "parseMetarWind VRB05KT dir=null", pass: p.wind_dir_deg === null && p.wind_speed_kt === 5, value: p });
  } catch (e) {
    results.push({ name: "parseMetarWind VRB throws", pass: false, err: String(e) });
  }
  try {
    const mockAir: AirportIndex = {
      EGLL: { name: "EGLL", lat: 51.4706, lon: -0.4619, runways: [] },
      KJFK: { name: "KJFK", lat: 40.6413, lon: -73.7781, runways: [] },
    };
    const mockNav: NavaidIndex = {
      CPT: { ident: "CPT", lat: 51.514, lon: -1.005, type: "NAVAID", name: "CPT" },
    };
    const { points } = resolveRouteTokens(parseRouteString("SID CPT STAR"), mockAir, mockNav);
    const direct = greatCircleNM(mockAir.EGLL.lat, mockAir.EGLL.lon, mockAir.KJFK.lat, mockAir.KJFK.lon);
    const routed = computeRouteDistanceNM(mockAir.EGLL, mockAir.KJFK, points);
    results.push({ name: "route distance >= direct when detoured", pass: routed >= direct - 1 });
  } catch (e) {
    results.push({ name: "route distance test throws", pass: false, err: String(e) });
  }
  try {
    const burn = (dist: number, fl: number) => {
      const base = CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(fl);
      const climb = estimateClimb(fl * 100);
      const desc = estimateDescent(fl * 100);
      const cruiseNM = Math.max(dist - climb.dist_nm - desc.dist_nm, 0);
      return (
        climb.dist_nm * base * CONSTANTS.fuel.climb_factor +
        cruiseNM * base +
        desc.dist_nm * base * CONSTANTS.fuel.descent_factor
      );
    };
    const f450 = burn(2000, 450),
      f600 = burn(2000, 600);
    const f2x = burn(3000, 580),
      f1x = burn(1500, 580);
    results.push({ name: "fuel less at higher FL (2000 NM: FL600 < FL450)", pass: f600 < f450, values: { f450, f600 } });
    results.push({ name: "fuel scales with distance (≈linear)", pass: f2x > f1x && f2x < 2.2 * f1x, values: { f1x, f2x } });
  } catch (e) {
    results.push({ name: "fuel monotonicity throws", pass: false, err: String(e) });
  }
  try {
    const a = landingFeasibleM(2200, CONSTANTS.weights.mlw_kg);
    const b = landingFeasibleM(1800, CONSTANTS.weights.mlw_kg);
    results.push({ name: "landing feasible 2200m@MLW; not at 1800m@MLW", pass: a.feasible === true && b.feasible === false });
  } catch (e) {
    results.push({ name: "landing feasibility throws", pass: false, err: String(e) });
  }
  try {
    const fl = 580;
    const dist = 2000;
    const climb = estimateClimb(fl * 100);
    const desc = estimateDescent(fl * 100);
    const cruiseNM = Math.max(dist - climb.dist_nm - desc.dist_nm, 0);
    const t = cruiseTimeHours(cruiseNM);
    results.push({ name: "manual distance yields finite cruise time", pass: Number.isFinite(t) && t >= 0 });
  } catch (e) {
    results.push({ name: "manual distance sanity throws", pass: false, err: String(e) });
  }

  // New tests: FL clamping
  try {
    const c1 = clampCruiseFL(610);
    const c2 = clampCruiseFL(100);
    results.push({ name: "clampCruiseFL clamps 610→590", pass: c1 === 590, value: c1 });
    results.push({ name: "clampCruiseFL allows 100 (no min clamp)", pass: c2 === 100, value: c2 });
  } catch (e) {
    results.push({ name: "clampCruiseFL throws", pass: false, err: String(e) });
  }

  // New tests: Non-RVSM snapping
  try {
    const e = snapToNonRvsm(580, "E");
    const w = snapToNonRvsm(580, "W");
    results.push({ name: "Non-RVSM: FL580 east snaps to FL570", pass: e.snapped === 570, value: e });
    results.push({ name: "Non-RVSM: FL580 west snaps to FL590", pass: w.snapped === 590, value: w });
    const low = snapToNonRvsm(250, "E");
    results.push({ name: "Non-RVSM: below FL410 unchanged", pass: low.snapped === 250, value: low });
  } catch (e) {
    results.push({ name: "Non-RVSM snapping throws", pass: false, err: String(e) });
  }

  return results;
}

function weightScale(actual: number, reference: number): number {
  if (!Number.isFinite(actual) || actual <= 0 || !Number.isFinite(reference) || reference <= 0) return 1;
  return Math.sqrt(actual / reference);
}
function computeTakeoffSpeeds(towKg: number): TakeoffSpeeds {
  const refKg = 170000;
  const s = weightScale(towKg, refKg);
  const V1 = Math.max(160, Math.round(180 * s));
  const VR = Math.max(170, Math.round(195 * s));
  const V2 = Math.max(190, Math.round(220 * s));
  return { V1, VR, V2 };
}
function computeLandingSpeeds(lwKg: number): LandingSpeeds {
  // Approximate Concorde landing performance:
  // target VLS ≈ 170–190 kt over typical landing weights,
  // with VAPP about 10–15 kt above VLS.
  const refKg = 100000;
  const s = weightScale(lwKg, refKg);

  let VLS = Math.round(175 * s);
  if (VLS < 170) VLS = 170;

  let VAPP = VLS + 15;
  if (VAPP < 185) VAPP = 185;

  return { VLS, VAPP };
}

function ConcordePlannerCanvas() {
  const [airports, setAirports] = useState<AirportIndex>({});
  const [dbLoaded, setDbLoaded] = useState(false);
  const [dbError, setDbError] = useState("");
  const [navaids, setNavaids] = useState<NavaidIndex>({});

  const [depIcao, setDepIcao] = useState("EGLL");
  const [depRw, setDepRw] = useState("");
  const [arrIcao, setArrIcao] = useState("KJFK");
  const [arrRw, setArrRw] = useState("");

  const [manualDistanceNM, setManualDistanceNM] = useState(0);
  const [routeText, setRouteText] = useState<string>("");
  const [routeDistanceNM, setRouteDistanceNM] = useState<number | null>(null);
  const [routeInfo, setRouteInfo] = useState<RouteResolution | null>(null);
  const [routeNotice, setRouteNotice] = useState<string>("");
  const [altIcao, setAltIcao] = useState("");
  const [trimTankKg, setTrimTankKg] = useState(0);

  const [cruiseFL, setCruiseFL] = useState(580);
  const [cruiseFLText, setCruiseFLText] = useState<string>("580");
  const [cruiseFLNotice, setCruiseFLNotice] = useState<string>("");
  const [cruiseFLTouched, setCruiseFLTouched] = useState(false);
  const [taxiKg, setTaxiKg] = useState(2500);
  const [contingencyPct, setContingencyPct] = useState(5);
  const [finalReserveKg, setFinalReserveKg] = useState(3600);

  const [metarDep, setMetarDep] = useState("");
  const [metarArr, setMetarArr] = useState("");
  const [metarErr, setMetarErr] = useState("");

  const [tests, setTests] = useState<SelfTestResult[]>([]);


  const depKey = (depIcao || "").toUpperCase();
  const arrKey = (arrIcao || "").toUpperCase();
  const altKey = (altIcao || "").toUpperCase();

  useEffect(() => {
    (async () => {
      try {
        const [airCsv, rwCsv, navCsv] = await Promise.all([
          fetch(AIRPORTS_CSV_URL, { mode: "cors" }).then((r) => r.text()),
          fetch(RUNWAYS_CSV_URL, { mode: "cors" }).then((r) => r.text()),
          fetch(NAVAIDS_CSV_URL, { mode: "cors" }).then((r) => r.text()),
        ]);

        const airportsDb = buildWorldAirportDB(airCsv, rwCsv);
        const navaidsDb = buildNavaidsDB(navCsv);

        setAirports(airportsDb);
        setNavaids(navaidsDb);
        setDbLoaded(true);
        setDbError("");
      } catch (e) {
        setDbError(String(e));
        setDbLoaded(false);
      }
    })();
  }, []);

  useEffect(() => {
    const a = depKey ? airports[depKey] : undefined;
    if (a?.runways?.length) {
      const longest = pickLongestRunway(a.runways);
      const hasCurrent = a.runways.some((r) => r.id === depRw);
      if ((!depRw || !hasCurrent) && longest && depRw !== longest.id) {
        setDepRw(longest.id);
      }
    } else if (depRw) {
      setDepRw("");
    }
  }, [airports, depKey, depRw]);

  useEffect(() => {
    const a = arrKey ? airports[arrKey] : undefined;
    if (a?.runways?.length) {
      const longest = pickLongestRunway(a.runways);
      const hasCurrent = a.runways.some((r) => r.id === arrRw);
      if ((!arrRw || !hasCurrent) && longest && arrRw !== longest.id) {
        setArrRw(longest.id);
      }
    } else if (arrRw) {
      setArrRw("");
    }
  }, [airports, arrKey, arrRw]);

  const depInfo = depKey ? airports[depKey] : undefined;
  const arrInfo = arrKey ? airports[arrKey] : undefined;

  function computeRouteDistanceFromText(text: string): {
    distanceNM: number;
    resolution: RouteResolution;
  } | null {
    if (!depInfo || !arrInfo) return null;
    const tokens = parseRouteString(text);
    const resolution = resolveRouteTokens(tokens, airports, navaids);
    const distanceNM = computeRouteDistanceNM(depInfo, arrInfo, resolution.points);
    return { distanceNM, resolution };
  }

  function applyRouteDistance() {
    setRouteNotice("");

    if (!depInfo || !arrInfo) {
      setRouteNotice("Enter valid DEP/ARR ICAO first (so we know where the route starts/ends).");
      return;
    }

    if (!routeText.trim()) {
      setRouteNotice("Paste a route string first.");
      return;
    }

    const out = computeRouteDistanceFromText(routeText);
    if (!out) {
      setRouteNotice("Could not compute route distance.");
      return;
    }

    const rounded = Math.round(out.distanceNM);
    setRouteDistanceNM(out.distanceNM);
    setRouteInfo(out.resolution);

    // Auto-fill Planned Distance, but keep it editable (user can override)
    setManualDistanceNM(rounded);

    const unresolved = out.resolution.recognized.unresolved.length;
    const proc = out.resolution.recognized.procedures.length;
    const airways = out.resolution.recognized.airways.length;

    const parts: string[] = [`Route distance set to ${rounded.toLocaleString()} NM.`];
    if (proc > 0) parts.push(`${proc} procedure tokens ignored.`);
    if (airways > 0) parts.push(`${airways} airway tokens ignored.`);
    if (unresolved > 0) parts.push(`${unresolved} unresolved tokens ignored (likely fixes/waypoints not in this DB).`);

    setRouteNotice(parts.join(" "));
  }

  const directionEW = useMemo(() => inferDirectionEW(depInfo, arrInfo), [depInfo, arrInfo]);

  // Auto-pick a compliant cruise level when route changes (unless user has manually touched the field).
  useEffect(() => {
    if (!directionEW) return;
    if (cruiseFLTouched) return;
    const rec = recommendedCruiseFL(directionEW);
    setCruiseFL(rec);
    setCruiseFLText(String(rec));
    setCruiseFLNotice(`Auto-selected Non-RVSM cruise FL${rec} (${directionEW === "E" ? "Eastbound" : "Westbound"}).`);
  }, [directionEW, cruiseFLTouched]);

  const plannedDistance = Math.max(manualDistanceNM || 0, 0);

  const cruiseAltFt = cruiseFL * 100;
  const climb = useMemo(() => estimateClimb(cruiseAltFt), [cruiseAltFt]);
  const descent = useMemo(() => estimateDescent(cruiseAltFt), [cruiseAltFt]);
  const reheat = useMemo(() => reheatGuard(climb.time_h), [climb.time_h]);
  const cruiseDistanceNM = Math.max(plannedDistance - climb.dist_nm - descent.dist_nm, 0);
  const cruiseTimeH = cruiseTimeHours(cruiseDistanceNM);
  const totalTimeH = climb.time_h + cruiseTimeH + descent.time_h;

  const tripKg = useMemo(() => {
    const baseBurn = CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(cruiseFL);
    const climbKg = climb.dist_nm * baseBurn * CONSTANTS.fuel.climb_factor;
    const cruiseKg = cruiseDistanceNM * baseBurn;
    const descentKg = descent.dist_nm * baseBurn * CONSTANTS.fuel.descent_factor;
    const kg = climbKg + cruiseKg + descentKg;
    return Math.max(kg, 0);
  }, [cruiseFL, climb.dist_nm, cruiseDistanceNM, descent.dist_nm]);

  const altInfo = altKey ? airports[altKey] : undefined;
  const alternateDistanceNM = useMemo(() => {
    if (!arrInfo || !altInfo) return 0;
    return greatCircleNM(arrInfo.lat, arrInfo.lon, altInfo.lat, altInfo.lon);
  }, [arrInfo, altInfo]);

  const blocks = useMemo(
    () =>
      blockFuelKg({
        tripKg,
        taxiKg,
        contingencyPct,
        finalReserveKg,
        alternateNM: alternateDistanceNM,
        burnKgPerNm: CONSTANTS.fuel.burn_kg_per_nm,
      }),
    [tripKg, taxiKg, contingencyPct, finalReserveKg, alternateDistanceNM]
  );

  const totalFuelRequiredKg = (blocks.block_kg || 0) + (trimTankKg || 0);
  const eteHours = totalTimeH;
  const avgBurnKgPerHour =
    eteHours > 0
      ? tripKg / eteHours
      : CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(cruiseFL) * CONSTANTS.speeds.cruise_tas_kt;

  const airborneFuelKg = Math.max(totalFuelRequiredKg - (taxiKg || 0), 0);
  const enduranceHours = avgBurnKgPerHour > 0 ? airborneFuelKg / avgBurnKgPerHour : 0;
  const reserveTimeH =
    avgBurnKgPerHour > 0
      ? ((blocks.contingency_kg || 0) + (blocks.final_reserve_kg || 0) + (blocks.alternate_kg || 0)) / avgBurnKgPerHour
      : 0;

  const enduranceMeets = enduranceHours >= eteHours + reserveTimeH;

  const fuelCapacityKg = CONSTANTS.weights.fuel_capacity_kg;
  const fuelWithinCapacity = totalFuelRequiredKg <= fuelCapacityKg;
  const fuelExcessKg = Math.max(totalFuelRequiredKg - fuelCapacityKg, 0);

  const fullPayloadKg = (CONSTANTS.weights.pax_full_count || 0) * (CONSTANTS.weights.pax_mass_kg || 0);
  const tkoWeightKgAuto = Math.min(
    (CONSTANTS.weights.oew_kg || 0) + fullPayloadKg + totalFuelRequiredKg,
    CONSTANTS.weights.mtow_kg
  );

  const estLandingWeightKg = Math.max(tkoWeightKgAuto - tripKg, 0);
  const tkSpeeds = computeTakeoffSpeeds(tkoWeightKgAuto);
  const ldSpeeds = computeLandingSpeeds(estLandingWeightKg);

  const depRunways = depInfo?.runways ?? [];
  const arrRunways = arrInfo?.runways ?? [];
  const depRunway = depRunways.find((r) => r.id === depRw);
  const arrRunway = arrRunways.find((r) => r.id === arrRw);

  const tkoCheck = useMemo(() => takeoffFeasibleM(depRunway?.length_m || 0, tkoWeightKgAuto), [depRunway, tkoWeightKgAuto]);
  const ldgCheck = useMemo(() => landingFeasibleM(arrRunway?.length_m || 0, estLandingWeightKg), [arrRunway, estLandingWeightKg]);

  const depWind = useMemo(() => {
    const p = parseMetarWind(metarDep || "");
    const comps = depRunway ? windComponents(p.wind_dir_deg, p.wind_speed_kt, depRunway.heading) : { headwind_kt: null, crosswind_kt: null };
    return { parsed: p, comps };
  }, [metarDep, depRunway]);

  const arrWind = useMemo(() => {
    const p = parseMetarWind(metarArr || "");
    const comps = arrRunway ? windComponents(p.wind_dir_deg, p.wind_speed_kt, arrRunway.heading) : { headwind_kt: null, crosswind_kt: null };
    return { parsed: p, comps };
  }, [metarArr, arrRunway]);

  async function fetchMetars() {
    const errors: string[] = [];
    if (!depKey || !arrKey) {
      setMetarErr("Both departure and arrival ICAO codes are required.");
      return;
    }
    setMetarErr("");
    const [d, a] = await Promise.all([fetchMetarByICAO(depKey), fetchMetarByICAO(arrKey)]);
    if (!d.ok) errors.push(d.error);
    if (!a.ok) errors.push(a.error);
    if (errors.length > 0) setMetarErr(errors.join(" ").trim());
    if (d.ok) setMetarDep(d.raw);
    if (a.ok) setMetarArr(a.raw);
  }

  const passCount = tests.filter((t) => t.pass).length;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <header className="px-6 py-4 border-b border-slate-800 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-2xl">✈️</span>
          <div>
            <h1 className="text-2xl font-bold">
              Concorde EFB <span className="text-sky-400">v{APP_VERSION}</span>
            </h1>
            <p className="text-xs text-slate-400">Your Concorde copilot for MSFS.</p>
          </div>
        </div>
        <div className="flex gap-2 items-center">
          <StatPill label="Nav DB" value={dbLoaded ? "Loaded" : "Loading…"} ok={dbLoaded && !dbError} />
          {dbError && <StatPill label="DB Error" value={dbError.slice(0, 40) + "…"} ok={false} />}
          <StatPill label="TAS" value={`${CONSTANTS.speeds.cruise_tas_kt} kt`} />
          <StatPill label="MTOW" value={`${CONSTANTS.weights.mtow_kg.toLocaleString()} kg`} />
          <StatPill label="MLW" value={`${CONSTANTS.weights.mlw_kg.toLocaleString()} kg`} />
          <StatPill label="Fuel cap" value={`${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg`} />
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6 grid gap-6">
        <Card title="Departure / Arrival (ICAO & Runways)" right={<Button onClick={fetchMetars}>Fetch METARs</Button>}>
          <Row>
            <div>
              <Label>Departure ICAO</Label>
              <Input value={depIcao} onChange={(e) => setDepIcao(e.target.value.toUpperCase())} />
              {!depInfo && dbLoaded && <div className="text-xs text-rose-300 mt-1">Unknown ICAO in database</div>}
            </div>
            <div>
              <Label>Arrival ICAO</Label>
              <Input value={arrIcao} onChange={(e) => setArrIcao(e.target.value.toUpperCase())} />
              {!arrInfo && dbLoaded && <div className="text-xs text-rose-300 mt-1">Unknown ICAO in database</div>}
            </div>
          </Row>
          <Row>
            <div>
              <Label>Departure Runway (meters)</Label>
              <Select value={depRw} onChange={(e) => setDepRw(e.target.value)}>
                {depRunways.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.id} • {Number(r.length_m).toLocaleString()} m • HDG {Math.round(r.heading)}°
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <Label>Arrival Runway (meters)</Label>
              <Select value={arrRw} onChange={(e) => setArrRw(e.target.value)}>
                {arrRunways.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.id} • {Number(r.length_m).toLocaleString()} m • HDG {Math.round(r.heading)}°
                  </option>
                ))}
              </Select>
            </div>
          </Row>
        </Card>

        <Card title="Cruise & Fuel (Manual Distance)">
          <Row>
            <div>
              <Label>Planned Distance (NM)</Label>
              <Input type="number" value={manualDistanceNM} onChange={(e) => setManualDistanceNM(parseFloat(e.target.value || "0"))} />
              <div className="text-xs text-slate-400 mt-1">
                Enter distance from your flight planner. We’ll compute Climb/Cruise/Descent from this and FL.
              </div>
            </div>
            <div>
              <Label>Cruise Flight Level (FL)</Label>
              <Input
                type="number"
                value={cruiseFLText}
                min={MIN_CONCORDE_FL}
                max={MAX_CONCORDE_FL}
                step={10}
                onChange={(e) => {
                  const next = e.target.value;
                  setCruiseFLTouched(true);
                  setCruiseFLText(next);

                  // Update calculations live when parsable, but don't snap while typing.
                  const n = Number(next);
                  if (Number.isFinite(n)) setCruiseFL(n);
                }}
                onBlur={() => {
                  const n = Number(cruiseFLText);
                  if (!Number.isFinite(n)) {
                    setCruiseFLNotice("Invalid FL value.");
                    return;
                  }

                  // 1) Clamp to Concorde max
                  let clamped = clampCruiseFL(n);
                  let noticeParts: string[] = [];

                  if (n !== clamped) {
                    noticeParts.push(`Clamped to FL${clamped} (max FL${MAX_CONCORDE_FL}).`);
                  }

                  // 2) Apply Non-RVSM snapping above FL410 when direction is known
                  if (directionEW && clamped >= NON_RVSM_MIN_FL) {
                    const { snapped, changed } = snapToNonRvsm(clamped, directionEW);
                    if (changed) {
                      noticeParts.push(
                        `Adjusted to Non-RVSM FL${snapped} (${directionEW === "E" ? "Eastbound" : "Westbound"}).`
                      );
                      clamped = snapped;
                    }
                  }

                  setCruiseFL(clamped);
                  setCruiseFLText(String(clamped));
                  setCruiseFLNotice(noticeParts.join(" "));
                }}
              />
              <div className="text-xs text-slate-400 mt-1">
                {directionEW ? (
                  <span>
                    Direction (auto): <b>{directionEW === "E" ? "Eastbound" : "Westbound"}</b>. Above FL410 we snap to Non-RVSM levels.
                  </span>
                ) : (
                  <span>Direction: <b>unknown</b> (enter valid DEP/ARR ICAO to enable Non-RVSM snapping).</span>
                )}
              </div>
              {cruiseFLNotice && (
                <div
                  className={`text-xs mt-1 ${
                    cruiseFLNotice.startsWith("Auto-selected") ? "text-emerald-300" : "text-rose-300"
                  }`}
                >
                  {cruiseFLNotice}
                </div>
              )}
            </div>
          </Row>

          <Row cols={4}>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Planned Distance</div>
              <div className="text-lg font-semibold">{plannedDistance ? Math.round(plannedDistance).toLocaleString() : "—"} NM</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Climb</div>
              <div className="text-lg font-semibold">
                <HHMM hours={climb.time_h} />
              </div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Cruise</div>
              <div className="text-lg font-semibold">
                <HHMM hours={cruiseTimeH} />
              </div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Descent</div>
              <div className="text-lg font-semibold">
                <HHMM hours={descent.time_h} />
              </div>
            </div>
          </Row>

          <Row>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Total Flight Time (ETE)</div>
              <div className="text-lg font-semibold">
                <HHMM hours={totalTimeH} />
              </div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Fuel Endurance (airborne)</div>
              <div className="text-lg font-semibold">
                <HHMM hours={enduranceHours} />
              </div>
            </div>
            <div className={`px-3 py-2 rounded-xl bg-slate-950 border ${enduranceMeets ? "border-emerald-500/40" : "border-rose-500/40"}`}>
              <div className="text-xs text-slate-400">Required Minimum (ETE + reserves)</div>
              <div className="text-lg font-semibold">
                <HHMM hours={eteHours + reserveTimeH} />
              </div>
            </div>
          </Row>

          <Row>
            <div>
              <Label>Alternate ICAO (optional)</Label>
              <Input value={altIcao} onChange={(e) => setAltIcao(e.target.value.toUpperCase())} />
              <div className="text-xs text-slate-400 mt-1">
                ARR → ALT distance: <b>{Math.round(alternateDistanceNM || 0).toLocaleString()}</b> NM
              </div>
            </div>
            <div>
              <Label>Taxi Fuel (kg)</Label>
              <Input type="number" value={taxiKg} onChange={(e) => setTaxiKg(parseFloat(e.target.value || "0"))} />
            </div>
            <div>
              <Label>Computed TOW (kg)</Label>
              <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold">
                {Math.round(tkoWeightKgAuto).toLocaleString()} kg
              </div>
            </div>
          </Row>

          <Row>
            <div>
              <Label>Contingency (%)</Label>
              <Input type="number" value={contingencyPct} onChange={(e) => setContingencyPct(parseFloat(e.target.value || "0"))} />
            </div>
            <div>
              <Label>Final Reserve (kg)</Label>
              <Input type="number" value={finalReserveKg} onChange={(e) => setFinalReserveKg(parseFloat(e.target.value || "0"))} />
            </div>
          </Row>

          <Row>
            <div>
              <Label>Trim Tank Fuel (kg)</Label>
              <Input type="number" value={trimTankKg} onChange={(e) => setTrimTankKg(parseFloat(e.target.value || "0"))} />
            </div>
            <div>
              <Label>Alternate Fuel (kg)</Label>
              <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold">
                {Math.round((alternateDistanceNM || 0) * CONSTANTS.fuel.burn_kg_per_nm).toLocaleString()} kg
              </div>
            </div>
          </Row>

          <div className="mt-3 grid gap-3 md:grid-cols-4 grid-cols-2">
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Trip Fuel</div>
              <div className="text-lg font-semibold">{Math.round(tripKg).toLocaleString()} kg</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Block Fuel</div>
              <div className="text-lg font-semibold">{Math.round(blocks.block_kg).toLocaleString()} kg</div>
            </div>
            <div className={`px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 ${reheat.within_cap ? "" : "border-rose-500/40"}`}>
              <div className="text-xs text-slate-400">Reheat OK</div>
              <div className={`text-lg font-semibold ${reheat.within_cap ? "text-emerald-400" : "text-rose-400"}`}>{reheat.within_cap ? "YES" : "NO"}</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Total Fuel Required (Block + Trim)</div>
              <div className="text-lg font-semibold">
                {Number.isFinite(blocks.block_kg) && Number.isFinite(trimTankKg) ? Math.round(blocks.block_kg + (trimTankKg || 0)).toLocaleString() : "—"} kg
              </div>
            </div>
          </div>

          {!fuelWithinCapacity && (
            <div className="mt-2 text-xs text-rose-300">
              Warning: Total fuel <b>{Math.round(totalFuelRequiredKg).toLocaleString()} kg</b> exceeds Concorde fuel capacity{" "}
              <b>{Math.round(fuelCapacityKg).toLocaleString()} kg</b> by <b>{Math.round(fuelExcessKg).toLocaleString()} kg</b>. Reduce block or trim fuel to stay within limits.
            </div>
          )}
        </Card>

        <Card title="Takeoff & Landing Speeds (IAS)">
          <Row cols={4}>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Computed TOW</div>
              <div className="text-lg font-semibold">{Math.round(tkoWeightKgAuto).toLocaleString()} kg</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">V1</div>
              <div className="text-lg font-semibold">{tkSpeeds.V1} kt</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">VR</div>
              <div className="text-lg font-semibold">{tkSpeeds.VR} kt</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">V2</div>
              <div className="text-lg font-semibold">{tkSpeeds.V2} kt</div>
            </div>
          </Row>
          <Row cols={4}>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Est. Landing WT</div>
              <div className="text-lg font-semibold">{Math.round(estLandingWeightKg).toLocaleString()} kg</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">VLS</div>
              <div className="text-lg font-semibold">{ldSpeeds.VLS} kt</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">VAPP</div>
              <div className="text-lg font-semibold">{ldSpeeds.VAPP} kt</div>
            </div>
          </Row>
          <div className="text-xs text-slate-400 mt-2">
            Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim.
          </div>
        </Card>

        <Card title="Weather & Runway Wind Components" right={<div className="text-xs text-slate-400">ILS intercept tip: ~15 NM / 5000 ft</div>}>
          {metarErr && <div className="text-xs text-rose-300 mb-2">METAR fetch error: {metarErr}</div>}
          <div className="grid gap-4">
            <div>
              <div className="text-sm font-semibold mb-1">Departure METAR ({depIcao}{depRunway ? ` ${depRunway.id}` : ""})</div>
              <Input placeholder="Raw METAR will appear here if fetch works; otherwise paste manually" value={metarDep} onChange={(e) => setMetarDep(e.target.value)} />
              <div className="grid md:grid-cols-4 grid-cols-2 gap-3 mt-2">
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Headwind</div>
                  <div className="text-lg font-semibold">{depWind.comps.headwind_kt ?? "—"} kt</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Crosswind</div>
                  <div className="text-lg font-semibold">{depWind.comps.crosswind_kt ?? "—"} kt</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Dir</div>
                  <div className="text-lg font-semibold">{depWind.parsed.wind_dir_deg ?? "VRB"}</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Spd/Gust</div>
                  <div className="text-lg font-semibold">
                    {depWind.parsed.wind_speed_kt ?? "—"}/{depWind.parsed.wind_gust_kt ?? "—"} kt
                  </div>
                </div>
              </div>
            </div>

            <div>
              <div className="text-sm font-semibold mb-1">Arrival METAR ({arrIcao}{arrRunway ? ` ${arrRunway.id}` : ""})</div>
              <Input placeholder="Raw METAR will appear here if fetch works; otherwise paste manually" value={metarArr} onChange={(e) => setMetarArr(e.target.value)} />
              <div className="grid md:grid-cols-4 grid-cols-2 gap-3 mt-2">
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Headwind</div>
                  <div className="text-lg font-semibold">{arrWind.comps.headwind_kt ?? "—"} kt</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Crosswind</div>
                  <div className="text-lg font-semibold">{arrWind.comps.crosswind_kt ?? "—"} kt</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Dir</div>
                  <div className="text-lg font-semibold">{arrWind.parsed.wind_dir_deg ?? "VRB"}</div>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-xs text-slate-400">Spd/Gust</div>
                  <div className="text-lg font-semibold">
                    {arrWind.parsed.wind_speed_kt ?? "—"}/{arrWind.parsed.wind_gust_kt ?? "—"} kt
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Card>

        <Card title="Runway Feasibility Summary">
          <Row cols={4}>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">T/O Req (m)</div>
              <div className="text-lg font-semibold">{Math.round(tkoCheck.required_length_m_est).toLocaleString()} m</div>
            </div>
            <div className={`px-3 py-2 rounded-xl bg-slate-950 border ${tkoCheck.feasible ? "border-emerald-500/40" : "border-rose-500/40"}`}>
              <div className="text-xs text-slate-400">Departure Feasible?</div>
              <div className={`text-lg font-semibold ${tkoCheck.feasible ? "text-emerald-400" : "text-rose-400"}`}>{tkoCheck.feasible ? "YES" : "NO"}</div>
            </div>
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">LDG Req (m)</div>
              <div className="text-lg font-semibold">{Math.round(ldgCheck.required_length_m_est).toLocaleString()} m</div>
            </div>
            <div className={`px-3 py-2 rounded-xl bg-slate-950 border ${ldgCheck.feasible ? "border-emerald-500/40" : "border-rose-500/40"}`}>
              <div className="text-xs text-slate-400">Arrival Feasible?</div>
              <div className={`text-lg font-semibold ${ldgCheck.feasible ? "text-emerald-400" : "text-rose-400"}`}>{ldgCheck.feasible ? "YES" : "NO"}</div>
            </div>
          </Row>
          <div className="text-xs text-slate-400 mt-2">
            Est. landing weight: <b>{Math.round(estLandingWeightKg).toLocaleString()} kg</b> (TOW − Trip Fuel).
          </div>
        </Card>

        <Card title="Diagnostics / Self-tests" right={<Button variant="ghost" onClick={() => setTests(runSelfTests())}>Run Self-Tests</Button>}>
          <div className="text-xs text-slate-400 mb-2">
            Covers meters, crosswind, longest-runway, VRB parsing, manual-distance sanity, fuel monotonicity, landing feasibility, and FL clamping.
          </div>
          {tests.length === 0 ? (
            <div className="text-sm text-slate-300">
              Click <b>Run Self-Tests</b> to execute.
            </div>
          ) : (
            <div>
              <div className="mb-2 text-sm">Passed {passCount}/{tests.length}</div>
              <ul className="list-disc pl-5 text-sm space-y-1">
                {tests.map((t, i) => (
                  <li key={i} className={t.pass ? "text-emerald-300" : "text-rose-300"}>
                    {t.name} {t.pass ? "✓" : "✗"} {t.err ? `— ${t.err}` : ""}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Card>

        <Card title="Notes & Assumptions (for tuning)">
          <ul className="list-disc pl-5 text-sm text-slate-300 space-y-1">
            <li>All masses in <b>kg</b>. Distances in <b>NM</b>. Runway lengths in <b>m</b> only.</li>
            <li>Nav DB autoloads Airports/Runways/NAVAIDs from OurAirports. No fallback.</li>
            <li>Procedural tokens are accepted so copy-pasting OFP routes won’t break; true SID/STAR geometry is not expanded yet.</li>
            <li>Fuel model is heuristic but altitude-sensitive and distance-stable; calibrate with DC Designs manual and in-sim numbers.</li>
          </ul>
        </Card>
      </main>

      <footer className="p-6 text-center text-xs text-slate-500">
        Manual values © DC Designs Concorde (MSFS). Planner is for training/planning only; always verify in-sim. Made with love by @theawesomeray
      </footer>

      {/* Opens counter badge (bottom-right) */}
      <a
        className="fixed bottom-3 right-3 z-50"
        href={OPENS_COUNTER_PATH}
        target="_blank"
        rel="noreferrer"
        title="Site visits (counts every app load)"
      >
        <img
          src={OPENS_BADGE_SRC}
          alt="Site visits counter"
          className="h-6 w-auto rounded-md border border-slate-700 bg-slate-950/70 backdrop-blur"
          loading="lazy"
        />
      </a>
    </div>
  );
}

type EBState = { error: unknown | null };

class ErrorBoundary extends React.Component<{ children: React.ReactNode }, EBState> {
  state: EBState = { error: null };
  static getDerivedStateFromError(error: unknown): EBState {
    return { error };
  }
  componentDidCatch(error: unknown, info: any) {
    console.error("Concorde EFB crashed:", error, info);
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 16 }}>
          <h2>Something went wrong.</h2>
          <p>Open the browser console for details.</p>
          <pre style={{ whiteSpace: "pre-wrap" }}>{String(this.state.error)}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}

export default function ConcordeEFB() {
  return (
    <ErrorBoundary>
      <ConcordePlannerCanvas />
    </ErrorBoundary>
  );
}
        <Card
          title="Route (paste from SimBrief / OFP)"
          right={<Button variant="ghost" onClick={applyRouteDistance}>Compute & Apply Distance</Button>}
        >
          <div className="text-xs text-slate-400 mb-2">
            Paste your route string (tokens separated by spaces). We’ll estimate distance using airports + OurAirports navaids.
            SID/STAR/airway tokens are accepted but not expanded into real geometry yet.
          </div>

          <textarea
            value={routeText}
            onChange={(e) => setRouteText(e.target.value)}
            placeholder="Example: EGLL CPT UL9 STU DCT ... KJFK"
            className="w-full min-h-[110px] px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500"
          />

          <div className="mt-3 grid gap-3 md:grid-cols-3 grid-cols-1">
            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Estimated Route Distance</div>
              <div className="text-lg font-semibold">
                {routeDistanceNM == null ? "—" : `${Math.round(routeDistanceNM).toLocaleString()} NM`}
              </div>
            </div>

            <div className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800">
              <div className="text-xs text-slate-400">Recognized</div>
              <div className="text-sm text-slate-200">
                Procedures: <b>{routeInfo?.recognized.procedures.length ?? 0}</b> • Airway: <b>{routeInfo?.recognized.airways.length ?? 0}</b> • Points: <b>{routeInfo?.points.length ?? 0}</b>
              </div>
            </div>

            <div className={`px-3 py-2 rounded-xl bg-slate-950 border ${routeInfo && (routeInfo.recognized.unresolved.length ?? 0) === 0 ? "border-emerald-500/40" : "border-slate-800"}`}>
              <div className="text-xs text-slate-400">Unresolved Tokens</div>
              <div className="text-sm text-slate-200">
                <b>{routeInfo?.recognized.unresolved.length ?? 0}</b>
              </div>
            </div>
          </div>

          {routeNotice && <div className="mt-2 text-xs text-slate-300">{routeNotice}</div>}

          {routeInfo && (routeInfo.recognized.unresolved.length ?? 0) > 0 && (
            <div className="mt-2 text-xs text-slate-400">
              Unresolved examples: <span className="font-mono">{routeInfo.recognized.unresolved.slice(0, 8).join(" ")}</span>
              {routeInfo.recognized.unresolved.length > 8 ? " …" : ""}
            </div>
          )}

          <div className="mt-2 text-xs text-slate-400">
            Note: the <b>Planned Distance (NM)</b> field below stays editable — you can override anytime.
          </div>
        </Card>