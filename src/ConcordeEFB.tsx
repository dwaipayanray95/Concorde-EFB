// Concorde EFB — Canvas v0.7 (for DC Designs, MSFS 2024)
// What’s new in v0.7
// • Manual distance input (NM) — users paste planner distance; no auto route math for accuracy.
// • Alternate ICAO → ARR→ALT distance & alternate fuel added into Block.
// • Trim Tank Fuel (kg) added; **Total Fuel Required = Block + Trim**.
// • Landing feasibility added (arrival) + departure feasibility — now display **reasons** when NOT feasible (required vs available, deficit).
// • METAR fetch more robust: tries AviationWeather API, then VATSIM fallback.
// • All units metric (kg, m); longest-runway autopick; crosswind/headwind components.
// • Self-tests cover manual-distance sanity, fuel monotonicity, feasibility sanity.
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
} from "react";
import Papa from "papaparse";

const APP_VERSION = "2.0.1";
const BUILD_MARKER = "281225-RC6";
const DEBUG_FL_AUTOPICK = false;
// App icon
// IMPORTANT: We want this to work on GitHub Pages (non-root base path) and inside Tauri.
// Using `new URL(..., import.meta.url)` makes Vite bundle the PNG and generate a correct URL
// regardless of the deployed base.
const APP_ICON_SRC_PRIMARY = new URL("../app-icon.png", import.meta.url).href;

// Fallback to `/icon.png` (from Vite /public) if present; otherwise we fall back to the SVG.
const APP_ICON_SRC_FALLBACK = `${import.meta.env.BASE_URL}icon.png`;

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

const ALL_NON_RVSM_LEVELS: number[] = Array.from(
  new Set([...nonRvsmValidFLs("E"), ...nonRvsmValidFLs("W")])
).sort((a, b) => a - b);

function normalizeCruiseFLByRules(fl: number, direction: DirectionEW | null): number {
  // 1) Clamp to Concorde limits
  let next = clampCruiseFL(fl);

  // 2) Above FL410, snap to valid Non-RVSM levels.
  // If direction is unknown, snap to the nearest level from the union set.
  if (next >= NON_RVSM_MIN_FL) {
    if (direction) {
      next = snapToNonRvsm(next, direction).snapped;
    } else {
      // Snap to nearest in ALL_NON_RVSM_LEVELS; tie-break to the lower level.
      let best = ALL_NON_RVSM_LEVELS[0];
      let bestDiff = Math.abs(best - next);
      for (const v of ALL_NON_RVSM_LEVELS) {
        const d = Math.abs(v - next);
        if (d < bestDiff || (d === bestDiff && v < best)) {
          best = v;
          bestDiff = d;
        }
      }
      next = best;
    }
  }

  return next;
}


function recommendedCruiseFL(direction: DirectionEW): number {
  // Keep the app’s original intent (high cruise) but make it compliant.
  const target = 580;
  const { snapped } = snapToNonRvsm(target, direction);
  return snapped;
}

// --- Cruise FL Recommendation Helper Types & Functions ---
type CruiseFLRecommendation = {
  fl: number;
  cruiseMin: number;
  cruiseNM: number;
  climbNM: number;
  descentNM: number;
  meetsMinimum: boolean;
  note: string;
};

function buildCandidateFLs(direction: DirectionEW | null): number[] {
  const minAutoFL = 250;
  const maxAutoFL = MAX_CONCORDE_FL;

  const lows: number[] = [];
  for (let fl = minAutoFL; fl < NON_RVSM_MIN_FL; fl += 10) lows.push(fl);

  const highs: number[] = [];
  if (direction) {
    highs.push(...nonRvsmValidFLs(direction));
  } else {
    for (let fl = NON_RVSM_MIN_FL; fl <= maxAutoFL; fl += 10) highs.push(fl);
  }

  // Combine + sort descending (prefer highest FL that still gives enough cruise)
  const all = Array.from(new Set([...highs, ...lows]))
    .filter((fl) => fl >= minAutoFL && fl <= maxAutoFL)
    .sort((a, b) => b - a);

  return all;
}

