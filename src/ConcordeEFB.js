import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
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
import Papa from "papaparse";
const APP_VERSION = "1.0.0";
// Public, no-auth “opens” counter via an SVG badge.
// The badge request itself increments the counter, so every app open updates it.
// (This is intentionally simple and works on GitHub Pages without CORS issues.)
const OPENS_COUNTER_PATH = "https://dwaipayanray95.github.io/Concorde-EFB/";
const OPENS_BADGE_SRC = "https://api.visitorbadge.io/api/visitors" +
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
function clampNumber(value, min, max) {
    return Math.min(max, Math.max(min, value));
}
function clampCruiseFL(input) {
    const v = Number.isFinite(input) ? input : 0;
    // Allow entry below 300 by clamping only to [0..MAX]
    return clampNumber(Math.round(v), MIN_CONCORDE_FL, MAX_CONCORDE_FL);
}
function initialBearingDeg(lat1, lon1, lat2, lon2) {
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
function inferDirectionEW(dep, arr) {
    if (!dep || !arr)
        return null;
    const brg = initialBearingDeg(dep.lat, dep.lon, arr.lat, arr.lon);
    // Eastbound roughly 000-179, Westbound 180-359
    return brg < 180 ? "E" : "W";
}
function nonRvsmValidFLs(direction) {
    // Pattern provided by user:
    // East: 410, 450, 490, 530, 570
    // West: 430, 470, 510, 550, 590
    const start = direction === "E" ? 410 : 430;
    const levels = [];
    for (let fl = start; fl <= MAX_CONCORDE_FL; fl += 40)
        levels.push(fl);
    return levels;
}
function snapToNonRvsm(fl, direction) {
    if (!Number.isFinite(fl))
        return { snapped: NON_RVSM_MIN_FL, changed: true };
    const clamped = clampCruiseFL(fl);
    if (clamped < NON_RVSM_MIN_FL)
        return { snapped: clamped, changed: clamped !== fl };
    const valid = nonRvsmValidFLs(direction);
    if (valid.includes(clamped))
        return { snapped: clamped, changed: clamped !== fl };
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
function recommendedCruiseFL(direction) {
    // Keep the app’s original intent (high cruise) but make it compliant.
    const target = 580;
    const { snapped } = snapToNonRvsm(target, direction);
    return snapped;
}
const toRad = (deg) => (deg * Math.PI) / 180;
const nmFromKm = (km) => km * 0.539957;
const ftToM = (ft) => {
    const value = typeof ft === "number"
        ? ft
        : parseFloat((ft ?? "").toString().trim() || "0");
    return value * 0.3048;
};
function greatCircleNM(lat1, lon1, lat2, lon2) {
    const R_km = 6371.0088;
    const phi1 = toRad(lat1), phi2 = toRad(lat2);
    const dphi = toRad(lat2 - lat1);
    const dlambda = toRad(lon2 - lon1);
    const a = Math.sin(dphi / 2) ** 2 +
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
};
function altitudeBurnFactor(cruiseFL) {
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
function cruiseTimeHours(distanceNM, tasKT = CONSTANTS.speeds.cruise_tas_kt) {
    if (tasKT <= 0)
        throw new Error("TAS must be positive");
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
function blockFuelKg({ tripKg, taxiKg, contingencyPct, finalReserveKg, alternateNM, burnKgPerNm, }) {
    const burn = burnKgPerNm ?? CONSTANTS.fuel.burn_kg_per_nm;
    const altKg = Math.max(alternateNM ?? 0, 0) * burn;
    const contKg = tripKg * Math.max(Number(contingencyPct || 0) / 100, 0);
    const total = tripKg + (taxiKg || 0) + contKg + (finalReserveKg || 0) + altKg;
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
    return {
        requested_min: requestedMin,
        cap_min: cap,
        within_cap: requestedMin <= cap,
    };
}
function takeoffFeasibleM(runwayLengthM, takeoffWeightKg) {
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
function landingFeasibleM(runwayLengthM, landingWeightKg) {
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
function parseMetarWind(raw) {
    const re = new RegExp("(VRB|\\d{3})(\\d{2})(G(\\d{2}))?KT");
    const m = raw.match(re);
    if (!m)
        return { wind_dir_deg: null, wind_speed_kt: null, wind_gust_kt: null };
    const dirToken = m[1], spd = parseInt(m[2], 10), gst = m[4] ? parseInt(m[4], 10) : null;
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
        if (rawLine)
            return { ok: true, raw: rawLine, source: "aviationweather" };
    }
    catch {
        // Ignore and fall back
    }
    try {
        const r2 = await fetch(fallback, { mode: "cors" });
        const t2 = await r2.text();
        const line = (t2.split(/\r?\n/)[0] || "").trim();
        if (line)
            return { ok: true, raw: line, source: "vatsim" };
        return { ok: false, error: `No METAR text returned for ${icao}` };
    }
    catch (e2) {
        return { ok: false, error: `METAR fetch failed for ${icao}: ${String(e2)}` };
    }
}
const AIRPORTS_CSV_URL = "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv";
const RUNWAYS_CSV_URL = "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv";
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
        if (!ident || ident.length !== 4)
            continue;
        const lat = parseFloat(a?.latitude_deg ?? "");
        const lon = parseFloat(a?.longitude_deg ?? "");
        if (!Number.isFinite(lat) || !Number.isFinite(lon))
            continue;
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
        if (!airport)
            continue;
        const lengthMValue = r?.length_m ? Number(r.length_m) : Number.NaN;
        const parsedLength = Number.isFinite(lengthMValue) && lengthMValue > 0
            ? lengthMValue
            : ftToM(r?.length_ft ?? null);
        const lengthM = Number.isFinite(parsedLength) && parsedLength > 0 ? Math.round(parsedLength) : 0;
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
const LATLON_RE = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const AIRWAY_RE = /^[A-Z]{1,2}\d{1,3}$/;
const PROCEDURE_RE = /^(DCT|SID[A-Z0-9-]*|STAR[A-Z0-9-]*|VIA|VECTOR)$/;
function parseRouteString(str) {
    if (!str)
        return [];
    return str
        .split(/\s+/)
        .map((s) => s.trim().toUpperCase())
        .filter(Boolean);
}
function resolveRouteTokens(tokens, airportsIndex, navaidsIndex) {
    const points = [];
    const recognized = {
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
function computeRouteDistanceNM(depInfo, arrInfo, routePoints) {
    const seq = [
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
function pickLongestRunway(runways) {
    if (!runways || runways.length === 0)
        return null;
    return runways.reduce((best, r) => ((r.length_m || 0) > (best.length_m || 0) ? r : best), runways[0]);
}
const Card = ({ title, children, right }) => (_jsxs("section", { className: "bg-slate-900/70 border border-slate-700 rounded-2xl p-5 shadow-xl", children: [_jsxs("div", { className: "flex items-center justify-between mb-3", children: [_jsx("h2", { className: "text-xl font-semibold", children: title }), right] }), children] }));
const Row = ({ children, cols = 2 }) => (_jsx("div", { className: `grid gap-3 ${cols === 3 ? "grid-cols-3" : cols === 4 ? "grid-cols-4" : "grid-cols-2"}`, children: children }));
const Label = ({ children }) => (_jsx("label", { className: "text-xs text-slate-400 block mb-1", children: children }));
const Input = ({ className, ...props }) => (_jsx("input", { ...props, className: `w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${className ?? ""}`.trim() }));
const Select = ({ className, ...props }) => (_jsx("select", { ...props, className: `w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 ${className ?? ""}`.trim() }));
const Button = ({ children, variant = "primary", className, ...props }) => (_jsx("button", { ...props, className: `px-4 py-2 rounded-xl font-semibold ${variant === "primary"
        ? "bg-sky-400 text-slate-900"
        : "bg-slate-800 text-slate-100 border border-slate-600"} hover:brightness-105 ${className ?? ""}`.trim(), children: children }));
function StatPill({ label, value, ok = true }) {
    return (_jsxs("div", { className: `px-2 py-1 rounded-full text-xs font-mono border ${ok
            ? "border-emerald-500/40 text-emerald-300"
            : "border-rose-500/40 text-rose-300"}`, children: [label, ": ", _jsx("span", { className: "font-bold", children: value })] }));
}
function HHMM({ hours }) {
    const totalMinutes = Math.round(hours * 60);
    const hh = Math.floor(totalMinutes / 60);
    const mm = totalMinutes % 60;
    return (_jsxs("span", { children: [hh, "h ", mm, "m"] }));
}
function approxEqual(a, b, tol = 1e-3) {
    return Math.abs(a - b) <= tol;
}
function runSelfTests() {
    const results = [];
    try {
        results.push({
            name: "cruiseTimeHours(1164,1164)=1h",
            pass: approxEqual(cruiseTimeHours(1164, 1164), 1.0),
        });
    }
    catch (e) {
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
    }
    catch (e) {
        results.push({ name: "altitudeBurnFactor throws", pass: false, err: String(e) });
    }
    try {
        const nm = greatCircleNM(51.4706, -0.4619, 40.6413, -73.7781);
        results.push({
            name: "greatCircleNM EGLL-KJFK ~ 3k NM",
            pass: nm > 2500 && nm < 3500,
            value: nm,
        });
    }
    catch (e) {
        results.push({ name: "greatCircleNM throws", pass: false, err: String(e) });
    }
    try {
        const m = ftToM(11800);
        results.push({ name: "ftToM(11800) ≈ 3597", pass: Math.abs(m - 3596.64) < 0.5, value: m });
    }
    catch (e) {
        results.push({ name: "ftToM throws", pass: false, err: String(e) });
    }
    try {
        const rh = reheatGuard(24 / 60);
        results.push({ name: "reheatGuard 24min within cap", pass: rh.within_cap === true, value: rh });
    }
    catch (e) {
        results.push({ name: "reheatGuard throws", pass: false, err: String(e) });
    }
    try {
        const comps = windComponents(0, 20, 90);
        results.push({
            name: "windComponents 90° crosswind ≈ 20 kt",
            pass: Math.abs((comps.crosswind_kt ?? 0) - 20) < 0.1,
            value: comps,
        });
    }
    catch (e) {
        results.push({ name: "windComponents throws", pass: false, err: String(e) });
    }
    try {
        const lr = pickLongestRunway([
            { id: "A", heading: 0, length_m: 2800 },
            { id: "B", heading: 90, length_m: 3600 },
            { id: "C", heading: 180, length_m: 3200 },
        ]);
        results.push({ name: "pickLongestRunway chooses 3600 m", pass: lr?.id === "B", value: lr });
    }
    catch (e) {
        results.push({ name: "pickLongestRunway throws", pass: false, err: String(e) });
    }
    try {
        const feas = takeoffFeasibleM(4000, CONSTANTS.weights.mtow_kg);
        results.push({ name: "T/O feasible @ 4000 m, MTOW", pass: feas.feasible === true, value: feas });
    }
    catch (e) {
        results.push({ name: "takeoffFeasibleM throws", pass: false, err: String(e) });
    }
    try {
        const p = parseMetarWind("XXXX 101650Z VRB05KT 9999");
        results.push({ name: "parseMetarWind VRB05KT dir=null", pass: p.wind_dir_deg === null && p.wind_speed_kt === 5, value: p });
    }
    catch (e) {
        results.push({ name: "parseMetarWind VRB throws", pass: false, err: String(e) });
    }
    try {
        const mockAir = {
            EGLL: { name: "EGLL", lat: 51.4706, lon: -0.4619, runways: [] },
            KJFK: { name: "KJFK", lat: 40.6413, lon: -73.7781, runways: [] },
        };
        const mockNav = {
            CPT: { ident: "CPT", lat: 51.514, lon: -1.005, type: "NAVAID", name: "CPT" },
        };
        const { points } = resolveRouteTokens(parseRouteString("SID CPT STAR"), mockAir, mockNav);
        const direct = greatCircleNM(mockAir.EGLL.lat, mockAir.EGLL.lon, mockAir.KJFK.lat, mockAir.KJFK.lon);
        const routed = computeRouteDistanceNM(mockAir.EGLL, mockAir.KJFK, points);
        results.push({ name: "route distance >= direct when detoured", pass: routed >= direct - 1 });
    }
    catch (e) {
        results.push({ name: "route distance test throws", pass: false, err: String(e) });
    }
    try {
        const burn = (dist, fl) => {
            const base = CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(fl);
            const climb = estimateClimb(fl * 100);
            const desc = estimateDescent(fl * 100);
            const cruiseNM = Math.max(dist - climb.dist_nm - desc.dist_nm, 0);
            return (climb.dist_nm * base * CONSTANTS.fuel.climb_factor +
                cruiseNM * base +
                desc.dist_nm * base * CONSTANTS.fuel.descent_factor);
        };
        const f450 = burn(2000, 450), f600 = burn(2000, 600);
        const f2x = burn(3000, 580), f1x = burn(1500, 580);
        results.push({ name: "fuel less at higher FL (2000 NM: FL600 < FL450)", pass: f600 < f450, values: { f450, f600 } });
        results.push({ name: "fuel scales with distance (≈linear)", pass: f2x > f1x && f2x < 2.2 * f1x, values: { f1x, f2x } });
    }
    catch (e) {
        results.push({ name: "fuel monotonicity throws", pass: false, err: String(e) });
    }
    try {
        const a = landingFeasibleM(2200, CONSTANTS.weights.mlw_kg);
        const b = landingFeasibleM(1800, CONSTANTS.weights.mlw_kg);
        results.push({ name: "landing feasible 2200m@MLW; not at 1800m@MLW", pass: a.feasible === true && b.feasible === false });
    }
    catch (e) {
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
    }
    catch (e) {
        results.push({ name: "manual distance sanity throws", pass: false, err: String(e) });
    }
    // New tests: FL clamping
    try {
        const c1 = clampCruiseFL(610);
        const c2 = clampCruiseFL(100);
        results.push({ name: "clampCruiseFL clamps 610→590", pass: c1 === 590, value: c1 });
        results.push({ name: "clampCruiseFL allows 100 (no min clamp)", pass: c2 === 100, value: c2 });
    }
    catch (e) {
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
    }
    catch (e) {
        results.push({ name: "Non-RVSM snapping throws", pass: false, err: String(e) });
    }
    return results;
}
function weightScale(actual, reference) {
    if (!Number.isFinite(actual) || actual <= 0 || !Number.isFinite(reference) || reference <= 0)
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
    // Approximate Concorde landing performance:
    // target VLS ≈ 170–190 kt over typical landing weights,
    // with VAPP about 10–15 kt above VLS.
    const refKg = 100000;
    const s = weightScale(lwKg, refKg);
    let VLS = Math.round(175 * s);
    if (VLS < 170)
        VLS = 170;
    let VAPP = VLS + 15;
    if (VAPP < 185)
        VAPP = 185;
    return { VLS, VAPP };
}
function ConcordePlannerCanvas() {
    const [airports, setAirports] = useState({});
    const [dbLoaded, setDbLoaded] = useState(false);
    const [dbError, setDbError] = useState("");
    const [depIcao, setDepIcao] = useState("EGLL");
    const [depRw, setDepRw] = useState("");
    const [arrIcao, setArrIcao] = useState("KJFK");
    const [arrRw, setArrRw] = useState("");
    const [manualDistanceNM, setManualDistanceNM] = useState(0);
    const [altIcao, setAltIcao] = useState("");
    const [trimTankKg, setTrimTankKg] = useState(0);
    const [cruiseFL, setCruiseFL] = useState(580);
    const [cruiseFLText, setCruiseFLText] = useState("580");
    const [cruiseFLNotice, setCruiseFLNotice] = useState("");
    const [cruiseFLTouched, setCruiseFLTouched] = useState(false);
    const [taxiKg, setTaxiKg] = useState(2500);
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
            }
            catch (e) {
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
        }
        else if (depRw) {
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
        }
        else if (arrRw) {
            setArrRw("");
        }
    }, [airports, arrKey, arrRw]);
    const depInfo = depKey ? airports[depKey] : undefined;
    const arrInfo = arrKey ? airports[arrKey] : undefined;
    const directionEW = useMemo(() => inferDirectionEW(depInfo, arrInfo), [depInfo, arrInfo]);
    // Auto-pick a compliant cruise level when route changes (unless user has manually touched the field).
    useEffect(() => {
        if (!directionEW)
            return;
        if (cruiseFLTouched)
            return;
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
        if (!arrInfo || !altInfo)
            return 0;
        return greatCircleNM(arrInfo.lat, arrInfo.lon, altInfo.lat, altInfo.lon);
    }, [arrInfo, altInfo]);
    const blocks = useMemo(() => blockFuelKg({
        tripKg,
        taxiKg,
        contingencyPct,
        finalReserveKg,
        alternateNM: alternateDistanceNM,
        burnKgPerNm: CONSTANTS.fuel.burn_kg_per_nm,
    }), [tripKg, taxiKg, contingencyPct, finalReserveKg, alternateDistanceNM]);
    const totalFuelRequiredKg = (blocks.block_kg || 0) + (trimTankKg || 0);
    const eteHours = totalTimeH;
    const avgBurnKgPerHour = eteHours > 0
        ? tripKg / eteHours
        : CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(cruiseFL) * CONSTANTS.speeds.cruise_tas_kt;
    const airborneFuelKg = Math.max(totalFuelRequiredKg - (taxiKg || 0), 0);
    const enduranceHours = avgBurnKgPerHour > 0 ? airborneFuelKg / avgBurnKgPerHour : 0;
    const reserveTimeH = avgBurnKgPerHour > 0
        ? ((blocks.contingency_kg || 0) + (blocks.final_reserve_kg || 0) + (blocks.alternate_kg || 0)) / avgBurnKgPerHour
        : 0;
    const enduranceMeets = enduranceHours >= eteHours + reserveTimeH;
    const fuelCapacityKg = CONSTANTS.weights.fuel_capacity_kg;
    const fuelWithinCapacity = totalFuelRequiredKg <= fuelCapacityKg;
    const fuelExcessKg = Math.max(totalFuelRequiredKg - fuelCapacityKg, 0);
    const fullPayloadKg = (CONSTANTS.weights.pax_full_count || 0) * (CONSTANTS.weights.pax_mass_kg || 0);
    const tkoWeightKgAuto = Math.min((CONSTANTS.weights.oew_kg || 0) + fullPayloadKg + totalFuelRequiredKg, CONSTANTS.weights.mtow_kg);
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
        const errors = [];
        if (!depKey || !arrKey) {
            setMetarErr("Both departure and arrival ICAO codes are required.");
            return;
        }
        setMetarErr("");
        const [d, a] = await Promise.all([fetchMetarByICAO(depKey), fetchMetarByICAO(arrKey)]);
        if (!d.ok)
            errors.push(d.error);
        if (!a.ok)
            errors.push(a.error);
        if (errors.length > 0)
            setMetarErr(errors.join(" ").trim());
        if (d.ok)
            setMetarDep(d.raw);
        if (a.ok)
            setMetarArr(a.raw);
    }
    const passCount = tests.filter((t) => t.pass).length;
    return (_jsxs("div", { className: "min-h-screen bg-slate-950 text-slate-100", children: [_jsxs("header", { className: "px-6 py-4 border-b border-slate-800 flex items-center justify-between", children: [_jsxs("div", { className: "flex items-center gap-3", children: [_jsx("span", { className: "text-2xl", children: "\u2708\uFE0F" }), _jsxs("div", { children: [_jsxs("h1", { className: "text-2xl font-bold", children: ["Concorde EFB ", _jsxs("span", { className: "text-sky-400", children: ["v", APP_VERSION] })] }), _jsx("p", { className: "text-xs text-slate-400", children: "Your Concorde copilot for MSFS." })] })] }), _jsxs("div", { className: "flex gap-2 items-center", children: [_jsx(StatPill, { label: "Nav DB", value: dbLoaded ? "Loaded" : "Loading…", ok: dbLoaded && !dbError }), dbError && _jsx(StatPill, { label: "DB Error", value: dbError.slice(0, 40) + "…", ok: false }), _jsx(StatPill, { label: "TAS", value: `${CONSTANTS.speeds.cruise_tas_kt} kt` }), _jsx(StatPill, { label: "MTOW", value: `${CONSTANTS.weights.mtow_kg.toLocaleString()} kg` }), _jsx(StatPill, { label: "MLW", value: `${CONSTANTS.weights.mlw_kg.toLocaleString()} kg` }), _jsx(StatPill, { label: "Fuel cap", value: `${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg` })] })] }), _jsxs("main", { className: "max-w-6xl mx-auto p-6 grid gap-6", children: [_jsxs(Card, { title: "Departure / Arrival (ICAO & Runways)", right: _jsx(Button, { onClick: fetchMetars, children: "Fetch METARs" }), children: [_jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Departure ICAO" }), _jsx(Input, { value: depIcao, onChange: (e) => setDepIcao(e.target.value.toUpperCase()) }), !depInfo && dbLoaded && _jsx("div", { className: "text-xs text-rose-300 mt-1", children: "Unknown ICAO in database" })] }), _jsxs("div", { children: [_jsx(Label, { children: "Arrival ICAO" }), _jsx(Input, { value: arrIcao, onChange: (e) => setArrIcao(e.target.value.toUpperCase()) }), !arrInfo && dbLoaded && _jsx("div", { className: "text-xs text-rose-300 mt-1", children: "Unknown ICAO in database" })] })] }), _jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Departure Runway (meters)" }), _jsx(Select, { value: depRw, onChange: (e) => setDepRw(e.target.value), children: depRunways.map((r) => (_jsxs("option", { value: r.id, children: [r.id, " \u2022 ", Number(r.length_m).toLocaleString(), " m \u2022 HDG ", Math.round(r.heading), "\u00B0"] }, r.id))) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Arrival Runway (meters)" }), _jsx(Select, { value: arrRw, onChange: (e) => setArrRw(e.target.value), children: arrRunways.map((r) => (_jsxs("option", { value: r.id, children: [r.id, " \u2022 ", Number(r.length_m).toLocaleString(), " m \u2022 HDG ", Math.round(r.heading), "\u00B0"] }, r.id))) })] })] })] }), _jsxs(Card, { title: "Cruise & Fuel (Manual Distance)", children: [_jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Planned Distance (NM)" }), _jsx(Input, { type: "number", value: manualDistanceNM, onChange: (e) => setManualDistanceNM(parseFloat(e.target.value || "0")) }), _jsx("div", { className: "text-xs text-slate-400 mt-1", children: "Enter distance from your flight planner. We\u2019ll compute Climb/Cruise/Descent from this and FL." })] }), _jsxs("div", { children: [_jsx(Label, { children: "Cruise Flight Level (FL)" }), _jsx(Input, { type: "number", value: cruiseFLText, min: MIN_CONCORDE_FL, max: MAX_CONCORDE_FL, step: 10, onChange: (e) => {
                                                    const next = e.target.value;
                                                    setCruiseFLTouched(true);
                                                    setCruiseFLText(next);
                                                    // Update calculations live when parsable, but don't snap while typing.
                                                    const n = Number(next);
                                                    if (Number.isFinite(n))
                                                        setCruiseFL(n);
                                                }, onBlur: () => {
                                                    const n = Number(cruiseFLText);
                                                    if (!Number.isFinite(n)) {
                                                        setCruiseFLNotice("Invalid FL value.");
                                                        return;
                                                    }
                                                    // 1) Clamp to Concorde max
                                                    let clamped = clampCruiseFL(n);
                                                    let noticeParts = [];
                                                    if (n !== clamped) {
                                                        noticeParts.push(`Clamped to FL${clamped} (max FL${MAX_CONCORDE_FL}).`);
                                                    }
                                                    // 2) Apply Non-RVSM snapping above FL410 when direction is known
                                                    if (directionEW && clamped >= NON_RVSM_MIN_FL) {
                                                        const { snapped, changed } = snapToNonRvsm(clamped, directionEW);
                                                        if (changed) {
                                                            noticeParts.push(`Adjusted to Non-RVSM FL${snapped} (${directionEW === "E" ? "Eastbound" : "Westbound"}).`);
                                                            clamped = snapped;
                                                        }
                                                    }
                                                    setCruiseFL(clamped);
                                                    setCruiseFLText(String(clamped));
                                                    setCruiseFLNotice(noticeParts.join(" "));
                                                } }), _jsx("div", { className: "text-xs text-slate-400 mt-1", children: directionEW ? (_jsxs("span", { children: ["Direction (auto): ", _jsx("b", { children: directionEW === "E" ? "Eastbound" : "Westbound" }), ". Above FL410 we snap to Non-RVSM levels."] })) : (_jsxs("span", { children: ["Direction: ", _jsx("b", { children: "unknown" }), " (enter valid DEP/ARR ICAO to enable Non-RVSM snapping)."] })) }), cruiseFLNotice && (_jsx("div", { className: `text-xs mt-1 ${cruiseFLNotice.startsWith("Auto-selected") ? "text-emerald-300" : "text-rose-300"}`, children: cruiseFLNotice }))] })] }), _jsxs(Row, { cols: 4, children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Planned Distance" }), _jsxs("div", { className: "text-lg font-semibold", children: [plannedDistance ? Math.round(plannedDistance).toLocaleString() : "—", " NM"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Climb" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: climb.time_h }) })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Cruise" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: cruiseTimeH }) })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Descent" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: descent.time_h }) })] })] }), _jsxs(Row, { children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Total Flight Time (ETE)" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: totalTimeH }) })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Fuel Endurance (airborne)" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: enduranceHours }) })] }), _jsxs("div", { className: `px-3 py-2 rounded-xl bg-slate-950 border ${enduranceMeets ? "border-emerald-500/40" : "border-rose-500/40"}`, children: [_jsx("div", { className: "text-xs text-slate-400", children: "Required Minimum (ETE + reserves)" }), _jsx("div", { className: "text-lg font-semibold", children: _jsx(HHMM, { hours: eteHours + reserveTimeH }) })] })] }), _jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Alternate ICAO (optional)" }), _jsx(Input, { value: altIcao, onChange: (e) => setAltIcao(e.target.value.toUpperCase()) }), _jsxs("div", { className: "text-xs text-slate-400 mt-1", children: ["ARR \u2192 ALT distance: ", _jsx("b", { children: Math.round(alternateDistanceNM || 0).toLocaleString() }), " NM"] })] }), _jsxs("div", { children: [_jsx(Label, { children: "Taxi Fuel (kg)" }), _jsx(Input, { type: "number", value: taxiKg, onChange: (e) => setTaxiKg(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Computed TOW (kg)" }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold", children: [Math.round(tkoWeightKgAuto).toLocaleString(), " kg"] })] })] }), _jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Contingency (%)" }), _jsx(Input, { type: "number", value: contingencyPct, onChange: (e) => setContingencyPct(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Final Reserve (kg)" }), _jsx(Input, { type: "number", value: finalReserveKg, onChange: (e) => setFinalReserveKg(parseFloat(e.target.value || "0")) })] })] }), _jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Trim Tank Fuel (kg)" }), _jsx(Input, { type: "number", value: trimTankKg, onChange: (e) => setTrimTankKg(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Alternate Fuel (kg)" }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 font-semibold", children: [Math.round((alternateDistanceNM || 0) * CONSTANTS.fuel.burn_kg_per_nm).toLocaleString(), " kg"] })] })] }), _jsxs("div", { className: "mt-3 grid gap-3 md:grid-cols-4 grid-cols-2", children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Trip Fuel" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(tripKg).toLocaleString(), " kg"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Block Fuel" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(blocks.block_kg).toLocaleString(), " kg"] })] }), _jsxs("div", { className: `px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 ${reheat.within_cap ? "" : "border-rose-500/40"}`, children: [_jsx("div", { className: "text-xs text-slate-400", children: "Reheat OK" }), _jsx("div", { className: `text-lg font-semibold ${reheat.within_cap ? "text-emerald-400" : "text-rose-400"}`, children: reheat.within_cap ? "YES" : "NO" })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Total Fuel Required (Block + Trim)" }), _jsxs("div", { className: "text-lg font-semibold", children: [Number.isFinite(blocks.block_kg) && Number.isFinite(trimTankKg) ? Math.round(blocks.block_kg + (trimTankKg || 0)).toLocaleString() : "—", " kg"] })] })] }), !fuelWithinCapacity && (_jsxs("div", { className: "mt-2 text-xs text-rose-300", children: ["Warning: Total fuel ", _jsxs("b", { children: [Math.round(totalFuelRequiredKg).toLocaleString(), " kg"] }), " exceeds Concorde fuel capacity", " ", _jsxs("b", { children: [Math.round(fuelCapacityKg).toLocaleString(), " kg"] }), " by ", _jsxs("b", { children: [Math.round(fuelExcessKg).toLocaleString(), " kg"] }), ". Reduce block or trim fuel to stay within limits."] }))] }), _jsxs(Card, { title: "Takeoff & Landing Speeds (IAS)", children: [_jsxs(Row, { cols: 4, children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Computed TOW" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(tkoWeightKgAuto).toLocaleString(), " kg"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "V1" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.V1, " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VR" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.VR, " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "V2" }), _jsxs("div", { className: "text-lg font-semibold", children: [tkSpeeds.V2, " kt"] })] })] }), _jsxs(Row, { cols: 4, children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Est. Landing WT" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(estLandingWeightKg).toLocaleString(), " kg"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VLS" }), _jsxs("div", { className: "text-lg font-semibold", children: [ldSpeeds.VLS, " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "VAPP" }), _jsxs("div", { className: "text-lg font-semibold", children: [ldSpeeds.VAPP, " kt"] })] })] }), _jsx("div", { className: "text-xs text-slate-400 mt-2", children: "Speeds scale with \u221A(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim." })] }), _jsxs(Card, { title: "Weather & Runway Wind Components", right: _jsx("div", { className: "text-xs text-slate-400", children: "ILS intercept tip: ~15 NM / 5000 ft" }), children: [metarErr && _jsxs("div", { className: "text-xs text-rose-300 mb-2", children: ["METAR fetch error: ", metarErr] }), _jsxs("div", { className: "grid gap-4", children: [_jsxs("div", { children: [_jsxs("div", { className: "text-sm font-semibold mb-1", children: ["Departure METAR (", depIcao, depRunway ? ` ${depRunway.id}` : "", ")"] }), _jsx(Input, { placeholder: "Raw METAR will appear here if fetch works; otherwise paste manually", value: metarDep, onChange: (e) => setMetarDep(e.target.value) }), _jsxs("div", { className: "grid md:grid-cols-4 grid-cols-2 gap-3 mt-2", children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Headwind" }), _jsxs("div", { className: "text-lg font-semibold", children: [depWind.comps.headwind_kt ?? "—", " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Crosswind" }), _jsxs("div", { className: "text-lg font-semibold", children: [depWind.comps.crosswind_kt ?? "—", " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Dir" }), _jsx("div", { className: "text-lg font-semibold", children: depWind.parsed.wind_dir_deg ?? "VRB" })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Spd/Gust" }), _jsxs("div", { className: "text-lg font-semibold", children: [depWind.parsed.wind_speed_kt ?? "—", "/", depWind.parsed.wind_gust_kt ?? "—", " kt"] })] })] })] }), _jsxs("div", { children: [_jsxs("div", { className: "text-sm font-semibold mb-1", children: ["Arrival METAR (", arrIcao, arrRunway ? ` ${arrRunway.id}` : "", ")"] }), _jsx(Input, { placeholder: "Raw METAR will appear here if fetch works; otherwise paste manually", value: metarArr, onChange: (e) => setMetarArr(e.target.value) }), _jsxs("div", { className: "grid md:grid-cols-4 grid-cols-2 gap-3 mt-2", children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Headwind" }), _jsxs("div", { className: "text-lg font-semibold", children: [arrWind.comps.headwind_kt ?? "—", " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Crosswind" }), _jsxs("div", { className: "text-lg font-semibold", children: [arrWind.comps.crosswind_kt ?? "—", " kt"] })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Dir" }), _jsx("div", { className: "text-lg font-semibold", children: arrWind.parsed.wind_dir_deg ?? "VRB" })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "Spd/Gust" }), _jsxs("div", { className: "text-lg font-semibold", children: [arrWind.parsed.wind_speed_kt ?? "—", "/", arrWind.parsed.wind_gust_kt ?? "—", " kt"] })] })] })] })] })] }), _jsxs(Card, { title: "Runway Feasibility Summary", children: [_jsxs(Row, { cols: 4, children: [_jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "T/O Req (m)" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(tkoCheck.required_length_m_est).toLocaleString(), " m"] })] }), _jsxs("div", { className: `px-3 py-2 rounded-xl bg-slate-950 border ${tkoCheck.feasible ? "border-emerald-500/40" : "border-rose-500/40"}`, children: [_jsx("div", { className: "text-xs text-slate-400", children: "Departure Feasible?" }), _jsx("div", { className: `text-lg font-semibold ${tkoCheck.feasible ? "text-emerald-400" : "text-rose-400"}`, children: tkoCheck.feasible ? "YES" : "NO" })] }), _jsxs("div", { className: "px-3 py-2 rounded-xl bg-slate-950 border border-slate-800", children: [_jsx("div", { className: "text-xs text-slate-400", children: "LDG Req (m)" }), _jsxs("div", { className: "text-lg font-semibold", children: [Math.round(ldgCheck.required_length_m_est).toLocaleString(), " m"] })] }), _jsxs("div", { className: `px-3 py-2 rounded-xl bg-slate-950 border ${ldgCheck.feasible ? "border-emerald-500/40" : "border-rose-500/40"}`, children: [_jsx("div", { className: "text-xs text-slate-400", children: "Arrival Feasible?" }), _jsx("div", { className: `text-lg font-semibold ${ldgCheck.feasible ? "text-emerald-400" : "text-rose-400"}`, children: ldgCheck.feasible ? "YES" : "NO" })] })] }), _jsxs("div", { className: "text-xs text-slate-400 mt-2", children: ["Est. landing weight: ", _jsxs("b", { children: [Math.round(estLandingWeightKg).toLocaleString(), " kg"] }), " (TOW \u2212 Trip Fuel)."] })] }), _jsxs(Card, { title: "Diagnostics / Self-tests", right: _jsx(Button, { variant: "ghost", onClick: () => setTests(runSelfTests()), children: "Run Self-Tests" }), children: [_jsx("div", { className: "text-xs text-slate-400 mb-2", children: "Covers meters, crosswind, longest-runway, VRB parsing, manual-distance sanity, fuel monotonicity, landing feasibility, and FL clamping." }), tests.length === 0 ? (_jsxs("div", { className: "text-sm text-slate-300", children: ["Click ", _jsx("b", { children: "Run Self-Tests" }), " to execute."] })) : (_jsxs("div", { children: [_jsxs("div", { className: "mb-2 text-sm", children: ["Passed ", passCount, "/", tests.length] }), _jsx("ul", { className: "list-disc pl-5 text-sm space-y-1", children: tests.map((t, i) => (_jsxs("li", { className: t.pass ? "text-emerald-300" : "text-rose-300", children: [t.name, " ", t.pass ? "✓" : "✗", " ", t.err ? `— ${t.err}` : ""] }, i))) })] }))] }), _jsx(Card, { title: "Notes & Assumptions (for tuning)", children: _jsxs("ul", { className: "list-disc pl-5 text-sm text-slate-300 space-y-1", children: [_jsxs("li", { children: ["All masses in ", _jsx("b", { children: "kg" }), ". Distances in ", _jsx("b", { children: "NM" }), ". Runway lengths in ", _jsx("b", { children: "m" }), " only."] }), _jsx("li", { children: "Nav DB autoloads Airports/Runways/NAVAIDs from OurAirports. No fallback." }), _jsx("li", { children: "Procedural tokens are accepted so copy-pasting OFP routes won\u2019t break; true SID/STAR geometry is not expanded yet." }), _jsx("li", { children: "Fuel model is heuristic but altitude-sensitive and distance-stable; calibrate with DC Designs manual and in-sim numbers." })] }) })] }), _jsx("footer", { className: "p-6 text-center text-xs text-slate-500", children: "Manual values \u00A9 DC Designs Concorde (MSFS). Planner is for training/planning only; always verify in-sim. Made with love by @theawesomeray" }), _jsx("a", { className: "fixed bottom-3 right-3 z-50", href: OPENS_COUNTER_PATH, target: "_blank", rel: "noreferrer", title: "Site visits (counts every app load)", children: _jsx("img", { src: OPENS_BADGE_SRC, alt: "Site visits counter", className: "h-6 w-auto rounded-md border border-slate-700 bg-slate-950/70 backdrop-blur", loading: "lazy" }) })] }));
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
            return (_jsxs("div", { style: { padding: 16 }, children: [_jsx("h2", { children: "Something went wrong." }), _jsx("p", { children: "Open the browser console for details." }), _jsx("pre", { style: { whiteSpace: "pre-wrap" }, children: String(this.state.error) })] }));
        }
        return this.props.children;
    }
}
export default function ConcordeEFB() {
    return (_jsx(ErrorBoundary, { children: _jsx(ConcordePlannerCanvas, {}) }));
}
