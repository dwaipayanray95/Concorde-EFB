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

const APP_VERSION = "1.1.3";
const BUILD_MARKER = "TO BE DECIDEDnpm";
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
  const [appIconMode, setAppIconMode] = useState<"primary" | "fallback" | "none">("primary");

  useEffect(() => {
    console.log(`[ConcordeEFB.tsx] ${BUILD_MARKER} v${APP_VERSION}`);
    document.title = `Concorde EFB v${APP_VERSION} • ${BUILD_MARKER}`;
  }, []);


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

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <header className="max-w-6xl mx-auto p-6 pb-0 flex items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          {appIconMode !== "none" ? (
            <img
              src={appIconMode === "primary" ? APP_ICON_SRC_PRIMARY : APP_ICON_SRC_FALLBACK}
              alt="Concorde EFB"
              className="h-24 w-24 object-contain shrink-0"
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
            <div className="h-24 w-24 flex items-center justify-center shrink-0">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                className="h-10 w-10 text-slate-200"
                aria-hidden="true"
              >
                <path d="M21.5 13.5c.3 0 .5.2.5.5v1a1 1 0 0 1-1 1H14l-2.2 3.6a1 1 0 0 1-1.8-.5V16H6l-1.2 1.2a1 1 0 0 1-1.7-.7V15a1 1 0 0 1 .3-.7L6 12 3.4 9.7a1 1 0 0 1-.3-.7V7.5a1 1 0 0 1 1.7-.7L6 8h3.9V4.4a1 1 0 0 1 1.8-.5L14 7.5h7a1 1 0 0 1 1 1v1c0 .3-.2.5-.5.5H14v3.5h7Z" />
              </svg>
            </div>
          )}

          <div>
            <div className="text-3xl font-bold">Concorde EFB v{APP_VERSION}</div>
            <div className="text-sm text-slate-400">Your Concorde copilot for MSFS.</div>
            <div className="text-[10px] text-slate-500 mt-1">Build: {BUILD_MARKER}</div>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 justify-end">
          <StatPill label="Nav DB" value={dbLoaded ? "Loaded" : "Loading"} ok={dbLoaded} />
          <StatPill label="TAS" value={`${CONSTANTS.speeds.cruise_tas_kt} kt`} />
          <StatPill label="MTOW" value={`${CONSTANTS.weights.mtow_kg.toLocaleString()} kg`} />
          <StatPill label="MLW" value={`${CONSTANTS.weights.mlw_kg.toLocaleString()} kg`} />
          <StatPill
            label="Fuel cap"
            value={`${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg`}
          />
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6 space-y-6">
        {dbError && (
          <div className="text-xs text-rose-300">Nav DB load error: {dbError}</div>
        )}

        <Card
          title="Route (paste from SimBrief / OFP)"
        >
          <div className="space-y-3">
            <Label>SimBrief Username / ID (optional)</Label>

            <div className="grid gap-3 sm:grid-cols-12 items-start">
              {/* Row 1: SimBrief ID + Import */}
              <div className="sm:col-span-4">
                <Input
                  className="h-12 py-0 text-sm"
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

              {/* Row 1: SimBrief details (shows after a successful import) */}
              <div className="hidden sm:block sm:col-span-6">
                <div className="h-12 px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 flex items-center">
                  <div className="grid grid-cols-2 gap-3 w-full min-w-0">
                    <div className="min-w-0">
                      <div className="text-[10px] text-slate-400">Call Sign</div>
                      <div className="text-sm font-semibold truncate">
                        {simbriefImported ? (simbriefCallSign || "—") : "—"}
                      </div>
                    </div>
                    <div className="min-w-0">
                      <div className="text-[10px] text-slate-400">Registration</div>
                      <div className="text-sm font-semibold truncate">
                        {simbriefImported ? (simbriefRegistration || "—") : "—"}
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Row 2: Route box (left) + distance (right) */}
              <div className="sm:col-span-9">
                <textarea
                  className="w-full h-12 px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 text-xs leading-tight resize-none overflow-y-auto"
                  placeholder="Route will auto-fill from SimBrief (or paste here)"
                  value={routeText}
                  onChange={(e) => {
                    // user is manually editing/pasting; distance becomes an auto-estimate
                    setDistanceSource("auto");
                    setPlannedDistanceOverridden(false);
                    setRouteText(e.target.value);
                  }}
                />

                {/* SimBrief success/error should live under the route box */}
                {simbriefNotice && (
                  <div
                    className={`mt-2 text-xs ${
                      simbriefNotice.startsWith("Imported")
                        ? "text-emerald-400"
                        : "text-rose-300"
                    }`}
                  >
                    {simbriefNotice}
                  </div>
                )}
              </div>

              <div className="sm:col-span-3">
                <div className="px-3 py-2 h-12 flex flex-col justify-center rounded-xl bg-slate-950 border border-slate-800">
                  <div className="text-[10px] text-slate-400">Estimated Route Distance</div>
                  <div className="text-sm font-semibold">
                    {routeDistanceNM != null
                      ? `${Math.round(routeDistanceNM).toLocaleString()} NM`
                      : "—"}
                  </div>
                </div>

                {/* Status should live under the distance box */}
                {simbriefImported && !plannedDistanceOverridden && distanceSource === "simbrief" && (
                  <div className="mt-2 text-xs text-emerald-400">Imported from SimBrief</div>
                )}
                {simbriefImported && plannedDistanceOverridden && (
                  <div className="mt-2 text-xs text-amber-300">
                    Imported from SimBrief • Planned Distance overridden
                  </div>
                )}
              </div>
            </div>

            {routeNotice && (
              <div className="text-xs text-slate-400">{routeNotice}</div>
            )}
          </div>
        </Card>

        <Card
          title="Departure / Arrival (ICAO & Runways)"
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

                const [d, a] = await Promise.all([
                  fetchMetarByICAO(dep),
                  fetchMetarByICAO(arr),
                ]);

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
          <Row>
            <div>
              <Label>Departure ICAO</Label>
              <Input
                value={depIcao}
                onChange={(e) => setDepIcao(e.target.value.toUpperCase())}
              />
            </div>
            <div>
              <Label>Arrival ICAO</Label>
              <Input
                value={arrIcao}
                onChange={(e) => setArrIcao(e.target.value.toUpperCase())}
              />
            </div>
          </Row>

          <Row>
            <div>
              <Label>Departure Runway (meters)</Label>
              <Select value={depRw} onChange={(e) => setDepRw(e.target.value)}>
                <option value="">—</option>
                {(depInfo?.runways ?? []).map((r) => (
                  <option key={`dep-${r.id}`} value={r.id}>
                    {r.id} • {r.length_m.toLocaleString()} m • HDG {r.heading}°
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <Label>Arrival Runway (meters)</Label>
              <Select value={arrRw} onChange={(e) => setArrRw(e.target.value)}>
                <option value="">—</option>
                {(arrInfo?.runways ?? []).map((r) => (
                  <option key={`arr-${r.id}`} value={r.id}>
                    {r.id} • {r.length_m.toLocaleString()} m • HDG {r.heading}°
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
              <Input
                type="number"
                value={manualDistanceNM}
                onChange={(e) => {
                  // User override: use this value for calculations, but do NOT change the SimBrief/route distance display.
                  if (simbriefImported) setPlannedDistanceOverridden(true);
                  lastAutoDistanceRef.current = null;

                  const next = parseFloat(e.target.value || "0");
                  setManualDistanceNM(Number.isFinite(next) ? next : 0);

                  // Re-enable auto-FL (it should recompute from the new Planned Distance).
                  setCruiseFLTouched(false);
                  setCruiseFLNotice("");
                }}
              />
              <div className="text-xs text-slate-400 mt-1">
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

                  // Track whether the user actually changed the value during this focus session.
                  if (cruiseFLFocusValueRef.current !== null && next !== cruiseFLFocusValueRef.current) {
                    cruiseFLEditedRef.current = true;
                  }

                  // Update calculations live when parsable, but don't snap while typing.
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
                    // Reset focus tracking.
                    cruiseFLFocusValueRef.current = null;
                    cruiseFLEditedRef.current = false;
                    return;
                  }

                  const next = normalizeCruiseFLByRules(n, directionEW);

                  // Build a helpful notice (only if we changed what the user typed)
                  if (next !== Math.round(n)) {
                    const dirMsg = directionEW
                      ? ` (${directionEW === "E" ? "Eastbound" : "Westbound"})`
                      : " (direction unknown)";
                    setCruiseFLNotice(`Adjusted to valid FL${next}${dirMsg}.`);
                  } else {
                    setCruiseFLNotice("");
                  }

                  setCruiseFL(next);
                  setCruiseFLText(String(next));

                  // Only mark as touched if they actually edited during this focus.
                  if (cruiseFLEditedRef.current) setCruiseFLTouched(true);

                  // Reset focus tracking.
                  cruiseFLFocusValueRef.current = null;
                  cruiseFLEditedRef.current = false;
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
                    cruiseFLNotice.startsWith("Warning")
                      ? "text-amber-300"
                      : cruiseFLNotice.startsWith("Adjusted")
                      ? "text-amber-300"
                      : cruiseFLNotice.startsWith("Adjusted")
                      ? "text-amber-300"
                      : cruiseFLNotice.startsWith("Invalid")
                      ? "text-rose-300"
                      : "text-slate-300"
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
        