function recommendCruiseFLForDistance(
  plannedDistanceNM: number,
  direction: DirectionEW | null,
  opts?: { minCruiseMin?: number; targetCruiseMin?: number }
): CruiseFLRecommendation | null {
  const distance = Number(plannedDistanceNM);
  if (!Number.isFinite(distance) || distance <= 0) return null;

  const minCruiseMin = opts?.minCruiseMin ?? 15;
  const targetCruiseMin = opts?.targetCruiseMin ?? 18;

  const candidates = buildCandidateFLs(direction);

  // Evaluate candidates and pick the highest FL that still yields >= min cruise.
  let bestMeeting: CruiseFLRecommendation | null = null;
  let bestOverall: CruiseFLRecommendation | null = null;

  for (const fl of candidates) {
    const climb = estimateClimb(fl * 100);
    const descent = estimateDescent(fl * 100);

    const climbNM = climb.dist_nm;
    const descentNM = descent.dist_nm;
    const cruiseNM = Math.max(distance - (climbNM + descentNM), 0);
    const cruiseMin = cruiseTimeHours(cruiseNM) * 60;

    const meets = cruiseMin >= minCruiseMin;

    const rec: CruiseFLRecommendation = {
      fl,
      cruiseMin,
      cruiseNM,
      climbNM,
      descentNM,
      meetsMinimum: meets,
      note: "",
    };

    if (!bestOverall || rec.cruiseMin > bestOverall.cruiseMin) {
      bestOverall = rec;
    }

    if (meets) {
      // Keep the first meeting candidate because the list is sorted descending.
      bestMeeting = rec;
      break;
    }
  }

  const chosen = bestMeeting ?? bestOverall;
  if (!chosen) return null;

  // Ensure the recommended FL is always valid under Concorde + Non-RVSM rules.
  chosen.fl = normalizeCruiseFLByRules(chosen.fl, direction);

  const dirTxt = direction ? (direction === "E" ? "eastbound" : "westbound") : "";

  if (bestMeeting) {
    const targetTxt = chosen.cruiseMin >= targetCruiseMin ? "" : " (tight sector)";
    chosen.note = `Auto-selected FL${chosen.fl}${dirTxt ? ` (${dirTxt})` : ""} to keep ~${Math.round(chosen.cruiseMin)} min cruise${targetTxt}.`;
  } else {
    chosen.note = `Short sector: even at FL${chosen.fl}${dirTxt ? ` (${dirTxt})` : ""}, cruise is only ~${Math.round(chosen.cruiseMin)} min.`;
  }

  return chosen;
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

type NavaidIndex = Record<string, NavaidInfo[]>;

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

type SimbriefExtract = {
  originIcao?: string;
  destIcao?: string;
  depRunway?: string;
  arrRunway?: string;
  alternateIcao?: string;
  route?: string;
  distanceNm?: number;
  cruiseFL?: number;
  depMetar?: string;
  arrMetar?: string;
  raw?: unknown;
  callSign?: string;
  registration?: string;
};

function normalizeIcao4(v: unknown): string | undefined {
  const s = String(v ?? "").trim().toUpperCase();
  return /^[A-Z]{4}$/.test(s) ? s : undefined;
}

function normalizeRunwayId(v: unknown): string | undefined {
  const s = String(v ?? "").trim().toUpperCase();
  // Allow: 27, 09, 30R, 04L, etc.
  // Normalize leading zeros to two digits when present.
  const m = /^(\d{1,2})([LRC])?$/.exec(s);
  if (!m) return undefined;
  const n = Number(m[1]);
  if (!Number.isFinite(n) || n < 1 || n > 36) return undefined;
  const num2 = String(n).padStart(2, "0");
  return `${num2}${m[2] ?? ""}`;
}


function normalizeCallsign(v: unknown): string | undefined {
  const s = String(v ?? "").trim().toUpperCase();
  if (!s) return undefined;
  // Keep alnum + dashes, typical callsign length.
  const cleaned = s.replace(/[^A-Z0-9-]/g, "");
  return cleaned && cleaned.length >= 2 ? cleaned : undefined;
}

function normalizeRegistration(v: unknown): string | undefined {
  const s = String(v ?? "").trim().toUpperCase();
  if (!s) return undefined;

  // Keep typical aircraft registration/tail formats (e.g., G-BOAC, VT-ABC, N123AB)
  const cleaned = s.replace(/[^A-Z0-9-]/g, "");
  if (!cleaned) return undefined;

  // Basic sanity: at least 3 chars, no trailing/leading dashes
  if (cleaned.length < 3) return undefined;
  if (cleaned.startsWith("-") || cleaned.endsWith("-")) return undefined;

  return cleaned;
}


function routeHasOriginToken(route: string, originIcao: string): boolean {
  const r = route.trim().toUpperCase();
  const o = originIcao.trim().toUpperCase();
  return r.startsWith(o + " ") || r.startsWith(o + "/");
}

function routeHasDestToken(route: string, destIcao: string): boolean {
  const r = route.trim().toUpperCase();
  const d = destIcao.trim().toUpperCase();
  // Accept: ... OMDB or ... OMDB/30R at the end
  return new RegExp(`\\b${d}(?:\\/[A-Z0-9]+)?\\s*$`, "i").test(r);
}

function withRouteEndpoints(
  route: string | undefined,
  originIcao: string | undefined,
  destIcao: string | undefined,
  depRunway: string | undefined,
  arrRunway: string | undefined
): string | undefined {
  const base = (route ?? "").trim();
  if (!base && !originIcao && !destIcao) return undefined;

  let r = base;

  if (originIcao) {
    const prefix = depRunway ? `${originIcao}/${depRunway}` : originIcao;
    if (!r) r = prefix;
    else if (!routeHasOriginToken(r, originIcao)) r = `${prefix} ${r}`.trim();
  }

  if (destIcao) {
    const suffix = arrRunway ? `${destIcao}/${arrRunway}` : destIcao;
    if (!r) r = suffix;
    else if (!routeHasDestToken(r, destIcao)) r = `${r} ${suffix}`.trim();
  }

  return r || undefined;
}

function toNumberOrUndefined(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(String(v ?? "").trim());
  return Number.isFinite(n) ? n : undefined;
}
function toMetarLineOrUndefined(v: unknown): string | undefined {
  if (typeof v !== "string") return undefined;
  const line = (v.split(/\r?\n/)[0] || "").trim();
  return line ? line : undefined;
}
function parseSimbriefCruiseFL(v: unknown): number | undefined {
  if (v == null) return undefined;

  // Common SimBrief patterns: "FL590", "590", "59000" (ft), 59000 (ft)
  if (typeof v === "string") {
    const s = v.trim().toUpperCase();
    const m = /^FL\s*(\d{2,3})$/.exec(s);
    if (m) {
      const fl = Number(m[1]);
      return Number.isFinite(fl) ? fl : undefined;
    }
    const asNum = toNumberOrUndefined(s);
    if (asNum == null) return undefined;
    if (asNum >= 1000) return Math.round(asNum / 100); // feet -> FL
    return Math.round(asNum); // treat as FL
  }

  if (typeof v === "number") {
    if (!Number.isFinite(v)) return undefined;
    if (v >= 1000) return Math.round(v / 100); // feet -> FL
    return Math.round(v);
  }

  return undefined;
}

function extractSimbrief(data: any): SimbriefExtract {
  const ofp = data?.ofp ?? data;

  const callSign =
    normalizeCallsign(ofp?.general?.callsign) ??
    normalizeCallsign(ofp?.general?.atc_callsign) ??
    normalizeCallsign(ofp?.general?.call_sign) ??
    normalizeCallsign(ofp?.general?.flight_callsign) ??
    normalizeCallsign(ofp?.atc?.callsign) ??
    normalizeCallsign(ofp?.atc?.call_sign);

  const registration =
    normalizeRegistration(ofp?.aircraft?.registration) ??
    normalizeRegistration(ofp?.aircraft?.reg) ??
    normalizeRegistration(ofp?.aircraft?.aircraft_reg) ??
    normalizeRegistration(ofp?.general?.registration) ??
    normalizeRegistration(ofp?.general?.reg) ??
    normalizeRegistration(ofp?.general?.aircraft_reg) ??
    normalizeRegistration(ofp?.general?.tail_number) ??
    normalizeRegistration(ofp?.general?.tail) ??
    normalizeRegistration(ofp?.atc?.registration);

  const originIcao =
    normalizeIcao4(ofp?.origin?.icao_code) ??
    normalizeIcao4(ofp?.origin?.icao) ??
    normalizeIcao4(ofp?.general?.origin_icao) ??
    normalizeIcao4(ofp?.general?.dep_icao);

  const destIcao =
    normalizeIcao4(ofp?.destination?.icao_code) ??
    normalizeIcao4(ofp?.destination?.icao) ??
    normalizeIcao4(ofp?.general?.destination_icao) ??
    normalizeIcao4(ofp?.general?.arr_icao);

  const depRunway =
    normalizeRunwayId(ofp?.origin?.plan_rwy) ??
    normalizeRunwayId(ofp?.origin?.planned_runway) ??
    normalizeRunwayId(ofp?.origin?.runway) ??
    normalizeRunwayId(ofp?.general?.dep_rwy) ??
    normalizeRunwayId(ofp?.general?.departure_runway) ??
    normalizeRunwayId(ofp?.general?.rwy_dep);

  const arrRunway =
    normalizeRunwayId(ofp?.destination?.plan_rwy) ??
    normalizeRunwayId(ofp?.destination?.planned_runway) ??
    normalizeRunwayId(ofp?.destination?.runway) ??
    normalizeRunwayId(ofp?.general?.arr_rwy) ??
    normalizeRunwayId(ofp?.general?.arrival_runway) ??
    normalizeRunwayId(ofp?.general?.rwy_arr);

  const alternateIcao =
    normalizeIcao4(ofp?.alternate?.icao_code) ??
    normalizeIcao4(ofp?.alternate?.icao) ??
    normalizeIcao4(ofp?.alternate?.alt_icao) ??
    normalizeIcao4(ofp?.general?.alternate_icao) ??
    normalizeIcao4(ofp?.general?.alternate) ??
    normalizeIcao4(ofp?.general?.alt_icao) ??
    normalizeIcao4(ofp?.general?.altn_icao) ??
    normalizeIcao4(ofp?.general?.alternate1_icao) ??
    normalizeIcao4(ofp?.general?.alternate2_icao);

  const routeRaw =
    ofp?.atc?.route ??
    ofp?.general?.route ??
    ofp?.general?.route_string ??
    ofp?.navlog?.route;

  const routeBase = typeof routeRaw === "string" ? routeRaw.trim() : undefined;
  const route = withRouteEndpoints(routeBase, originIcao, destIcao, depRunway, arrRunway);

  // METARs (SimBrief often includes these; if present, we can auto-fill wind components without needing a fetch)
  const depMetar =
    toMetarLineOrUndefined(ofp?.origin?.metar) ??
    toMetarLineOrUndefined(ofp?.origin?.metar_raw) ??
    toMetarLineOrUndefined(ofp?.weather?.origin_metar) ??
    toMetarLineOrUndefined(ofp?.weather?.orig_metar) ??
    toMetarLineOrUndefined(ofp?.weather?.departure_metar) ??
    toMetarLineOrUndefined(ofp?.wx?.origin_metar) ??
    toMetarLineOrUndefined(ofp?.wx?.dep_metar);

  const arrMetar =
    toMetarLineOrUndefined(ofp?.destination?.metar) ??
    toMetarLineOrUndefined(ofp?.destination?.metar_raw) ??
    toMetarLineOrUndefined(ofp?.weather?.destination_metar) ??
    toMetarLineOrUndefined(ofp?.weather?.dest_metar) ??
    toMetarLineOrUndefined(ofp?.weather?.arrival_metar) ??
    toMetarLineOrUndefined(ofp?.wx?.destination_metar) ??
    toMetarLineOrUndefined(ofp?.wx?.arr_metar);

  // Distance keys can vary across SimBrief formats.
  const dist =
    toNumberOrUndefined(ofp?.general?.route_distance) ??
    toNumberOrUndefined(ofp?.general?.distance) ??
    toNumberOrUndefined(ofp?.general?.dist_nm) ??
    toNumberOrUndefined(ofp?.general?.air_distance) ??
    toNumberOrUndefined(ofp?.general?.air_distance_nm);

  const cruiseFL =
    parseSimbriefCruiseFL(ofp?.general?.cruise_altitude) ??
    parseSimbriefCruiseFL(ofp?.general?.cruise_altitude_ft) ??
    parseSimbriefCruiseFL(ofp?.general?.crz_alt) ??
    parseSimbriefCruiseFL(ofp?.general?.initial_altitude) ??
    parseSimbriefCruiseFL(ofp?.general?.initial_altitude_ft);

  return {
    originIcao,
    destIcao,
    depRunway,
    arrRunway,
    alternateIcao,
    route,
    distanceNm: dist,
    cruiseFL,
    depMetar,
    arrMetar,
    raw: data,
    callSign,
    registration,
  };
}

async function fetchSimbrief(usernameOrId: string): Promise<SimbriefExtract> {
  const u = String(usernameOrId ?? "").trim();
  if (!u) throw new Error("Enter a SimBrief username/ID.");

  // SimBrief JSON endpoint
  const url = `https://www.simbrief.com/api/xml.fetcher.php?username=${encodeURIComponent(u)}&json=1`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error(`SimBrief fetch failed (${res.status}).`);

  const data = await res.json();
  const extracted = extractSimbrief(data);

  // Helpful error if the payload is not what we expect.
  if (!extracted.originIcao && !extracted.destIcao && !extracted.route && !extracted.distanceNm) {
    throw new Error("SimBrief response parsed, but expected fields were not found. (Check console for raw JSON)");
  }

  return extracted;
}

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

    const entry: NavaidInfo = {
      ident,
      lat,
      lon,
      type: (r?.type || "NAVAID").toString(),
      name: (r?.name || ident).toString(),
    };

    if (!navaids[ident]) navaids[ident] = [];
    navaids[ident].push(entry);
  }

  return navaids;
}

const LATLON_RE = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const AIRWAY_RE = /^[A-Z]{1,2}\d{1,3}$/;
const PROCEDURE_RE = /^(DCT|SID[A-Z0-9-]*|STAR[A-Z0-9-]*|VIA|VECTOR)$/;
function pickBestNavaidForRoute(
  ident: string,
  candidates: NavaidInfo[] | undefined,
  depInfo?: AirportInfo,
  arrInfo?: AirportInfo
): NavaidInfo | null {
  if (!candidates || candidates.length === 0) return null;
  if (!depInfo || !arrInfo) return candidates[0];

  // Choose candidate closest to the DEP->ARR corridor (min extra detour distance)
  const direct = greatCircleNM(depInfo.lat, depInfo.lon, arrInfo.lat, arrInfo.lon);

  let best = candidates[0];
  let bestExtra = Number.POSITIVE_INFINITY;

  for (const c of candidates) {
    const via =
      greatCircleNM(depInfo.lat, depInfo.lon, c.lat, c.lon) +
      greatCircleNM(c.lat, c.lon, arrInfo.lat, arrInfo.lon);
    const extra = via - direct;

    if (extra < bestExtra) {
      bestExtra = extra;
      best = c;
    }
  }
  return best;
}

