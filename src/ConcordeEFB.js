import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
// Concorde EFB — Canvas v0.85 (for DC Designs, MSFS 2024)
// What’s new in v0.85
// • Non-RVSM FL compliance warning (≥ FL410) with auto direction inference (DEP→ARR).
// • Max cruise FL enforced at FL590 in logic & UI.
// • Version label is now driven by state (no hardcoded string).
import React, { useEffect, useMemo, useState } from "react";
import Papa from "papaparse";

const toRad = (deg) => (deg * Math.PI) / 180;
const nmFromKm = (km) => km * 0.539957;

const ftToM = (ft) => {
  const value =
    typeof ft === "number"
      ? ft
      : parseFloat((ft ?? "").toString().trim() || "0");
  return value * 0.3048;
};

function greatCircleNM(lat1, lon1, lat2, lon2) {
  const R_km = 6371.0088;
  const phi1 = toRad(lat1),
    phi2 = toRad(lat2);
  const dphi = toRad(lat2 - lat1);
  const dlambda = toRad(lon2 - lon1);
  const a =
    Math.sin(dphi / 2) ** 2 +
    Math.cos(phi1) *
      Math.cos(phi2) *
      Math.sin(dlambda / 2) ** 2;
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
  speeds: { cruise_mach: 2.04, cruise_tas_kt: 1164, max_cruise_fl: 590 },
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
};

function altitudeBurnFactor(cruiseFL) {
  const maxFL = CONSTANTS?.speeds?.max_cruise_fl ?? 590;
  const fl = Math.max(300, Math.min(maxFL, cruiseFL || 580));
  const x = (fl - 450) / (600 - 450);
  return 1.2 - 0.2 * Math.max(0, Math.min(1, x));
}

function cruiseTimeHours(distanceNM, tasKT = CONSTANTS.speeds.cruise_tas_kt) {
  if (tasKT <= 0) throw new Error("TAS must be positive");
  return distanceNM / tasKT;
}

function estimateClimb(cruiseAltFt, avgFpm = 2500, avgGSkt = 450) {
  const tH = Math.max(cruiseAltFt, 0) / Math.max(avgFpm, 100) / 60;
  const dNM = tH * Math.max(avgGSkt, 200);
  return { time_h: tH, dist_nm: dNM };
}

function estimateDescent(cruiseAltFt, avgGSkt = 420, bufferNM = 30) {
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
}) {
  const burn = burnKgPerNm ?? CONSTANTS.fuel.burn_kg_per_nm;
  const altKg = Math.max(alternateNM ?? 0, 0) * burn;
  const contKg = tripKg * Math.max(Number(contingencyPct || 0) / 100, 0);
  const total =
    tripKg +
    (taxiKg || 0) +
    contKg +
    (finalReserveKg || 0) +
    altKg;
  return {
    trip_kg: tripKg,
    taxi_kg: taxiKg || 0,
    contingency_kg: contKg,
    final_reserve_kg: finalReserveKg || 0,
    alternate_kg: altKg,
    block_kg: total,
  };
}

function reheatGuard(climbTimeHours) {
  const requestedMin = Math.round(climbTimeHours * 60);
  const cap = CONSTANTS.fuel.reheat_minutes_cap;
  return { requested_min: requestedMin, cap_min: cap, within_cap: requestedMin <= cap };
}

function takeoffFeasibleM(runwayLengthM, takeoffWeightKg) {
  const mtow = CONSTANTS.weights.mtow_kg;
  const baseReq = CONSTANTS.runway.min_takeoff_m_at_mtow;
  const ratio = Math.max(Math.min(takeoffWeightKg / mtow, 1.2), 0.5);
  const required = baseReq * ratio;
  return { required_length_m_est: required, runway_length_m: runwayLengthM, feasible: runwayLengthM >= required };
}

function landingFeasibleM(runwayLengthM, landingWeightKg) {
  const mlw = CONSTANTS.weights.mlw_kg;
  const baseReq = CONSTANTS.runway.min_landing_m_at_mlw;
  const ratio = Math.max(Math.min((landingWeightKg || mlw) / mlw, 1.3), 0.6);
  const required = baseReq * Math.pow(ratio, 1.15);
  return { required_length_m_est: required, runway_length_m: runwayLengthM, feasible: runwayLengthM >= required };
}