function extractRouteEndpoints(tokens: string[], airportsIndex: AirportIndex): { dep?: string; arr?: string } {
  const airportTokens = tokens.filter((t) => t.length === 4 && airportsIndex?.[t]);
  if (airportTokens.length >= 2) {
    return { dep: airportTokens[0], arr: airportTokens[airportTokens.length - 1] };
  }
  return {};
}
function normalizeRouteToken(raw: string): string | null {
  const t0 = (raw || "").trim().toUpperCase();
  if (!t0) return null;

  // Remove common punctuation that shows up in OFP strings.
  const t = t0.replace(/[(),;]/g, "").replace(/\.+$/g, "");
  if (!t) return null;

  // Handle airport tokens with runway suffixes, e.g. "VIDP/27", "OMDB/30R".
  // We want the ICAO to resolve DEP/ARR correctly.
  const airportWithRw = /^([A-Z]{4})(?:\/[A-Z0-9]+)?$/;
  const m = airportWithRw.exec(t);
  if (m) return m[1];

  return t;
}

function parseRouteString(str: string): string[] {
  if (!str) return [];
  return str
    .split(/\s+/)
    .map(normalizeRouteToken)
    .filter((t): t is string => Boolean(t));
}
function resolveRouteTokens(
  tokens: string[],
  airportsIndex: AirportIndex,
  navaidsIndex: NavaidIndex,
  ctx?: { depInfo?: AirportInfo; arrInfo?: AirportInfo }
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
      points.push({ label: t, lat: parseFloat(latlon[1]), lon: parseFloat(latlon[2]) });
      continue;
    }

    if (t.length === 4 && airportsIndex?.[t]) {
      const a = airportsIndex[t];
      points.push({ label: t, lat: a.lat, lon: a.lon });
      continue;
    }

    const candidates = navaidsIndex?.[t];
    if (candidates && candidates.length > 0) {
      const best = pickBestNavaidForRoute(t, candidates, ctx?.depInfo, ctx?.arrInfo);
      if (best) {
        points.push({ label: t, lat: best.lat, lon: best.lon });
        continue;
      }
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
  <section className="efb-surface p-6 transition-colors duration-500 hover:bg-white/10">
    <div className="flex items-center justify-between mb-5">
      <h2 className="text-lg font-semibold text-white/90">{title}</h2>
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
    className={`grid gap-6 ${
      cols === 3
        ? "grid-cols-1 md:grid-cols-3"
        : cols === 4
          ? "grid-cols-2 lg:grid-cols-4"
          : "grid-cols-1 md:grid-cols-2"
    }`}
  >
    {children}
  </div>
);

type LabelProps = {
  children: ReactNode;
};

const Label = ({ children }: LabelProps) => (
  <label className="efb-label block mb-2 ml-1">{children}</label>
);

const SectionHeader = ({ children }: { children: ReactNode }) => (
  <div className="text-sm font-semibold text-white/80 mt-4 mb-2">{children}</div>
);

const Divider = () => <div className="h-px bg-white/10 my-4" />;

type InputProps = InputHTMLAttributes<HTMLInputElement>;

const Input = ({ className, ...props }: InputProps) => (
  <input
    {...props}
    className={`efb-input ${className ?? ""}`.trim()}
  />
);

type SelectProps = SelectHTMLAttributes<HTMLSelectElement>;

const Select = ({ className, ...props }: SelectProps) => (
  <select
    {...props}
    className={`efb-input appearance-none ${className ?? ""}`.trim()}
  />
);

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "ghost";
};

const Button = ({ children, variant = "primary", className, ...props }: ButtonProps) => (
  <button
    {...props}
    className={`rounded-2xl px-5 py-2.5 text-sm font-medium transition-all active:scale-95 disabled:opacity-50 disabled:pointer-events-none ${
      variant === "primary"
        ? "bg-[#0a84ff] text-white shadow-[0_14px_30px_-12px_rgba(10,132,255,0.9)] hover:bg-[#0c8fff]"
        : "bg-white/5 text-white/80 border border-white/10 hover:bg-white/10"
    } ${className ?? ""}`.trim()}
  >
    {children}
  </button>
);

type ThemeMode = "dark" | "light";

type ThemeToggleProps = {
  theme: ThemeMode;
  onToggle: () => void;
};

const ThemeToggle = ({ theme, onToggle }: ThemeToggleProps) => {
  const isLight = theme === "light";
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={isLight}
      aria-label={`Switch to ${isLight ? "dark" : "light"} mode`}
      className="theme-toggle group relative inline-flex h-7 w-28 items-center rounded-full border border-white/10 bg-white/5 p-1 text-[9px] font-semibold uppercase tracking-[0.24em] text-white/60 transition hover:bg-white/10"
    >
      <span className="pointer-events-none relative z-10 grid w-full grid-cols-2 text-center">
        <span className={`transition ${!isLight ? "text-white/90" : "text-white/50"}`}>
          Dark
        </span>
        <span className={`transition ${isLight ? "text-white/90" : "text-white/50"}`}>
          Light
        </span>
      </span>
      <span
        aria-hidden="true"
        className={`theme-toggle-thumb absolute left-1 top-1 bottom-1 w-[calc(50%-4px)] rounded-full border border-white/10 bg-white/10 shadow transition ${
          isLight ? "translate-x-full" : "translate-x-0"
        }`}
      />
    </button>
  );
};

type StatPillProps = {
  label: string;
  value: string;
  ok?: boolean;
};

function StatPill({ label, value, ok }: StatPillProps) {
  const valueClass =
    ok === undefined ? "text-white/90" : ok ? "text-emerald-300" : "text-rose-300";

  return (
    <div className="flex flex-col items-end">
      <span className="text-[10px] font-semibold uppercase tracking-[0.28em] text-white/35">
        {label}
      </span>
      <span className={`text-sm font-medium ${valueClass}`}>{value}</span>
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
      {hh}
      <span className="text-xs text-white/40">h</span> {mm}
      <span className="text-xs text-white/40">m</span>
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
      CPT: [{ ident: "CPT", lat: 51.514, lon: -1.005, type: "NAVAID", name: "CPT" }],
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

function readStoredTheme(): ThemeMode | null {
  if (typeof window === "undefined") return null;
  try {
    const stored = localStorage.getItem("efb-theme");
    if (stored === "light" || stored === "dark") return stored;
  } catch {
    // Ignore storage access failures.
  }
  return null;
}

function resolveInitialTheme(): ThemeMode {
  return readStoredTheme() ?? "dark";
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
  const [simbriefUser, setSimbriefUser] = useState<string>(() => {
    try {
      return localStorage.getItem("simbrief_user") || "";
    } catch {
      return "";
    }
  });
  const [simbriefNotice, setSimbriefNotice] = useState<string>("");
  const [simbriefCallSign, setSimbriefCallSign] = useState<string>("");
  const [simbriefRegistration, setSimbriefRegistration] = useState<string>("");
  const [simbriefLoading, setSimbriefLoading] = useState(false);
  const [simbriefImported, setSimbriefImported] = useState(false);
  const [plannedDistanceOverridden, setPlannedDistanceOverridden] = useState(false);
  const [distanceSource, setDistanceSource] = useState<"none" | "simbrief" | "auto" | "manual">("none");
  const [simbriefCruiseFL, setSimbriefCruiseFL] = useState<number | null>(null);
  const simbriefRouteSetRef = useRef(false);
  const lastAutoDistanceRef = useRef<number | null>(null);
  const cruiseFLFocusValueRef = useRef<string | null>(null);
  const cruiseFLEditedRef = useRef(false);
  const [altIcao, setAltIcao] = useState("");
  const [trimTankKg, setTrimTankKg] = useState(0);

 // Start at a valid non-RVSM level (580 is NOT valid).
const INITIAL_CRUISE_FL = 590;
const [cruiseFL, setCruiseFL] = useState<number>(INITIAL_CRUISE_FL);
const [cruiseFLText, setCruiseFLText] = useState<string>(String(INITIAL_CRUISE_FL));
const [cruiseFLNotice, setCruiseFLNotice] = useState<string>("");
// If true, user has overridden FL and we should not auto-change it from distance.
const [cruiseFLTouched, setCruiseFLTouched] = useState(false);
  const [taxiKg, setTaxiKg] = useState(2500);
  const [contingencyPct, setContingencyPct] = useState(5);
  const [finalReserveKg, setFinalReserveKg] = useState(3600);

  const [metarDep, setMetarDep] = useState("");
  const [metarArr, setMetarArr] = useState("");
  const [metarErr, setMetarErr] = useState("");

  const [tests, setTests] = useState<SelfTestResult[]>([]);
  const [showDiagnostics, setShowDiagnostics] = useState(false);
  const [appIconMode, setAppIconMode] = useState<"primary" | "fallback" | "none">("primary");
  const [theme, setTheme] = useState<ThemeMode>(resolveInitialTheme);
  const [themeStored, setThemeStored] = useState<boolean>(() => readStoredTheme() !== null);

  useEffect(() => {
    console.log(`[ConcordeEFB.tsx] ${BUILD_MARKER} v${APP_VERSION}`);
    document.title = `Concorde EFB v${APP_VERSION} • ${BUILD_MARKER}`;
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.dataset.theme = theme;
    document.body.dataset.theme = theme;
    if (themeStored) {
      try {
        localStorage.setItem("efb-theme", theme);
      } catch {
        // Ignore storage access failures.
      }
    }
  }, [theme, themeStored]);


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
    try {
      localStorage.setItem("simbrief_user", simbriefUser);
    } catch {
      // ignore
    }
  }, [simbriefUser]);

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

  const altInfo = altKey ? airports[altKey] : undefined;

  const directionEW = useMemo(() => inferDirectionEW(depInfo, arrInfo), [depInfo, arrInfo]);

  const applyCruiseFL = useCallback(
    (raw: number, note?: string) => {
      const next = normalizeCruiseFLByRules(raw, directionEW);

      // Keep both numeric + text states in sync.
      if (next !== cruiseFL) setCruiseFL(next);
      const nextText = String(next);
      if (nextText !== cruiseFLText) setCruiseFLText(nextText);

      if (typeof note === "string" && note.trim()) setCruiseFLNotice(note);
    },
    [directionEW, cruiseFL, cruiseFLText]
  );

  const plannedDistance = useMemo(() => {
    // Source of truth for *all* calculations is the Planned Distance input.
    // SimBrief/route distance is displayed separately and must never override this value.
    const manual = Number(manualDistanceNM);
    return Number.isFinite(manual) && manual > 0 ? manual : 0;
  }, [manualDistanceNM]);


  // --- Auto cruise FL from Planned Distance ---
  // Planned Distance drives the FL recommendation. We only auto-set FL when the user
  // hasn't explicitly overridden it (cruiseFLTouched === false).
  // Also: do not fight the user while they're typing in the FL box.
  const lastAppliedAutoFLRef = useRef<number | null>(null);

  const autoFLRec = useMemo(() => {
    if (!Number.isFinite(plannedDistance) || plannedDistance <= 0) return null;

    const rec = recommendCruiseFLForDistance(plannedDistance, directionEW, {
      minCruiseMin: 15,
      targetCruiseMin: 20,
    });

    if (!rec) return null;

    // Default: our model-driven recommendation
    let fl = normalizeCruiseFLByRules(rec.fl, directionEW);
    let note = rec.note;

    // Short-sector fallback: if we cannot meet minimum cruise time, prefer SimBrief cruise FL (if available).
    if (!rec.meetsMinimum && simbriefImported && Number.isFinite(simbriefCruiseFL ?? NaN)) {
      const sb = normalizeCruiseFLByRules(simbriefCruiseFL as number, directionEW);
      fl = sb;
      note = `Warning: short sector — unable to guarantee ≥15 min cruise with our profile model. Using SimBrief cruise FL${sb}.`;
    }

    return { fl, note };
  }, [plannedDistance, directionEW, simbriefImported, simbriefCruiseFL]);

  useEffect(() => {
    // Don't fight the user while they're typing.
    if (cruiseFLFocusValueRef.current !== null) return;

    // Respect manual override.
    if (cruiseFLTouched) return;

    if (!autoFLRec) return;

    const next = autoFLRec.fl;
    const nextText = String(next);

    // Guard against loops / no-op updates.
    if (
      lastAppliedAutoFLRef.current === next &&
      cruiseFL === next &&
      cruiseFLText === nextText
    ) {
      return;
    }

    lastAppliedAutoFLRef.current = next;
    setCruiseFL(next);
    setCruiseFLText(nextText);
    setCruiseFLNotice(autoFLRec.note);

    console.log("[CruiseFL:auto] applied", {
      plannedDistance,
      directionEW,
      next,
      note: autoFLRec.note,
    });
  }, [autoFLRec, plannedDistance, directionEW, cruiseFLTouched, cruiseFL, cruiseFLText]);

  useEffect(() => {
    if (!DEBUG_FL_AUTOPICK) return;

    // Log only when inputs that should affect Auto-FL change.
    console.log("[CruiseFL:dbg]", {
      plannedDistance,
      distanceSource,
      manualDistanceNM,
      routeDistanceNM,
      directionEW,
      cruiseFLTouched,
      isEditingFL: cruiseFLFocusValueRef.current !== null,
      autoFL: autoFLRec ? { fl: autoFLRec.fl, note: autoFLRec.note } : null,
      current: { cruiseFL, cruiseFLText },
    });
  }, [
    plannedDistance,
    distanceSource,
    manualDistanceNM,
    routeDistanceNM,
    directionEW,
    cruiseFLTouched,
    cruiseFL,
    cruiseFLText,
    autoFLRec,
  ]);

  useEffect(() => {
    // Always keep cruiseFL valid (clamp + Non-RVSM snap) when not typing.
    if (cruiseFLFocusValueRef.current !== null) return;

    const base = Number.isFinite(cruiseFL) ? cruiseFL : Number(cruiseFLText);
    const next = normalizeCruiseFLByRules(base, directionEW);
    const nextText = String(next);

    if (next !== cruiseFL) setCruiseFL(next);
    if (nextText !== cruiseFLText) setCruiseFLText(nextText);
  }, [directionEW, cruiseFL, cruiseFLText]);

  const climb = useMemo(() => estimateClimb(Math.max(clampCruiseFL(cruiseFL), 0) * 100), [cruiseFL]);
  const descent = useMemo(() => estimateDescent(Math.max(clampCruiseFL(cruiseFL), 0) * 100), [cruiseFL]);

  const reheat = useMemo(() => reheatGuard(climb.time_h), [climb.time_h]);

  const burnKgPerNmAdj = useMemo(
    () => CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(clampCruiseFL(cruiseFL)),
    [cruiseFL]
  );

  const cruiseNM = useMemo(() => {
    const nm = plannedDistance - (climb.dist_nm + descent.dist_nm);
    return Math.max(nm, 0);
  }, [plannedDistance, climb.dist_nm, descent.dist_nm]);

  const cruiseTimeH = useMemo(() => {
    try {
      return cruiseTimeHours(cruiseNM);
    } catch {
      return 0;
    }
  }, [cruiseNM]);

  const totalTimeH = useMemo(
    () => (climb.time_h || 0) + (cruiseTimeH || 0) + (descent.time_h || 0),
    [climb.time_h, cruiseTimeH, descent.time_h]
  );

  const eteHours = totalTimeH;

  const burnKgPerHour = useMemo(
    () => Math.max(burnKgPerNmAdj * CONSTANTS.speeds.cruise_tas_kt, 1),
    [burnKgPerNmAdj]
  );

  const reserveTimeH = useMemo(() => {
    const fr = Number(finalReserveKg);
    if (!Number.isFinite(fr) || fr <= 0) return 0;
    return fr / burnKgPerHour;
  }, [finalReserveKg, burnKgPerHour]);

  const enduranceHours = useMemo(() => {
    return CONSTANTS.weights.fuel_capacity_kg / burnKgPerHour;
  }, [burnKgPerHour]);

  const enduranceMeets = enduranceHours >= eteHours + reserveTimeH;

  const alternateDistanceNM = useMemo(() => {
    if (!arrInfo || !altInfo) return 0;
    return greatCircleNM(arrInfo.lat, arrInfo.lon, altInfo.lat, altInfo.lon);
  }, [arrInfo, altInfo]);

  const tripKg = useMemo(() => {
    // Heuristic: climb burns more, descent burns less
    const climbKg = climb.dist_nm * burnKgPerNmAdj * CONSTANTS.fuel.climb_factor;
    const cruiseKg = cruiseNM * burnKgPerNmAdj;
    const descKg = descent.dist_nm * burnKgPerNmAdj * CONSTANTS.fuel.descent_factor;
    return Math.max(climbKg + cruiseKg + descKg, 0);
  }, [climb.dist_nm, cruiseNM, descent.dist_nm, burnKgPerNmAdj]);

  const blocks = useMemo(() => {
    return blockFuelKg({
      tripKg,
      taxiKg,
      contingencyPct,
      finalReserveKg,
      alternateNM: alternateDistanceNM,
      burnKgPerNm: burnKgPerNmAdj,
    });
  }, [tripKg, taxiKg, contingencyPct, finalReserveKg, alternateDistanceNM, burnKgPerNmAdj]);

  const totalFuelRequiredKg = useMemo(() => {
    const t = Number(trimTankKg) || 0;
    return (blocks.block_kg || 0) + t;
  }, [blocks.block_kg, trimTankKg]);

  const fuelCapacityKg = CONSTANTS.weights.fuel_capacity_kg;
  const fuelWithinCapacity = totalFuelRequiredKg <= fuelCapacityKg;
  const fuelExcessKg = Math.max(totalFuelRequiredKg - fuelCapacityKg, 0);

  const paxKg = CONSTANTS.weights.pax_full_count * CONSTANTS.weights.pax_mass_kg;
  const tkoWeightKgAuto = useMemo(() => {
    return CONSTANTS.weights.oew_kg + paxKg + totalFuelRequiredKg;
  }, [paxKg, totalFuelRequiredKg]);

  const tkSpeeds = useMemo(() => computeTakeoffSpeeds(tkoWeightKgAuto), [tkoWeightKgAuto]);

  const estLandingWeightKg = useMemo(() => {
    const lw = tkoWeightKgAuto - tripKg;
    return Math.max(lw, 0);
  }, [tkoWeightKgAuto, tripKg]);

  const ldSpeeds = useMemo(() => computeLandingSpeeds(estLandingWeightKg), [estLandingWeightKg]);

  const depRunway = useMemo(() => {
    if (!depInfo || !depRw) return null;
    return depInfo.runways.find((r) => r.id === depRw) ?? null;
  }, [depInfo, depRw]);

  const arrRunway = useMemo(() => {
    if (!arrInfo || !arrRw) return null;
    return arrInfo.runways.find((r) => r.id === arrRw) ?? null;
  }, [arrInfo, arrRw]);

  const depWind = useMemo(() => {
    const parsed = parseMetarWind(metarDep || "");
    const comps = windComponents(parsed.wind_dir_deg, parsed.wind_speed_kt, depRunway?.heading ?? 0);
    return { parsed, comps };
  }, [metarDep, depRunway?.heading]);

  const arrWind = useMemo(() => {
    const parsed = parseMetarWind(metarArr || "");
    const comps = windComponents(parsed.wind_dir_deg, parsed.wind_speed_kt, arrRunway?.heading ?? 0);
    return { parsed, comps };
  }, [metarArr, arrRunway?.heading]);

  const tkoCheck = useMemo(() => {
    const len = depRunway?.length_m ?? 0;
    return takeoffFeasibleM(len, tkoWeightKgAuto);
  }, [depRunway?.length_m, tkoWeightKgAuto]);

  const ldgCheck = useMemo(() => {
    const len = arrRunway?.length_m ?? 0;
    return landingFeasibleM(len, estLandingWeightKg);
  }, [arrRunway?.length_m, estLandingWeightKg]);

  const passCount = useMemo(() => tests.filter((t) => t.pass).length, [tests]);
  const failedTests = useMemo(() => tests.filter((t) => !t.pass), [tests]);

  function computeRouteDistanceFromText(text: string): {
    distanceNM: number;
    distanceNM_raw: number;
    detour_factor: number;
    resolution: RouteResolution;
    depFromRoute?: string;
    arrFromRoute?: string;
  } | null {
    const tokens = parseRouteString(text);
    const { dep: depFromRoute, arr: arrFromRoute } = extractRouteEndpoints(tokens, airports);

    const depForCalc = (depFromRoute ? airports[depFromRoute] : depInfo) ?? undefined;
    const arrForCalc = (arrFromRoute ? airports[arrFromRoute] : arrInfo) ?? undefined;
    if (!depForCalc || !arrForCalc) return null;

    // Remove endpoints from the middle so they don't get double-counted.
    const filtered = tokens.filter((t) => t !== depFromRoute && t !== arrFromRoute);

    const resolution = resolveRouteTokens(filtered, airports, navaids, {
      depInfo: depForCalc,
      arrInfo: arrForCalc,
    });

    const distanceNM_raw = computeRouteDistanceNM(depForCalc, arrForCalc, resolution.points);

    // Fallback: if we couldn't resolve many actual waypoints (common when the DB lacks intersections),
    // apply a small detour factor based on the number of airway/procedure tokens.
    // This usually brings us closer to SimBrief's routed distance vs pure great-circle.
    let detour_factor = 1;
    const airwayCount = resolution.recognized.airways.length;
    const procCount = resolution.recognized.procedures.length;
    const resolvedPts = resolution.points.length;

    if (resolvedPts <= 1 && (airwayCount > 0 || procCount > 0)) {
      // 1% per airway token + 2% per procedure token, capped at +18%.
      detour_factor = 1 + Math.min(0.18, 0.01 * airwayCount + 0.02 * procCount);
    }

    const distanceNM = distanceNM_raw * detour_factor;

    return { distanceNM, distanceNM_raw, detour_factor, resolution, depFromRoute, arrFromRoute };
  }

  // SimBrief import handler moved out of applyRouteDistance.
  const importFromSimbrief = async () => {
    setSimbriefNotice("");
    setSimbriefImported(false);
    setSimbriefCallSign("");
    setSimbriefRegistration("");

    const u = simbriefUser.trim();
    if (!u) {
      setSimbriefNotice("Enter your SimBrief username/ID first.");
      return;
    }

    setSimbriefLoading(true);
    try {
      const extracted = await fetchSimbrief(u);
      // For debugging in case SimBrief changes fields.
      console.log("SimBrief raw JSON:", extracted.raw);
      setSimbriefCruiseFL(Number.isFinite(extracted.cruiseFL as number) ? (extracted.cruiseFL as number) : null);

      if (extracted.callSign) setSimbriefCallSign(extracted.callSign);
      if (extracted.registration) setSimbriefRegistration(extracted.registration);

      if (extracted.originIcao) {
        setDepIcao(extracted.originIcao);
        setDepRw("");
      }
      if (extracted.destIcao) {
        setArrIcao(extracted.destIcao);
        setArrRw("");
      }
      if (extracted.alternateIcao) {
        setAltIcao(extracted.alternateIcao);
      }

      // If SimBrief provides planned runways, try to apply them.
      // (If our runway DB doesn't contain the exact ID, the dropdown may stay blank —
      // but the route string will still show the runway suffixes.)
      if (extracted.depRunway) setDepRw(extracted.depRunway);
      if (extracted.arrRunway) setArrRw(extracted.arrRunway);

      // Auto-fill METARs from SimBrief (if available) so wind components populate immediately.
      if (extracted.depMetar) setMetarDep(extracted.depMetar);
      if (extracted.arrMetar) setMetarArr(extracted.arrMetar);
      if (extracted.depMetar || extracted.arrMetar) setMetarErr("");

      const hasSimbriefDistance = typeof extracted.distanceNm === "number" && extracted.distanceNm > 0;

      if (extracted.route) {
        // If SimBrief provided a distance, we will trust it and avoid auto-recomputing once.
        if (hasSimbriefDistance) simbriefRouteSetRef.current = true;
        setRouteText(extracted.route);
      }

      if (hasSimbriefDistance) {
        const rounded = Math.round(extracted.distanceNm!);
        setManualDistanceNM(rounded);
        setRouteDistanceNM(extracted.distanceNm!);
        setRouteInfo(null);
        setRouteNotice("");
        setDistanceSource("simbrief");
        setPlannedDistanceOverridden(false);
        lastAutoDistanceRef.current = null;

        // IMPORTANT: SimBrief distance should drive auto-FL again.
        setCruiseFLTouched(false);
        setCruiseFLNotice("");
      } else {
        // No distance in the SimBrief JSON; we'll auto-estimate from the route string.
        // Keep the estimated distance visible and let Planned Distance be re-derived from it.
        setDistanceSource("auto");
        setPlannedDistanceOverridden(false);
        setRouteNotice("");
        setManualDistanceNM(0);
        lastAutoDistanceRef.current = null;

        // IMPORTANT: allow auto-FL to re-run once Planned Distance is derived.
        setCruiseFLTouched(false);
        setCruiseFLNotice("");
      }

      setSimbriefImported(true);

      const dep = extracted.originIcao ? ` ${extracted.originIcao}` : "";
      const arr = extracted.destIcao ? ` → ${extracted.destIcao}` : "";
      const alt = extracted.alternateIcao ? ` (ALT ${extracted.alternateIcao})` : "";
      setSimbriefNotice(`Imported SimBrief OFP${dep}${arr}${alt}.`);
    } catch (e) {
      setSimbriefNotice(String(e));
    } finally {
      setSimbriefLoading(false);
    }
  };
  useEffect(() => {
    const text = (routeText || "").trim();
    if (!text) {
      setRouteDistanceNM(null);
      if (distanceSource === "auto") setDistanceSource("none");
      return;
    }

    // Only auto-compute route distance when we're explicitly in auto mode.
    // This prevents manual Planned Distance edits from overwriting the imported/estimated route distance.
    if (distanceSource !== "auto") return;

    const t = window.setTimeout(() => {
      // Skip one auto-calc right after a SimBrief import that already set a distance.
      if (simbriefRouteSetRef.current) {
        simbriefRouteSetRef.current = false;
        return;
      }

      const out = computeRouteDistanceFromText(text);
      if (!out) {
        setRouteDistanceNM(null);
        return;
      }

      setRouteDistanceNM(out.distanceNM);
      setDistanceSource("auto");

      // Only auto-update Planned Distance if the user hasn't overridden it manually.
      const rounded = Math.round(out.distanceNM);
      if (manualDistanceNM === 0 || manualDistanceNM === (lastAutoDistanceRef.current ?? -1)) {
        setManualDistanceNM(rounded);
        lastAutoDistanceRef.current = rounded;
      }
    }, 300);

    return () => window.clearTimeout(t);
  }, [routeText, airports, navaids, depInfo, arrInfo, manualDistanceNM, distanceSource]);

  function applyRouteDistance() {
    setRouteNotice("");

    if (!routeText.trim()) {
      setRouteNotice("Paste a route string first.");
      return;
    }

    const out = computeRouteDistanceFromText(routeText);
    if (!out) {
      setRouteNotice(
        "Could not compute route distance. Ensure Nav DB is loaded, and either set DEP/ARR or include airport ICAOs inside the route."
      );
      return;
    }

    if (out.depFromRoute && out.arrFromRoute) {
      if (out.depFromRoute !== depKey) {
        setDepIcao(out.depFromRoute);
        setDepRw("");
      }
      if (out.arrFromRoute !== arrKey) {
        setArrIcao(out.arrFromRoute);
        setArrRw("");
      }
    }

    const rounded = Math.round(out.distanceNM);
    setRouteDistanceNM(out.distanceNM);
    setRouteInfo(out.resolution);
    setManualDistanceNM(rounded);

    const unresolved = out.resolution.recognized.unresolved.length;
    const parts: string[] = [`Planned Distance set to ${rounded.toLocaleString()} NM.`];

    if (out.depFromRoute && out.arrFromRoute) {
      parts.push(`Derived DEP/ARR: ${out.depFromRoute} → ${out.arrFromRoute}.`);
    }

    if (out.detour_factor > 1.001) {
      const pct = Math.round((out.detour_factor - 1) * 100);
      parts.push(`Applied airway detour factor (+${pct}%) due to limited waypoint resolution.`);
    }

    if (unresolved > 0) parts.push("Some waypoints couldn’t be resolved; distance is approximate.");
    setRouteNotice(parts.join(" "));
  }

  const metricBox = "efb-metric flex flex-col justify-center";
  const metricLabel = "text-[10px] uppercase tracking-[0.24em] text-white/40";
  const metricValue = "text-lg font-semibold text-white/90 tabular-nums";

  return (
    <div className="relative min-h-screen text-slate-100">
      <div className="pointer-events-none fixed inset-0 -z-10">
        <div className="absolute -top-24 left-1/2 h-72 w-[52rem] -translate-x-1/2 rounded-full bg-sky-500/10 blur-[140px]" />
        <div className="absolute top-1/3 left-8 h-60 w-60 rounded-full bg-cyan-400/10 blur-[120px]" />
        <div className="absolute bottom-24 right-8 h-64 w-64 rounded-full bg-slate-500/20 blur-[140px]" />
      </div>

      <div className="mx-auto max-w-7xl px-6 pb-16 pt-8 space-y-8">
        <header className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-4">
            {appIconMode !== "none" ? (
              <img
                src={appIconMode === "primary" ? APP_ICON_SRC_PRIMARY : APP_ICON_SRC_FALLBACK}
                alt="Concorde EFB"
                className="h-20 w-20 object-contain shrink-0 rounded-2xl border border-white/10 bg-white/5 p-2 shadow-[0_12px_30px_-18px_rgba(0,0,0,0.8)]"
                onError={(e) => {
                  const failedSrc = (e.currentTarget as HTMLImageElement).src;
                  console.warn("App icon failed to load:", failedSrc);

                  // 1st failure: switch to fallback icon.png
                  // 2nd failure: show the simple SVG placeholder
                  setAppIconMode((prev) => (prev === "primary" ? "fallback" : "none"));
                }}
                draggable={false}
              />
            ) : (
              <div className="h-20 w-20 flex items-center justify-center shrink-0 rounded-2xl border border-white/10 bg-white/5">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  className="h-8 w-8 text-white/80"
                  aria-hidden="true"
                >
                  <path d="M21.5 13.5c.3 0 .5.2.5.5v1a1 1 0 0 1-1 1H14l-2.2 3.6a1 1 0 0 1-1.8-.5V16H6l-1.2 1.2a1 1 0 0 1-1.7-.7V15a1 1 0 0 1 .3-.7L6 12 3.4 9.7a1 1 0 0 1-.3-.7V7.5a1 1 0 0 1 1.7-.7L6 8h3.9V4.4a1 1 0 0 1 1.8-.5L14 7.5h7a1 1 0 0 1 1 1v1c0 .3-.2.5-.5.5H14v3.5h7Z" />
                </svg>
              </div>
            )}

            <div>
              <div className="text-3xl font-semibold tracking-tight text-white">Concorde EFB</div>
              <div className="text-sm text-white/45">Flight planning & performance for MSFS.</div>
              <div className="mt-3 flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-[0.3em] text-white/35">
                <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
                  v{APP_VERSION}
                </span>
                <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
                  Build {BUILD_MARKER}
                </span>
              </div>
            </div>
          </div>
          <div className="flex flex-col items-end gap-3">
            <ThemeToggle
              theme={theme}
              onToggle={() => {
                setThemeStored(true);
                setTheme(theme === "light" ? "dark" : "light");
              }}
            />
            <div className="flex flex-wrap justify-end gap-6">
              <StatPill label="Nav DB" value={dbLoaded ? "Loaded" : "Loading"} ok={dbLoaded} />
              <StatPill label="TAS" value={`${CONSTANTS.speeds.cruise_tas_kt} kt`} />
              <StatPill label="MTOW" value={`${CONSTANTS.weights.mtow_kg.toLocaleString()} kg`} />
              <StatPill label="MLW" value={`${CONSTANTS.weights.mlw_kg.toLocaleString()} kg`} />
              <StatPill label="Fuel cap" value={`${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg`} />
            </div>
          </div>
        </header>

        <main className="space-y-8">
          {dbError && (
            <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-xs text-rose-200">
              Nav DB load error: {dbError}
            </div>
          )}

          <Card title="FLIGHT PLAN">
            <div className="space-y-6">
              <Label>SimBrief Username / ID (optional)</Label>
              <div className="grid gap-6 sm:grid-cols-12 items-start">
                <div className="sm:col-span-4">
                  <Input
                    className="h-12 text-sm"
                    value={simbriefUser}
                    placeholder="SimBrief username"
                    onChange={(e) => setSimbriefUser(e.target.value)}
                  />
                </div>

                <div className="sm:col-span-2">
                  <Button
                    className="h-12 px-4 text-sm w-full whitespace-nowrap"
                    onClick={importFromSimbrief}
                    disabled={simbriefLoading}
                  >
                    <span className="inline-flex items-center justify-center gap-2 w-full">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 24 24"
                        fill="currentColor"
                        className="h-4 w-4"
                        aria-hidden="true"
                      >
                        <path d="M12 3a1 1 0 0 1 1 1v8.586l2.293-2.293a1 1 0 1 1 1.414 1.414l-4.007 4.007a1 1 0 0 1-1.4.012l-4.02-4.02a1 1 0 1 1 1.414-1.414L11 12.586V4a1 1 0 0 1 1-1Z" />
                        <path d="M5 20a1 1 0 0 1-1-1v-2a1 1 0 1 1 2 0v1h12v-1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1H5Z" />
                      </svg>
                      {simbriefLoading ? "Importing…" : "Import"}
                    </span>
                  </Button>
                </div>

                <div className="hidden sm:block sm:col-span-6">
                  <div className="grid grid-cols-2 gap-4">
                    <div
                      className={`h-12 px-4 rounded-2xl border flex items-center justify-center min-w-0 text-center ${
                        simbriefImported
                          ? "bg-[#348939]/45 border-[#348939] shadow-[0_0_30px_rgba(52,137,57,0.55)]"
                          : "bg-white/5 border-white/10"
                      }`}
                    >
                      <div className="min-w-0 text-center">
                        <div className="text-[10px] uppercase tracking-[0.28em] text-white/40">
                          Call Sign
                        </div>
                        <div
                          className={`text-sm font-semibold truncate ${
                            simbriefImported ? "text-white" : "text-white/90"
                          }`}
                        >
                          {simbriefImported ? (simbriefCallSign || "—") : "—"}
                        </div>
                      </div>
                    </div>

                    <div
                      className={`h-12 px-4 rounded-2xl border flex items-center justify-center min-w-0 text-center ${
                        simbriefImported
                          ? "bg-[#FDBF02]/45 border-[#FDBF02] shadow-[0_0_30px_rgba(253,191,2,0.55)]"
                          : "bg-white/5 border-white/10"
                      }`}
                    >
                      <div className="min-w-0 text-center">
                        <div className="text-[10px] uppercase tracking-[0.28em] text-white/40">
                          Registration
                        </div>
                        <div
                          className={`text-sm font-semibold truncate ${
                            simbriefImported ? "text-white" : "text-white/90"
                          }`}
                        >
                          {simbriefImported ? (simbriefRegistration || "—") : "—"}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="sm:col-span-9">
                  <textarea
                    className="efb-input h-12 text-xs leading-tight resize-none overflow-y-auto"
                    placeholder="Route will auto-fill from SimBrief (or paste here)"
                    value={routeText}
                    onChange={(e) => {
                      setDistanceSource("auto");
                      setPlannedDistanceOverridden(false);
                      setRouteText(e.target.value);
                    }}
                  />

                </div>

                <div className="sm:col-span-3">
                  <div className={`${metricBox} h-12`}>
                    <div className={metricLabel}>Estimated Route Distance</div>
                    <div className="text-sm font-semibold text-white/90 tabular-nums">
                      {routeDistanceNM != null
                        ? `${Math.round(routeDistanceNM).toLocaleString()} NM`
                        : "—"}
                    </div>
                  </div>

                </div>
              </div>

              <div className="grid grid-cols-12 gap-6 -mt-2">
                <div className="col-span-12 sm:col-span-9">
                  {simbriefNotice && (
                    <div
                      className={`text-xs ${
                        simbriefNotice.startsWith("Imported")
                          ? "text-emerald-300"
                          : "text-rose-300"
                      }`}
                    >
                      {simbriefNotice}
                    </div>
                  )}
                </div>
                <div className="col-span-12 sm:col-span-3 text-left sm:text-right">
                  {simbriefImported && !plannedDistanceOverridden && distanceSource === "simbrief" && (
                    <div className="text-xs text-emerald-300">Imported from SimBrief</div>
                  )}
                  {simbriefImported && plannedDistanceOverridden && (
                    <div className="text-xs text-amber-200">
                      Imported from SimBrief • Planned Distance overridden
                    </div>
                  )}
                </div>
              </div>

              {routeNotice && (
                <div className="text-xs text-white/45">{routeNotice}</div>
              )}
            </div>
          </Card>

          <Card title="CRUISE & FUEL MANAGEMENT">
            <Row>
              <div>
                <Label>Planned Distance (NM)</Label>
                <Input
                  type="number"
                  value={manualDistanceNM}
                  onChange={(e) => {
                    if (simbriefImported) setPlannedDistanceOverridden(true);
                    lastAutoDistanceRef.current = null;

                    const next = parseFloat(e.target.value || "0");
                    setManualDistanceNM(Number.isFinite(next) ? next : 0);
                    setCruiseFLTouched(false);
                    setCruiseFLNotice("");
                  }}
                />
                <div className="text-xs text-white/45 mt-2">
                  {simbriefImported
                    ? "SimBrief imported: you can override Planned Distance manually (this won’t change the imported route distance shown above)."
                    : "Enter distance from your flight planner. We’ll compute Climb/Cruise/Descent from this and FL."}
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
                    setCruiseFLText(next);

                    if (cruiseFLFocusValueRef.current !== null && next !== cruiseFLFocusValueRef.current) {
                      cruiseFLEditedRef.current = true;
                    }

                    const n = Number(next);
                    if (Number.isFinite(n)) setCruiseFL(n);
                  }}
                  onFocus={() => {
                    cruiseFLFocusValueRef.current = cruiseFLText;
                    cruiseFLEditedRef.current = false;
                  }}
                  onBlur={() => {
                    const n = Number(cruiseFLText);
                    if (!Number.isFinite(n)) {
                      setCruiseFLNotice("Invalid FL value.");
                      setCruiseFLText(String(cruiseFL));
                      cruiseFLFocusValueRef.current = null;
                      return;
                    }
                    applyCruiseFL(n);
                    cruiseFLFocusValueRef.current = null;
                    if (cruiseFLEditedRef.current) setCruiseFLTouched(true);
                  }}
                />
                <div className="text-xs text-white/45 mt-2">
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
                      cruiseFLNotice.startsWith("Invalid")
                        ? "text-rose-300"
                        : cruiseFLNotice.startsWith("Adjusted")
                        ? "text-amber-200"
                        : "text-white/50"
                    }`}
                  >
                    {cruiseFLNotice}
                  </div>
                )}
              </div>
            </Row>

            <div className="mt-6 grid gap-4 lg:grid-cols-[1.1fr_2fr]">
              <div className={`${metricBox} lg:border-r lg:border-white/10`}>
                <div className={metricLabel}>Total Flight Time</div>
                <div className={metricValue}>
                  <HHMM hours={totalTimeH} />
                </div>
              </div>
              <div className="grid gap-4 sm:grid-cols-3">
                <div className={metricBox}>
                  <div className={metricLabel}>Climb</div>
                  <div className={metricValue}>
                    <HHMM hours={climb.time_h} />
                  </div>
                </div>
                <div className={metricBox}>
                  <div className={metricLabel}>Cruise</div>
                  <div className={metricValue}>
                    <HHMM hours={cruiseTimeH} />
                  </div>
                </div>
                <div className={metricBox}>
                  <div className={metricLabel}>Descent</div>
                  <div className={metricValue}>
                    <HHMM hours={descent.time_h} />
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-6 grid gap-6 lg:grid-cols-[1.3fr_0.7fr]">
              <div className="space-y-6">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <Label>Taxi Fuel (kg)</Label>
                    <Input type="number" value={taxiKg} onChange={(e) => setTaxiKg(parseFloat(e.target.value || "0"))} />
                  </div>
                  <div>
                    <Label>Contingency (%)</Label>
                    <Input type="number" value={contingencyPct} onChange={(e) => setContingencyPct(parseFloat(e.target.value || "0"))} />
                  </div>
                  <div>
                    <Label>Final Reserve (kg)</Label>
                    <Input type="number" value={finalReserveKg} onChange={(e) => setFinalReserveKg(parseFloat(e.target.value || "0"))} />
                  </div>
                  <div className="space-y-3">
                    <div>
                      <Label>Trim Tank Fuel (kg)</Label>
                      <Input type="number" value={trimTankKg} onChange={(e) => setTrimTankKg(parseFloat(e.target.value || "0"))} />
                    </div>
                    <div className="h-px bg-white/10" />
                    <div>
                      <Label>Alternate ICAO</Label>
                      <Input value={altIcao} onChange={(e) => setAltIcao(e.target.value.toUpperCase())} />
                      <div className="text-xs text-white/45 mt-2">
                        ARR → ALT distance: <b>{Math.round(alternateDistanceNM || 0).toLocaleString()}</b> NM
                      </div>
                    </div>
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                  <div className={metricBox}>
                    <div className={metricLabel}>Computed TOW</div>
                    <div className={metricValue}>{Math.round(tkoWeightKgAuto).toLocaleString()} kg</div>
                  </div>
                  <div className={`efb-metric flex flex-col justify-center ${enduranceMeets ? "" : "border-rose-500/40"}`}>
                    <div className={metricLabel}>Fuel Endurance</div>
                    <div className={metricValue}>
                      <HHMM hours={enduranceHours} />
                    </div>
                  </div>
                  <div className={`efb-metric ${enduranceMeets ? "border-emerald-500/30" : "border-rose-500/40"}`}>
                    <div className={metricLabel}>ETE + Reserves</div>
                    <div className={metricValue}>
                      <HHMM hours={eteHours + reserveTimeH} />
                    </div>
                  </div>
                  <div className={`efb-metric ${enduranceMeets ? "border-emerald-500/30" : "border-rose-500/40"}`}>
                    <div className={metricLabel}>ETE + Reserves</div>
                    <div className={metricValue}>
                      <HHMM hours={eteHours + reserveTimeH} />
                    </div>
                  </div>
                </div>
                <div className={`text-xs ${reheat.within_cap ? "text-white/45" : "text-rose-300"}`}>
                  Reheat safety: climb reheat within {CONSTANTS.fuel.reheat_minutes_cap} min cap.
                </div>
                {!enduranceMeets && (
                  <div className="text-xs text-rose-300">
                    Fuel endurance is less than required ETE + reserves.
                  </div>
                )}
              </div>

              <div className="rounded-3xl border border-white/10 bg-black/30 p-5 space-y-3">
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/70">Trip Fuel</span>
                  <span className="text-xl font-mono text-white/95">{Math.round(tripKg).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/50">Taxi Fuel</span>
                  <span className="text-base font-mono text-white/85">{Math.round(taxiKg || 0).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/50">Contingency</span>
                  <span className="text-base font-mono text-white/85">{Math.round(blocks.contingency_kg || 0).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/50">Trim Fuel</span>
                  <span className="text-base font-mono text-white/85">{Math.round(trimTankKg || 0).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/50">Alt Fuel ({Math.round(alternateDistanceNM || 0)} NM)</span>
                  <span className="text-base font-mono text-white/85">{Math.round((alternateDistanceNM || 0) * CONSTANTS.fuel.burn_kg_per_nm).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-white/10">
                  <span className="text-sm text-white/70 font-medium">Block Fuel</span>
                  <span className="text-xl font-mono text-white">{Math.round(blocks.block_kg).toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center py-1 pt-3">
                  <div className="flex flex-col">
                    <span className="text-sm text-white/70 font-medium">Total Required</span>
                    <span className="text-[10px] text-white/40">Block + Trim ({trimTankKg} kg)</span>
                  </div>
                  <div className="text-right">
                    <span className={`text-2xl font-mono ${fuelWithinCapacity ? "text-emerald-400" : "text-rose-400"}`}>
                      {Number.isFinite(blocks.block_kg) ? Math.round(blocks.block_kg + (trimTankKg || 0)).toLocaleString() : "—"}
                    </span>
                    <span className="text-sm text-white/50 ml-1">kg</span>
                  </div>
                </div>
              </div>
            </div>

            {!fuelWithinCapacity && (
              <div className="mt-3 text-xs text-rose-300">
                Warning: Total fuel <b>{Math.round(totalFuelRequiredKg).toLocaleString()} kg</b> exceeds Concorde fuel capacity{" "}
                <b>{Math.round(fuelCapacityKg).toLocaleString()} kg</b> by <b>{Math.round(fuelExcessKg).toLocaleString()} kg</b>. Reduce block or trim fuel to stay within limits.
              </div>
            )}
          </Card>

          <Card
            title="PERFORMANCE CALCULATOR"
            right={
              <Button
                onClick={async () => {
                  setMetarErr("");
                  const dep = depKey;
                  const arr = arrKey;

                  if (!dep || dep.length !== 4 || !arr || arr.length !== 4) {
                    setMetarErr("Enter valid DEP and ARR ICAOs first.");
                    return;
                  }

                  const [d, a] = await Promise.all([fetchMetarByICAO(dep), fetchMetarByICAO(arr)]);

                  const errs: string[] = [];
                  if (d.ok) setMetarDep(d.raw);
                  else errs.push(d.error);

                  if (a.ok) setMetarArr(a.raw);
                  else errs.push(a.error);

                  if (errs.length) setMetarErr(errs.join(" | "));
                }}
              >
                Fetch METARs
              </Button>
            }
          >
            <SectionHeader>Airports & Runways</SectionHeader>
            {metarErr && <div className="text-xs text-rose-300 mt-2">METAR fetch error: {metarErr}</div>}
            <div className="grid gap-5 lg:grid-cols-2">
              <div className="space-y-3">
                <div className="grid gap-3 sm:grid-cols-2">
                  <div>
                    <Label>Departure ICAO</Label>
                    <Input
                      value={depIcao}
                      onChange={(e) => setDepIcao(e.target.value.toUpperCase())}
                    />
                  </div>
                  <div>
                    <Label>Departure Runway</Label>
                    <Select value={depRw} onChange={(e) => setDepRw(e.target.value)}>
                      <option value="">—</option>
                      {(depInfo?.runways ?? []).map((r) => (
                        <option key={`dep-${r.id}`} value={r.id}>
                          {`RWY ${r.id} • ${Number(r.length_m || 0).toLocaleString()} m • ${Math.round(
                            Number(r.heading || 0)
                          )}°`}
                        </option>
                      ))}
                    </Select>
                  </div>
                </div>
                <div className={`rounded-2xl border px-4 py-3 ${
                  depWind.parsed.wind_gust_kt
                    ? "border-amber-400/40 bg-amber-500/10"
                    : "border-emerald-400/30 bg-emerald-500/10"
                }`}>
                  <div className="flex items-center justify-between text-[10px] uppercase tracking-[0.28em] text-white/60">
                    <span>DEP METAR</span>
                    <span className="text-white/60">{depIcao}{depRunway ? ` ${depRunway.id}` : ""}</span>
                  </div>
                  <div className="mt-2 text-xs text-white/90 font-mono break-words">
                    {metarDep || "—"}
                  </div>
                </div>
              </div>

              <div className="space-y-3">
                <div className="grid gap-3 sm:grid-cols-2">
                  <div>
                    <Label>Arrival ICAO</Label>
                    <Input
                      value={arrIcao}
                      onChange={(e) => setArrIcao(e.target.value.toUpperCase())}
                    />
                  </div>
                  <div>
                    <Label>Arrival Runway</Label>
                    <Select value={arrRw} onChange={(e) => setArrRw(e.target.value)}>
                      <option value="">—</option>
                      {(arrInfo?.runways ?? []).map((r) => (
                        <option key={`arr-${r.id}`} value={r.id}>
                          {`RWY ${r.id} • ${Number(r.length_m || 0).toLocaleString()} m • ${Math.round(
                            Number(r.heading || 0)
                          )}°`}
                        </option>
                      ))}
                    </Select>
                  </div>
                </div>
                <div className={`rounded-2xl border px-4 py-3 ${
                  arrWind.parsed.wind_gust_kt
                    ? "border-amber-400/40 bg-amber-500/10"
                    : "border-emerald-400/30 bg-emerald-500/10"
                }`}>
                  <div className="flex items-center justify-between text-[10px] uppercase tracking-[0.28em] text-white/60">
                    <span>ARR METAR</span>
                    <span className="text-white/60">{arrIcao}{arrRunway ? ` ${arrRunway.id}` : ""}</span>
                  </div>
                  <div className="mt-2 text-xs text-white/90 font-mono break-words">
                    {metarArr || "—"}
                  </div>
                </div>
              </div>
            </div>

            <Divider />

            <div className="grid gap-6 lg:grid-cols-2">
              {/*
                Landing limits are based on runway length and MLW.
                Keep the visual treatment in sync with the computed feasibility.
              */}
              {/**/}
              <div className={`rounded-3xl border p-5 space-y-4 ${
                tkoCheck.feasible
                  ? "border-white/10 bg-black/30"
                  : "border-rose-500/60 bg-rose-500/15 shadow-[0_0_45px_rgba(244,63,94,0.35)]"
              }`}>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-[0.28em] text-white/70">TAKEOFF PERFORMANCE</div>
                    <div className="text-2xl font-semibold text-white/90 mt-2">
                      {Math.round(tkoWeightKgAuto).toLocaleString()}
                      <span className="text-sm text-white/40"> kg</span>
                    </div>
                  </div>
                  <div
                    className={`text-[11px] font-semibold px-3 py-1 rounded-full border ${
                      tkoCheck.feasible
                        ? "border-emerald-400/40 text-emerald-300 bg-emerald-500/10"
                        : "border-rose-400/40 text-rose-300 bg-rose-500/10"
                    }`}
                  >
                    {tkoCheck.feasible ? "WITHIN LIMITS" : "RUNWAY TOO SHORT"}
                  </div>
                </div>
                <div className="grid grid-cols-3 gap-3">
                  <div className={metricBox}>
                    <div className={metricLabel}>V1</div>
                    <div className={metricValue}>{tkSpeeds.V1}</div>
                  </div>
                  <div className={metricBox}>
                    <div className={metricLabel}>VR</div>
                    <div className={metricValue}>{tkSpeeds.VR}</div>
                  </div>
                  <div className={metricBox}>
                    <div className={metricLabel}>V2</div>
                    <div className={metricValue}>{tkSpeeds.V2}</div>
                  </div>
                </div>
                <div className="text-xs text-white/45">
                  Runway required: <b>{Math.round(tkoCheck.required_length_m_est).toLocaleString()} m</b>
                </div>
              </div>

              <div className={`rounded-3xl border p-5 space-y-4 ${
                ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                  ? "border-white/10 bg-black/30"
                  : "border-rose-500/60 bg-rose-500/15 shadow-[0_0_45px_rgba(244,63,94,0.35)]"
              }`}>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-[0.28em] text-white/70">LANDING PERFORMANCE</div>
                    <div className="text-2xl font-semibold text-white/90 mt-2">
                      {Math.round(estLandingWeightKg).toLocaleString()}
                      <span className="text-sm text-white/40"> kg</span>
                    </div>
                  </div>
                  <div
                    className={`text-[11px] font-semibold px-3 py-1 rounded-full border ${
                      ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                        ? "border-emerald-400/40 text-emerald-300 bg-emerald-500/10"
                        : "border-rose-400/40 text-rose-300 bg-rose-500/10"
                    }`}
                  >
                    {ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                      ? "WITHIN LIMITS"
                      : estLandingWeightKg > CONSTANTS.weights.mlw_kg
                      ? "OVER MLW"
                      : "RUNWAY TOO SHORT"}
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className={metricBox}>
                    <div className={metricLabel}>VLS</div>
                    <div className={metricValue}>{ldSpeeds.VLS}</div>
                  </div>
                  <div className={metricBox}>
                    <div className={metricLabel}>VAPP</div>
                    <div className={metricValue}>{ldSpeeds.VAPP}</div>
                  </div>
                </div>
                <div className="text-xs text-white/45">
                  Runway required: <b>{Math.round(ldgCheck.required_length_m_est).toLocaleString()} m</b>
                </div>
              </div>
            </div>
            <div className="text-xs text-white/45 mt-3">
              Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim.
            </div>
          </Card>

          <Card title="Notes & Assumptions">
            <ul className="list-disc pl-5 text-sm text-white/70 space-y-2">
              <li>All masses in <b>kg</b>. Distances in <b>NM</b>. Runway lengths in <b>m</b> only.</li>
              <li>Nav DB loads Airports/Runways/NAVAIDs from OurAirports at runtime.</li>
              <li>Routes accept SID/STAR tokens but do not expand full procedure geometry.</li>
              <li>SimBrief import drives DEP/ARR, route, alternates, and METAR when available.</li>
              <li>Fuel model is heuristic and altitude-sensitive; verify against DC Designs data and in‑sim results.</li>
              <li>Reheat safety is a climb-time cap check; it does not change calculations.</li>
            </ul>
          </Card>

          <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-white/10 bg-black/25 px-4 py-3 text-xs text-white/60">
            <div className="flex flex-wrap items-center gap-2">
              <Button
                variant="ghost"
                className="h-8 px-3 text-xs"
                onClick={() => {
                  setTests(runSelfTests());
                  setShowDiagnostics(true);
                }}
              >
                Run Self-Tests
              </Button>
              {tests.length > 0 && (
                <span className="text-white/70">
                  Diagnostics: {passCount}/{tests.length} passed
                </span>
              )}
              {failedTests.length > 0 && (
                <Button
                  variant="ghost"
                  className="h-8 px-3 text-xs"
                  onClick={() => setShowDiagnostics((prev) => !prev)}
                >
                  {showDiagnostics ? "Hide Details" : "Show Details"}
                </Button>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Button variant="ghost" className="h-8 px-3 text-xs" disabled title="Provide Donate URL">
                Donate
              </Button>
              <Button variant="ghost" className="h-8 px-3 text-xs" disabled title="Provide feedback URL">
                Bug / Feature
              </Button>
              <Button variant="ghost" className="h-8 px-3 text-xs" disabled title="Provide GitHub URL">
                GitHub
              </Button>
              <Button variant="ghost" className="h-8 px-3 text-xs" disabled title="Coming soon">
                View Changelog
              </Button>
              <Button variant="ghost" className="h-8 px-3 text-xs" disabled title="Coming soon">
                Download Latest
              </Button>
            </div>
          </div>
          {showDiagnostics && failedTests.length > 0 && (
            <div className="mt-2 grid gap-2 sm:grid-cols-2">
              {failedTests.map((t, i) => (
                <div
                  key={`fail-${i}`}
                  className="text-[10px] px-2 py-1 rounded border border-rose-500/30 text-rose-300 bg-rose-500/5"
                >
                  {t.name} {t.err ? `— ${t.err}` : ""}
                </div>
              ))}
            </div>
          )}
        </main>

        <footer className="pt-6 text-center text-xs text-white/45">
          Manual values © DC Designs Concorde (MSFS). Planner is for training/planning only; always verify in-sim. Made with love by @theawesomeray
        </footer>
      </div>

      <a
        className="fixed bottom-4 right-4 z-50 opacity-70 transition hover:opacity-100"
        href={OPENS_COUNTER_PATH}
        target="_blank"
        rel="noreferrer"
        title="Site visits (counts every app load)"
      >
        <img
          src={OPENS_BADGE_SRC}
          alt="Site visits counter"
          className="h-6 w-auto rounded-md border border-white/10 bg-black/60 backdrop-blur"
          loading="lazy"
        />
      </a>
    </div>
  );
}

export default ConcordePlannerCanvas;