function parseMetarWind(raw) {
  const re = new RegExp("(VRB|\\d{3})(\\d{2})(G(\\d{2}))?KT");
  const m = raw.match(re);
  if (!m) return { wind_dir_deg: null, wind_speed_kt: null, wind_gust_kt: null };
  const dirToken = m[1],
    spd = parseInt(m[2], 10),
    gst = m[4] ? parseInt(m[4], 10) : null;
  const dirDeg = dirToken === "VRB" ? null : parseInt(dirToken, 10);
  return { wind_dir_deg: dirDeg, wind_speed_kt: spd, wind_gust_kt: gst };
}

function windComponents(windDirDeg, windSpeedKt, runwayHeadingDeg) {
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

async function fetchMetarByICAO(icao) {
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

function buildWorldAirportDB(airportsCsvText, runwaysCsvText) {
  const airportsRows = Papa.parse(airportsCsvText, {
    header: true,
    skipEmptyLines: true,
  }).data;
  const runwaysRows = Papa.parse(runwaysCsvText, {
    header: true,
    skipEmptyLines: true,
  }).data;

  const airportsMap = {};
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
      Number.isFinite(parsedLength) && parsedLength > 0
        ? Math.round(parsedLength)
        : 0;

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

function pickLongestRunway(runways) {
  if (!runways || runways.length === 0) return null;
  return runways.reduce(
    (best, r) => ((r.length_m || 0) > (best.length_m || 0) ? r : best),
    runways[0]
  );
}

const Card = ({ title, children, right }) =>
  _jsxs("section", {
    className:
      "bg-slate-900/70 border border-slate-700 rounded-2xl p-5 shadow-xl",
    children: [
      _jsxs("div", {
        className: "flex items-center justify-between mb-3",
        children: [
          _jsx("h2", { className: "text-xl font-semibold", children: title }),
          right,
        ],
      }),
      children,
    ],
  });

const Row = ({ children, cols = 2 }) =>
  _jsx("div", {
    className: `grid gap-3 ${
      cols === 3
        ? "grid-cols-3"
        : cols === 4
        ? "grid-cols-4"
        : "grid-cols-2"
    }`,
    children: children,
  });

const Label = ({ children }) =>
  _jsx("label", {
    className: "text-xs text-slate-400 block mb-1",
    children: children,
  });

const Input = ({ className, ...props }) =>
  _jsx("input", {
    ...props,
    className: `w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${
      className ?? ""
    }`.trim(),
  });

const Select = ({ className, ...props }) =>
  _jsx("select", {
    ...props,
    className: `w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${
      className ?? ""
    }`.trim(),
  });

const Button = ({ children, variant = "primary", className, ...props }) =>
  _jsx("button", {
    ...props,
    className: `px-4 py-2 rounded-xl font-semibold ${
      variant === "primary"
        ? "bg-sky-400 text-slate-900"
        : "bg-slate-800 text-slate-100 border border-slate-600"
    } hover:brightness-105 ${className ?? ""}`.trim(),
    children: children,
  });

function StatPill({ label, value, ok = true }) {
  return _jsxs("div", {
    className: `px-2 py-1 rounded-full text-xs font-mono border ${
      ok
        ? "border-emerald-500/40 text-emerald-300"
        : "border-rose-500/40 text-rose-300"
    }`,
    children: [
      label,
      ": ",
      _jsx("span", { className: "font-bold", children: value }),
    ],
  });
}

function HHMM({ hours }) {
  const totalMinutes = Math.round(hours * 60);
  const hh = Math.floor(totalMinutes / 60);
  const mm = totalMinutes % 60;
  return _jsxs("span", { children: [hh, "h ", mm, "m"] });
}

function approxEqual(a, b, tol = 1e-3) {
  return Math.abs(a - b) <= tol;
}

// Non-RVSM (Concorde) flight level rules (simplified):
// From FL410 and above, use 20 FL spacing with direction-based alternation:
// Eastbound: FL410, 450, 490, 530, 570 ...
// Westbound: FL430, 470, 510, 550, 590 ...
// Up to max cruise FL (default 590).
function getNonRvsmAllowedFLs(maxFL = (CONSTANTS?.speeds?.max_cruise_fl ?? 590)) {
  const allowed = { east: [], west: [] };
  const startEast = 410;
  const startWest = 430;
  for (let fl = startEast; fl <= maxFL; fl += 40) allowed.east.push(fl);
  for (let fl = startWest; fl <= maxFL; fl += 40) allowed.west.push(fl);
  return allowed;
}

function validateNonRvsmFL(cruiseFL, direction, maxFL = (CONSTANTS?.speeds?.max_cruise_fl ?? 590)) {
  const fl = Number(cruiseFL);

  if (!Number.isFinite(fl) || fl <= 0) {
    return { ok: false, message: "Enter a valid Flight Level (e.g., 580)", suggestions: [] };
  }

  if (fl > maxFL) {
    return {
      ok: false,
      message: `FL${Math.round(fl)} is above the Concorde max cruise FL${maxFL}.`,
      suggestions: [maxFL],
    };
  }

  if (fl < 410) {
    return { ok: true, message: "", suggestions: [] };
  }

  const dir = (direction || "E").toUpperCase();
  const allowed = getNonRvsmAllowedFLs(maxFL);
  const list = dir === "W" ? allowed.west : allowed.east;

  const rounded = Math.round(fl);
  const exact = list.includes(rounded);
  if (exact) return { ok: true, message: "", suggestions: [] };

  const nearest = [...list]
    .map((v) => ({ v, d: Math.abs(v - rounded) }))
    .sort((a, b) => a.d - b.d)
    .slice(0, 2)
    .map((x) => x.v);

  const dirLabel = dir === "W" ? "Westbound" : "Eastbound";
  return {
    ok: false,
    message: `${dirLabel} non-RVSM cruising levels (≥ FL410) must be ${
      dir === "W"
        ? "FL430/470/510/550/590"
        : "FL410/450/490/530/570"
    }…`,
    suggestions: nearest,
  };
}

// Option B helpers: infer direction from DEP/ARR coordinates (shortest-path delta longitude)
function normalizeDeltaLon(deg) {
  let d = ((deg + 540) % 360) - 180; // [-180, 180]
  if (!Number.isFinite(d)) d = 0;
  return d;
}

function inferDirectionFromAirports(depInfo, arrInfo) {
  if (!depInfo || !arrInfo) return "E"; // default
  const dLon = normalizeDeltaLon((arrInfo.lon ?? 0) - (depInfo.lon ?? 0));
  return dLon >= 0 ? "E" : "W";
}

function weightScale(actual, reference) {
  if (
    !Number.isFinite(actual) ||
    actual <= 0 ||
    !Number.isFinite(reference) ||
    reference <= 0
  )
    return 1;
  return Math.sqrt(actual / reference);
}

function computeTakeoffSpeeds(towKg) {
  const refKg = 170000;
  const s = weightScale(towKg, refKg);
  const V1 = Math.max(160, Math.round(180 * s));
  const VR = Math.max(170, Math.round(195 * s));
  const V2 = Math.max(190, Math.round(220 * s));
  return { V1, VR, V2 };
}

function computeLandingSpeeds(lwKg) {
  const refKg = 105000;
  const s = weightScale(lwKg, refKg);
  const VLS = Math.max(140, Math.round(150 * s));
  const VAPP = VLS + 10;
  return { VLS, VAPP };
}

function runSelfTests() {
  const results = [];
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
    results.push({ name: "greatCircleNM EGLL-KJFK ~ 3k NM", pass: nm > 2500 && nm < 3500, value: nm });
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
    const lr = pickLongestRunway([
      { id: "A", heading: 0, length_m: 2800 },
      { id: "B", heading: 90, length_m: 3600 },
      { id: "C", heading: 180, length_m: 3200 },
    ]);
    results.push({ name: "pickLongestRunway chooses 3600 m", pass: lr?.id === "B", value: lr });
  } catch (e) {
    results.push({ name: "pickLongestRunway throws", pass: false, err: String(e) });
  }

  // Non-RVSM tests
  try {
    const eOk = validateNonRvsmFL(410, "E");
    const eBad = validateNonRvsmFL(430, "E");
    const wOk = validateNonRvsmFL(430, "W");
    const wBad = validateNonRvsmFL(410, "W");
    results.push({ name: "Non-RVSM FL Eastbound allows 410; rejects 430", pass: eOk.ok === true && eBad.ok === false });
    results.push({ name: "Non-RVSM FL Westbound allows 430; rejects 410", pass: wOk.ok === true && wBad.ok === false });
  } catch (e) {
    results.push({ name: "Non-RVSM FL validation throws", pass: false, err: String(e) });
  }
  try {
    const maxFL = CONSTANTS?.speeds?.max_cruise_fl ?? 590;
    const above = validateNonRvsmFL(maxFL + 10, "W");
    results.push({ name: "Non-RVSM FL rejects above max cruise", pass: above.ok === false && (above.suggestions?.[0] === maxFL) });
  } catch (e) {
    results.push({ name: "Non-RVSM max FL test throws", pass: false, err: String(e) });
  }

  // Recommend FL self-tests
  try {
    const maxFL = CONSTANTS?.speeds?.max_cruise_fl ?? 590;
    const recShort = recommendCruiseFLForRoute(200, "E", maxFL);
    const recLongW = recommendCruiseFLForRoute(3000, "W", maxFL);
    const allowed = getNonRvsmAllowedFLs(maxFL);

    results.push({
      name: "Recommend FL short route stays below FL410",
      pass: Number.isFinite(recShort) && recShort >= 300 && recShort <= 390,
      value: recShort,
    });

    results.push({
      name: "Recommend FL long westbound route is valid candidate",
      pass:
        Number.isFinite(recLongW) &&
        (recLongW <= 390 || allowed.west.includes(recLongW)) &&
        recLongW <= maxFL,
      value: recLongW,
    });
  } catch (e) {
    results.push({ name: "Recommend FL tests throw", pass: false, err: String(e) });
  }

  return results;
}

function recommendCruiseFLForRoute(distanceNM, direction, maxFL = (CONSTANTS?.speeds?.max_cruise_fl ?? 590)) {
  const dist = Number(distanceNM);
  if (!Number.isFinite(dist) || dist <= 0) return 580;

  const dir = (direction || "E").toUpperCase();
  const allowedNonRvsm = getNonRvsmAllowedFLs(maxFL);
  const nonRvsmList = dir === "W" ? allowedNonRvsm.west : allowedNonRvsm.east;

  // Candidate FLs: 300–390 (step 10) + non-RVSM list (>=410)
  const candidates = [];
  for (let fl = 300; fl <= 390; fl += 10) candidates.push(fl);
  for (const fl of nonRvsmList) candidates.push(fl);

  // Objective: minimize estimated trip fuel for this distance.
  let best = { fl: 580, tripKg: Number.POSITIVE_INFINITY };

  for (const fl of candidates) {
    const cruiseAltFt = fl * 100;
    const climb = estimateClimb(cruiseAltFt);
    const descent = estimateDescent(cruiseAltFt);
    const cruiseDist = Math.max(dist - climb.dist_nm - descent.dist_nm, 0);

    const baseBurn = CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(fl);
    const climbKg = climb.dist_nm * baseBurn * CONSTANTS.fuel.climb_factor;
    const cruiseKg = cruiseDist * baseBurn;
    const descentKg = descent.dist_nm * baseBurn * CONSTANTS.fuel.descent_factor;
    const tripKg = Math.max(climbKg + cruiseKg + descentKg, 0);

    if (tripKg < best.tripKg) best = { fl, tripKg };
  }

  // Clamp and sanity
  if (best.fl > maxFL) return maxFL;
  if (best.fl < 300) return 300;
  return best.fl;
}

// Option B helpers: infer direction from DEP/ARR coordinates (shortest-path delta longitude)
function ConcordePlannerCanvas() {
  const [airports, setAirports] = useState({});
  const [dbLoaded, setDbLoaded] = useState(false);
  const [dbError, setDbError] = useState("Error loading database");

  const [depIcao, setDepIcao] = useState("EGLL");
  const [depRw, setDepRw] = useState("");
  const [arrIcao, setArrIcao] = useState("KJFK");
  const [arrRw, setArrRw] = useState("");

  const [manualDistanceNM, setManualDistanceNM] = useState(0);
  const [version, setVersion] = useState("v0.85");

  const [altIcao, setAltIcao] = useState("");
  const [trimTankKg, setTrimTankKg] = useState(0);
  const [cruiseFL, setCruiseFL] = useState(580);
  const [autoCruiseFL, setAutoCruiseFL] = useState(true);
  const [taxiKg, setTaxiKg] = useState(450);
  const [contingencyPct, setContingencyPct] = useState(5);
  const [finalReserveKg, setFinalReserveKg] = useState(3600);

  const [metarDep, setMetarDep] = useState("");
  const [metarArr, setMetarArr] = useState("");
  const [metarErr, setMetarErr] = useState("");
  const [tests, setTests] = useState([]);

  const depKey = (depIcao || "").toUpperCase();
  const arrKey = (arrIcao || "").toUpperCase();
  const altKey = (altIcao || "").toUpperCase();

  useEffect(() => {
    (async () => {
      try {
        const [airCsv, rwCsv] = await Promise.all([
          fetch(AIRPORTS_CSV_URL, { mode: "cors" }).then((r) => r.text()),
          fetch(RUNWAYS_CSV_URL, { mode: "cors" }).then((r) => r.text()),
        ]);
        const db = buildWorldAirportDB(airCsv, rwCsv);
        setAirports(db);
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
    const rws = a?.runways ?? [];

    if (rws.length) {
      const currentValid = depRw && rws.some((r) => r.id === depRw);
      if (!currentValid) {
        const longest = pickLongestRunway(rws);
        if (longest) setDepRw(longest.id);
      }
    } else {
      if (depRw) setDepRw("");
    }
  }, [airports, depKey, depRw]);

  useEffect(() => {
    const a = arrKey ? airports[arrKey] : undefined;
    const rws = a?.runways ?? [];

    if (rws.length) {
      const currentValid = arrRw && rws.some((r) => r.id === arrRw);
      if (!currentValid) {
        const longest = pickLongestRunway(rws);
        if (longest) setArrRw(longest.id);
      }
    } else {
      if (arrRw) setArrRw("");
    }
  }, [airports, arrKey, arrRw]);

  const depInfo = depKey ? airports[depKey] : undefined;
  const arrInfo = arrKey ? airports[arrKey] : undefined;

  const inferredDirection = useMemo(
    () => inferDirectionFromAirports(depInfo, arrInfo),
    [depInfo, arrInfo]
  );

  const flCompliance = useMemo(
    () => validateNonRvsmFL(cruiseFL, inferredDirection),
    [cruiseFL, inferredDirection]
  );

  useEffect(() => {
    if (!autoCruiseFL) return;
    if (!Number.isFinite(manualDistanceNM) || manualDistanceNM <= 0) return;

    const rec = recommendCruiseFLForRoute(manualDistanceNM, inferredDirection);
    // Avoid unnecessary state churn
    if (Number.isFinite(rec) && Math.round(rec) !== Math.round(cruiseFL)) {
      setCruiseFL(rec);
    }
  }, [autoCruiseFL, manualDistanceNM, inferredDirection]);

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

  const fullPayloadKg = (CONSTANTS.weights.pax_full_count || 0) * (CONSTANTS.weights.pax_mass_kg || 0);
  const tkoWeightKgAuto = Math.min((CONSTANTS.weights.oew_kg || 0) + fullPayloadKg + totalFuelRequiredKg, CONSTANTS.weights.mtow_kg);
  const estLandingWeightKg = Math.max(tkoWeightKgAuto - tripKg, 0);

  const tkSpeeds = computeTakeoffSpeeds(tkoWeightKgAuto);
  const ldSpeeds = computeLandingSpeeds(estLandingWeightKg);

  const depRunways = depInfo?.runways ?? [];
  const arrRunways = arrInfo?.runways ?? [];

  const depRunway = depRunways.find((r) => r.id === depRw);
  const arrRunway = arrRunways.find((r) => r.id === arrRw);

  const tkoCheck = useMemo(
    () => takeoffFeasibleM(depRunway?.length_m || 0, tkoWeightKgAuto),
    [depRunway, tkoWeightKgAuto]
  );

  const ldgCheck = useMemo(
    () => landingFeasibleM(arrRunway?.length_m || 0, estLandingWeightKg),
    [arrRunway, estLandingWeightKg]
  );

  const depWind = useMemo(() => {
    const p = parseMetarWind(metarDep || "");
    const comps = depRunway
      ? windComponents(p.wind_dir_deg, p.wind_speed_kt, depRunway.heading)
      : { headwind_kt: null, crosswind_kt: null };
    return { parsed: p, comps };
  }, [metarDep, depRunway]);

  const arrWind = useMemo(() => {
    const p = parseMetarWind(metarArr || "");
    const comps = arrRunway
      ? windComponents(p.wind_dir_deg, p.wind_speed_kt, arrRunway.heading)
      : { headwind_kt: null, crosswind_kt: null };
    return { parsed: p, comps };
  }, [metarArr, arrRunway]);

  async function fetchMetars() {
    const errors = [];
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

  return _jsxs("div", {
    className: "min-h-screen bg-slate-950 text-slate-100",
    children: [
      _jsxs("header", {
        className:
          "px-6 py-4 border-b border-slate-800 flex items-center justify-between",
        children: [
          _jsxs("div", {
            className: "flex items-center gap-3",
            children: [
              _jsx("span", { className: "text-2xl", children: "✈️" }),
              _jsxs("div", {
                children: [
                  _jsxs("h1", {
                    className: "text-2xl font-bold",
                    children: [
                      "Concorde EFB ",
                      _jsx("span", { className: "text-sky-400", children: version }),
                    ],
                  }),
                  _jsx("p", {
                    className: "text-xs text-slate-400",
                    children: "Your Concorde copilot for MSFS.",
                  }),
                ],
              }),
            ],
          }),
          _jsxs("div", {
            className: "flex gap-2 items-center",
            children: [
              _jsx(StatPill, { label: "Nav DB", value: dbLoaded ? "Loaded" : "Loading…", ok: dbLoaded && !dbError }),
              dbError && _jsx(StatPill, { label: "DB Error", value: dbError.slice(0, 40) + "…", ok: false }),
              _jsx(StatPill, { label: "TAS", value: `${CONSTANTS.speeds.cruise_tas_kt} kt` }),
              _jsx(StatPill, { label: "MTOW", value: `${CONSTANTS.weights.mtow_kg.toLocaleString()} kg` }),
              _jsx(StatPill, { label: "MLW", value: `${CONSTANTS.weights.mlw_kg.toLocaleString()} kg` }),
              _jsx(StatPill, { label: "Fuel cap", value: `${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg` }),
            ],
          }),
        ],
      }),

      _jsxs("main", {
        className: "max-w-6xl mx-auto p-6 grid gap-6",
        children: [
          _jsxs(Card, {
            title: "Departure / Arrival (ICAO & Runways)",
            right: _jsx(Button, { onClick: fetchMetars, children: "Fetch METARs" }),
            children: [
              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Departure ICAO" }),
                      _jsx(Input, { value: depIcao, onChange: (e) => setDepIcao(e.target.value.toUpperCase()) }),
                      !depInfo && dbLoaded && _jsx("div", { className: "text-xs text-rose-300 mt-1", children: "Unknown ICAO in database" }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Arrival ICAO" }),
                      _jsx(Input, { value: arrIcao, onChange: (e) => setArrIcao(e.target.value.toUpperCase()) }),
                      !arrInfo && dbLoaded && _jsx("div", { className: "text-xs text-rose-300 mt-1", children: "Unknown ICAO in database" }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Departure Runway (meters)" }),
                      _jsx(Select, {
                        value: depRw,
                        onChange: (e) => setDepRw(e.target.value),
                        children: depRunways.map((r) =>
                          _jsxs(
                            "option",
                            {
                              value: r.id,
                              children: [
                                r.id,
                                " • ",
                                Number(r.length_m).toLocaleString(),
                                " m • HDG ",
                                Math.round(r.heading),
                                "°",
                              ],
                            },
                            r.id
                          )
                        ),
                      }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Arrival Runway (meters)" }),
                      _jsx(Select, {
                        value: arrRw,
                        onChange: (e) => setArrRw(e.target.value),
                        children: arrRunways.map((r) =>
                          _jsxs(
                            "option",
                            {
                              value: r.id,
                              children: [
                                r.id,
                                " • ",
                                Number(r.length_m).toLocaleString(),
                                " m • HDG ",
                                Math.round(r.heading),
                                "°",
                              ],
                            },
                            r.id
                          )
                        ),
                      }),
                    ],
                  }),
                ],
              }),
            ],
          }),

          _jsxs(Card, {
            title: "Cruise & Fuel (Manual Distance)",
            children: [
              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Planned Distance (NM)" }),
                      _jsx(Input, {
                        type: "number",
                        value: manualDistanceNM,
                        onChange: (e) => {
                          setManualDistanceNM(parseFloat(e.target.value || "0"));
                          setAutoCruiseFL(true);
                        },
                      }),
                      _jsx("div", {
                        className: "text-xs text-slate-400 mt-1",
                        children:
                          "Enter distance from your flight planner. We’ll compute Climb/Cruise/Descent from this and FL.",
                      }),
                    ],
                  }),

                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Cruise Flight Level (FL)" }),
                      _jsx(Input, {
                        type: "number",
                        value: cruiseFL,
                        onChange: (e) => {
                          setCruiseFL(parseFloat(e.target.value || "0"));
                          setAutoCruiseFL(false);
                        },
                      }),
                      _jsxs("div", {
                        className: "text-xs text-slate-400 mt-1",
                        children: [
                          "Direction inferred from route: ",
                          _jsx("b", { children: inferredDirection === "W" ? "Westbound" : "Eastbound" }),
                        ],
                      }),
                      _jsx("div", {
                        className: "text-[11px] text-slate-500 mt-1",
                        children: autoCruiseFL ? "Auto FL: ON (distance-driven)" : "Auto FL: OFF (manual override)",
                      }),

                      !flCompliance.ok && cruiseFL >= 410 && _jsxs("div", {
                        className: "text-xs text-rose-300 mt-2",
                        children: [
                          flCompliance.message,
                          " ",
                          flCompliance.suggestions?.length
                            ? _jsxs("span", {
                                children: [
                                  "Suggested: ",
                                  flCompliance.suggestions.map((s) =>
                                    _jsx(
                                      "button",
                                      {
                                        className: "underline mx-1",
                                        onClick: () => setCruiseFL(s),
                                        type: "button",
                                        children: `FL${s}`,
                                      },
                                      s
                                    )
                                  ),
                                ],
                              })
                            : null,
                        ],
                      }),

                      cruiseFL > (CONSTANTS?.speeds?.max_cruise_fl ?? 590) && _jsxs("div", {
                        className: "text-xs text-rose-300 mt-2",
                        children: [
                          "Max cruise FL for Concorde in this tool is FL",
                          (CONSTANTS?.speeds?.max_cruise_fl ?? 590),
                          ".",
                        ],
                      }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                cols: 4,
                children: [
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Planned Distance" }),
                      _jsxs("div", { className: "text-lg font-semibold", children: [plannedDistance ? Math.round(plannedDistance).toLocaleString() : "—", " NM"] }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Climb" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: climb.time_h }) }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Cruise" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: cruiseTimeH }) }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Descent" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: descent.time_h }) }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Total Flight Time (ETE)" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: totalTimeH }) }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Fuel Endurance (airborne)" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: enduranceHours }) }),
                    ],
                  }),
                  _jsxs("div", {
                    className: `px-3 py-2 rounded-xl bg-slate-950 border ${enduranceMeets ? "border-emerald-500/40" : "border-rose-500/40"}`,
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Required Minimum (ETE + reserves)" }),
                      _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: eteHours + reserveTimeH }) }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Alternate ICAO (optional)" }),
                      _jsx(Input, { value: altIcao, onChange: (e) => setAltIcao(e.target.value.toUpperCase()) }),
                      _jsxs("div", {
                        className: "text-xs text-slate-400 mt-1",
                        children: [
                          "ARR → ALT distance: ",
                          _jsx("b", { children: Math.round(alternateDistanceNM || 0).toLocaleString() }),
                          " NM",
                        ],
                      }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Taxi Fuel (kg)" }),
                      _jsx(Input, { type: "number", value: taxiKg, onChange: (e) => setTaxiKg(parseFloat(e.target.value || "0")) }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Computed TOW (kg)" }),
                      _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold", children: [Math.round(tkoWeightKgAuto).toLocaleString(), " kg"] }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Contingency (%)" }),
                      _jsx(Input, { type: "number", value: contingencyPct, onChange: (e) => setContingencyPct(parseFloat(e.target.value || "0")) }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Final Reserve (kg)" }),
                      _jsx(Input, { type: "number", value: finalReserveKg, onChange: (e) => setFinalReserveKg(parseFloat(e.target.value || "0")) }),
                    ],
                  }),
                ],
              }),

              _jsxs(Row, {
                children: [
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Trim Tank Fuel (kg)" }),
                      _jsx(Input, { type: "number", value: trimTankKg, onChange: (e) => setTrimTankKg(parseFloat(e.target.value || "0")) }),
                    ],
                  }),
                  _jsxs("div", {
                    children: [
                      _jsx(Label, { children: "Alternate Fuel (kg)" }),
                      _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold", children: [Math.round((alternateDistanceNM || 0) * CONSTANTS.fuel.burn_kg_per_nm).toLocaleString(), " kg"] }),
                    ],
                  }),
                ],
              }),

              _jsxs("div", {
                className: "mt-3 grid gap-3 md:grid-cols-4 grid-cols-2",
                children: [
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Trip Fuel" }),
                      _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(tripKg).toLocaleString(), " kg"] }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Block Fuel" }),
                      _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(blocks.block_kg).toLocaleString(), " kg"] }),
                    ],
                  }),
                  _jsxs("div", {
                    className: `px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 ${reheat.within_cap ? "" : "border-rose-500/40"}`,
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Reheat OK" }),
                      _jsx("div", { className: `text-lg font-semibold ${reheat.within_cap ? "text-emerald-400" : "text-rose-400"}`, children: reheat.within_cap ? "YES" : "NO" }),
                    ],
                  }),
                  _jsxs("div", {
                    className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800",
                    children: [
                      _jsx("div", { className: "text-xs text-slate-400", children: "Total Fuel Required (Block + Trim)" }),
                      _jsxs("div", { className: "text-lg font-semibold", children: [Number.isFinite(blocks.block_kg) && Number.isFinite(trimTankKg) ? Math.round(blocks.block_kg + (trimTankKg || 0)).toLocaleString() : "—", " kg"] }),
                    ],
                  }),
                ],
              }),
            ],
          }),

          _jsxs(Card, {
            title: "Takeoff & Landing Speeds (IAS)",
            children: [
              _jsxs(Row, {
                cols: 4,
                children: [
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Computed TOW" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(tkoWeightKgAuto).toLocaleString(), " kg"] })] }),
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "V1" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.V1, " kt"] })] }),
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VR" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.VR, " kt"] })] }),
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "V2" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.V2, " kt"] })] }),
                ],
              }),
              _jsxs(Row, {
                cols: 4,
                children: [
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Est. Landing WT" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(estLandingWeightKg).toLocaleString(), " kg"] })] }),
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VLS" }), _jsxs("div", { className: "text-lg font-semibold", children: [ldSpeeds.VLS, " kt"] })] }),
                  _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VAPP" }), _jsxs("div", { className: "text-lg font-semibold", children: [ldSpeeds.VAPP, " kt"] })] }),
                ],
              }),
              _jsx("div", { className: "text-xs text-slate-400 mt-2", children: "Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim." }),
            ],
          }),

          _jsxs(Card, {
            title: "Diagnostics / Self-tests",
            right: _jsx(Button, { variant: "ghost", onClick: () => setTests(runSelfTests()), children: "Run Self-Tests" }),
            children: [
              _jsx("div", { className: "text-xs text-slate-400 mb-2", children: "Includes Non-RVSM FL compliance tests for East/West and max FL clamp." }),
              tests.length === 0
                ? _jsxs("div", { className: "text-sm text-slate-300", children: ["Click ", _jsx("b", { children: "Run Self-Tests" }), " to execute."] })
                : _jsxs("div", {
                    children: [
                      _jsxs("div", { className: "mb-2 text-sm", children: ["Passed ", passCount, "/", tests.length] }),
                      _jsx("ul", {
                        className: "list-disc pl-5 text-sm space-y-1",
                        children: tests.map((t, i) =>
                          _jsxs(
                            "li",
                            {
                              className: t.pass ? "text-emerald-300" : "text-rose-300",
                              children: [t.name, " ", t.pass ? "✓" : "✗", " ", t.err ? `— ${t.err}` : ""],
                            },
                            i
                          )
                        ),
                      }),
                    ],
                  }),
            ],
          }),
        ],
      }),

      _jsx("footer", {
        className: "p-6 text-center text-xs text-slate-500",
        children:
          "Manual values © DC Designs Concorde (MSFS). Planner is for training/planning only; always verify in-sim. Made with love by @theawesomeray",
      }),
    ],
  });
}

class ErrorBoundary extends React.Component {
  constructor() {
    super(...arguments);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  componentDidCatch(error, info) {
    console.error("Concorde EFB crashed:", error, info);
  }
  render() {
    if (this.state.error) {
      return _jsxs("div", {
        style: { padding: 16 },
        children: [
          _jsx("h2", { children: "Something went wrong." }),
          _jsx("p", { children: "Open the browser console for details." }),
          _jsx("pre", {
            style: { whiteSpace: "pre-wrap" },
            children: String(this.state.error),
          }),
        ],
      });
    }
    return this.props.children;
  }
}

export default function ConcordeEFB() {
  return _jsx(ErrorBoundary, { children: _jsx(ConcordePlannerCanvas, {}) });
}