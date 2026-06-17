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
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Papa from "papaparse";
import { UI_TOKENS } from "./uiTokens";
const APP_VERSION = "2.1.0";
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
const OPENS_BADGE_SRC = "https://api.visitorbadge.io/api/visitors" +
    `?path=${encodeURIComponent(OPENS_COUNTER_PATH)}` +
    "&label=EFB%20Launches" +
    "&labelColor=%23111a2b" +
    "&countColor=%230ea5e9" +
    "&style=flat" +
    "&labelStyle=upper";
const DONATE_PAGE_URL = "https://patreon.com/theawesoperay?utm_medium=unknown&utm_source=join_link&utm_campaign=creatorshare_creator&utm_content=copyLink";
const CHANGELOG_PAGE_URL = "https://github.com/dwaipayanray95/Concorde-EFB?tab=readme-ov-file#changelog-1";
const DOWNLOAD_LATEST_URL = "https://flightsim.to/file/101890/concorde-efb";
const GITHUB_LATEST_RELEASE_API = "https://api.github.com/repos/dwaipayanray95/Concorde-EFB/releases/latest";
const UPDATE_CHECK_CACHE_KEY = "efb_update_check_v1";
const UPDATE_CHECK_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
// User should be able to enter FL below 300 (e.g. low-level segments), but Concorde max is still capped.
const MIN_CONCORDE_FL = 0;
const MAX_CONCORDE_FL = 590;
// Non-RVSM flight levels for Concorde above FL410 (user-provided rule-of-thumb)
const NON_RVSM_MIN_FL = 410;
function normalizeVersionTag(input) {
    const raw = String(input || "").trim();
    if (!raw)
        return "";
    return raw.replace(/^v/i, "").split("-")[0];
}
function parseSemverParts(version) {
    const norm = normalizeVersionTag(version);
    if (!norm)
        return [];
    return norm
        .split(".")
        .map((part) => parseInt(part, 10))
        .filter((part) => Number.isFinite(part));
}
function compareSemver(a, b) {
    const av = parseSemverParts(a);
    const bv = parseSemverParts(b);
    const len = Math.max(av.length, bv.length);
    for (let i = 0; i < len; i += 1) {
        const ai = av[i] ?? 0;
        const bi = bv[i] ?? 0;
        if (ai > bi)
            return 1;
        if (ai < bi)
            return -1;
    }
    return 0;
}
function isNewerVersion(candidate, current) {
    const normalizedCandidate = normalizeVersionTag(candidate);
    const normalizedCurrent = normalizeVersionTag(current);
    if (!normalizedCandidate || !normalizedCurrent)
        return false;
    return compareSemver(normalizedCandidate, normalizedCurrent) > 0;
}
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
const ALL_NON_RVSM_LEVELS = Array.from(new Set([...nonRvsmValidFLs("E"), ...nonRvsmValidFLs("W")])).sort((a, b) => a - b);
function normalizeCruiseFLByRules(fl, direction) {
    // 1) Clamp to Concorde limits
    let next = clampCruiseFL(fl);
    // 2) Above FL410, snap to valid Non-RVSM levels.
    // If direction is unknown, snap to the nearest level from the union set.
    if (next >= NON_RVSM_MIN_FL) {
        if (direction) {
            next = snapToNonRvsm(next, direction).snapped;
        }
        else {
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
function recommendedCruiseFL(direction) {
    // Keep the app’s original intent (high cruise) but make it compliant.
    const target = 580;
    const { snapped } = snapToNonRvsm(target, direction);
    return snapped;
}
function buildCandidateFLs(direction) {
    const minAutoFL = 250;
    const maxAutoFL = MAX_CONCORDE_FL;
    const lows = [];
    for (let fl = minAutoFL; fl < NON_RVSM_MIN_FL; fl += 10)
        lows.push(fl);
    const highs = [];
    if (direction) {
        highs.push(...nonRvsmValidFLs(direction));
    }
    else {
        for (let fl = NON_RVSM_MIN_FL; fl <= maxAutoFL; fl += 10)
            highs.push(fl);
    }
    // Combine + sort descending (prefer highest FL that still gives enough cruise)
    const all = Array.from(new Set([...highs, ...lows]))
        .filter((fl) => fl >= minAutoFL && fl <= maxAutoFL)
        .sort((a, b) => b - a);
    return all;
}
function recommendCruiseFLForDistance(plannedDistanceNM, direction, opts) {
    const distance = Number(plannedDistanceNM);
    if (!Number.isFinite(distance) || distance <= 0)
        return null;
    const minCruiseMin = opts?.minCruiseMin ?? 15;
    const targetCruiseMin = opts?.targetCruiseMin ?? 18;
    const candidates = buildCandidateFLs(direction);
    // Evaluate candidates and pick the highest FL that still yields >= min cruise.
    let bestMeeting = null;
    let bestOverall = null;
    for (const fl of candidates) {
        const climb = estimateClimb(fl * 100);
        const descent = estimateDescent(fl * 100);
        const climbNM = climb.dist_nm;
        const descentNM = descent.dist_nm;
        const cruiseNM = Math.max(distance - (climbNM + descentNM), 0);
        const cruiseMin = cruiseTimeHours(cruiseNM) * 60;
        const meets = cruiseMin >= minCruiseMin;
        const rec = {
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
    if (!chosen)
        return null;
    // Ensure the recommended FL is always valid under Concorde + Non-RVSM rules.
    chosen.fl = normalizeCruiseFLByRules(chosen.fl, direction);
    const dirTxt = direction ? (direction === "E" ? "eastbound" : "westbound") : "";
    if (bestMeeting) {
        const targetTxt = chosen.cruiseMin >= targetCruiseMin ? "" : " (tight sector)";
        chosen.note = `Auto-selected FL${chosen.fl}${dirTxt ? ` (${dirTxt})` : ""} to keep ~${Math.round(chosen.cruiseMin)} min cruise${targetTxt}.`;
    }
    else {
        chosen.note = `Short sector: even at FL${chosen.fl}${dirTxt ? ` (${dirTxt})` : ""}, cruise is only ~${Math.round(chosen.cruiseMin)} min.`;
    }
    return chosen;
}
function normalizeIcao4(v) {
    const s = String(v ?? "").trim().toUpperCase();
    return /^[A-Z]{4}$/.test(s) ? s : undefined;
}
function normalizeRunwayId(v) {
    const s = String(v ?? "").trim().toUpperCase();
    // Allow: 27, 09, 30R, 04L, etc.
    // Normalize leading zeros to two digits when present.
    const m = /^(\d{1,2})([LRC])?$/.exec(s);
    if (!m)
        return undefined;
    const n = Number(m[1]);
    if (!Number.isFinite(n) || n < 1 || n > 36)
        return undefined;
    const num2 = String(n).padStart(2, "0");
    return `${num2}${m[2] ?? ""}`;
}
function normalizeCallsign(v) {
    const s = String(v ?? "").trim().toUpperCase();
    if (!s)
        return undefined;
    // Keep alnum + dashes, typical callsign length.
    const cleaned = s.replace(/[^A-Z0-9-]/g, "");
    return cleaned && cleaned.length >= 2 ? cleaned : undefined;
}
function normalizeRegistration(v) {
    const s = String(v ?? "").trim().toUpperCase();
    if (!s)
        return undefined;
    // Keep typical aircraft registration/tail formats (e.g., G-BOAC, VT-ABC, N123AB)
    const cleaned = s.replace(/[^A-Z0-9-]/g, "");
    if (!cleaned)
        return undefined;
    // Basic sanity: at least 3 chars, no trailing/leading dashes
    if (cleaned.length < 3)
        return undefined;
    if (cleaned.startsWith("-") || cleaned.endsWith("-"))
        return undefined;
    return cleaned;
}
function routeHasOriginToken(route, originIcao) {
    const r = route.trim().toUpperCase();
    const o = originIcao.trim().toUpperCase();
    return r.startsWith(o + " ") || r.startsWith(o + "/");
}
function routeHasDestToken(route, destIcao) {
    const r = route.trim().toUpperCase();
    const d = destIcao.trim().toUpperCase();
    // Accept: ... OMDB or ... OMDB/30R at the end
    return new RegExp(`\\b${d}(?:\\/[A-Z0-9]+)?\\s*$`, "i").test(r);
}
function withRouteEndpoints(route, originIcao, destIcao, depRunway, arrRunway) {
    const base = (route ?? "").trim();
    if (!base && !originIcao && !destIcao)
        return undefined;
    let r = base;
    if (originIcao) {
        const prefix = depRunway ? `${originIcao}/${depRunway}` : originIcao;
        if (!r)
            r = prefix;
        else if (!routeHasOriginToken(r, originIcao))
            r = `${prefix} ${r}`.trim();
    }
    if (destIcao) {
        const suffix = arrRunway ? `${destIcao}/${arrRunway}` : destIcao;
        if (!r)
            r = suffix;
        else if (!routeHasDestToken(r, destIcao))
            r = `${r} ${suffix}`.trim();
    }
    return r || undefined;
}
function toNumberOrUndefined(v) {
    const n = typeof v === "number" ? v : Number(String(v ?? "").trim());
    return Number.isFinite(n) ? n : undefined;
}
function toMetarLineOrUndefined(v) {
    if (typeof v !== "string")
        return undefined;
    const line = (v.split(/\r?\n/)[0] || "").trim();
    return line ? line : undefined;
}
function parseSimbriefCruiseFL(v) {
    if (v == null)
        return undefined;
    // Common SimBrief patterns: "FL590", "590", "59000" (ft), 59000 (ft)
    if (typeof v === "string") {
        const s = v.trim().toUpperCase();
        const m = /^FL\s*(\d{2,3})$/.exec(s);
        if (m) {
            const fl = Number(m[1]);
            return Number.isFinite(fl) ? fl : undefined;
        }
        const asNum = toNumberOrUndefined(s);
        if (asNum == null)
            return undefined;
        if (asNum >= 1000)
            return Math.round(asNum / 100); // feet -> FL
        return Math.round(asNum); // treat as FL
    }
    if (typeof v === "number") {
        if (!Number.isFinite(v))
            return undefined;
        if (v >= 1000)
            return Math.round(v / 100); // feet -> FL
        return Math.round(v);
    }
    return undefined;
}
function parsePaxWeightKg(value, unit) {
    const n = toNumberOrUndefined(value);
    if (n == null)
        return undefined;
    const u = String(unit ?? "").trim().toLowerCase();
    if (u.startsWith("lb"))
        return n * 0.45359237;
    if (u.startsWith("kg"))
        return n;
    // Heuristic: pax weight over 150 is almost certainly pounds.
    if (n > 150)
        return n * 0.45359237;
    return n;
}
function sumDefined(values) {
    const nums = values.filter((v) => Number.isFinite(v ?? NaN));
    if (!nums.length)
        return undefined;
    return nums.reduce((a, b) => a + b, 0);
}
function choosePaxCountCandidate(candidates) {
    const nums = candidates.filter((v) => Number.isFinite(v ?? NaN));
    if (!nums.length)
        return undefined;
    const positives = nums.filter((v) => v > 0);
    const chosen = positives.length ? Math.max(...positives) : Math.max(...nums);
    return Number.isFinite(chosen) ? Math.round(chosen) : undefined;
}
function extractSimbrief(data) {
    const ofp = data?.ofp ?? data;
    const callSign = normalizeCallsign(ofp?.general?.callsign) ??
        normalizeCallsign(ofp?.general?.atc_callsign) ??
        normalizeCallsign(ofp?.general?.call_sign) ??
        normalizeCallsign(ofp?.general?.flight_callsign) ??
        normalizeCallsign(ofp?.atc?.callsign) ??
        normalizeCallsign(ofp?.atc?.call_sign);
    const registration = normalizeRegistration(ofp?.aircraft?.registration) ??
        normalizeRegistration(ofp?.aircraft?.reg) ??
        normalizeRegistration(ofp?.aircraft?.aircraft_reg) ??
        normalizeRegistration(ofp?.general?.registration) ??
        normalizeRegistration(ofp?.general?.reg) ??
        normalizeRegistration(ofp?.general?.aircraft_reg) ??
        normalizeRegistration(ofp?.general?.tail_number) ??
        normalizeRegistration(ofp?.general?.tail) ??
        normalizeRegistration(ofp?.atc?.registration);
    const originIcao = normalizeIcao4(ofp?.origin?.icao_code) ??
        normalizeIcao4(ofp?.origin?.icao) ??
        normalizeIcao4(ofp?.general?.origin_icao) ??
        normalizeIcao4(ofp?.general?.dep_icao);
    const destIcao = normalizeIcao4(ofp?.destination?.icao_code) ??
        normalizeIcao4(ofp?.destination?.icao) ??
        normalizeIcao4(ofp?.general?.destination_icao) ??
        normalizeIcao4(ofp?.general?.arr_icao);
    const depRunway = normalizeRunwayId(ofp?.origin?.plan_rwy) ??
        normalizeRunwayId(ofp?.origin?.planned_runway) ??
        normalizeRunwayId(ofp?.origin?.runway) ??
        normalizeRunwayId(ofp?.general?.dep_rwy) ??
        normalizeRunwayId(ofp?.general?.departure_runway) ??
        normalizeRunwayId(ofp?.general?.rwy_dep);
    const arrRunway = normalizeRunwayId(ofp?.destination?.plan_rwy) ??
        normalizeRunwayId(ofp?.destination?.planned_runway) ??
        normalizeRunwayId(ofp?.destination?.runway) ??
        normalizeRunwayId(ofp?.general?.arr_rwy) ??
        normalizeRunwayId(ofp?.general?.arrival_runway) ??
        normalizeRunwayId(ofp?.general?.rwy_arr);
    const alternateIcao = normalizeIcao4(ofp?.alternate?.icao_code) ??
        normalizeIcao4(ofp?.alternate?.icao) ??
        normalizeIcao4(ofp?.alternate?.alt_icao) ??
        normalizeIcao4(ofp?.general?.alternate_icao) ??
        normalizeIcao4(ofp?.general?.alternate) ??
        normalizeIcao4(ofp?.general?.alt_icao) ??
        normalizeIcao4(ofp?.general?.altn_icao) ??
        normalizeIcao4(ofp?.general?.alternate1_icao) ??
        normalizeIcao4(ofp?.general?.alternate2_icao);
    const routeRaw = ofp?.atc?.route ??
        ofp?.general?.route ??
        ofp?.general?.route_string ??
        ofp?.navlog?.route;
    const routeBase = typeof routeRaw === "string" ? routeRaw.trim() : undefined;
    const route = withRouteEndpoints(routeBase, originIcao, destIcao, depRunway, arrRunway);
    // METARs (SimBrief often includes these; if present, we can auto-fill wind components without needing a fetch)
    const depMetar = toMetarLineOrUndefined(ofp?.origin?.metar) ??
        toMetarLineOrUndefined(ofp?.origin?.metar_raw) ??
        toMetarLineOrUndefined(ofp?.weather?.origin_metar) ??
        toMetarLineOrUndefined(ofp?.weather?.orig_metar) ??
        toMetarLineOrUndefined(ofp?.weather?.departure_metar) ??
        toMetarLineOrUndefined(ofp?.wx?.origin_metar) ??
        toMetarLineOrUndefined(ofp?.wx?.dep_metar);
    const arrMetar = toMetarLineOrUndefined(ofp?.destination?.metar) ??
        toMetarLineOrUndefined(ofp?.destination?.metar_raw) ??
        toMetarLineOrUndefined(ofp?.weather?.destination_metar) ??
        toMetarLineOrUndefined(ofp?.weather?.dest_metar) ??
        toMetarLineOrUndefined(ofp?.weather?.arrival_metar) ??
        toMetarLineOrUndefined(ofp?.wx?.destination_metar) ??
        toMetarLineOrUndefined(ofp?.wx?.arr_metar);
    // Distance keys can vary across SimBrief formats.
    const dist = toNumberOrUndefined(ofp?.general?.route_distance) ??
        toNumberOrUndefined(ofp?.general?.distance) ??
        toNumberOrUndefined(ofp?.general?.dist_nm) ??
        toNumberOrUndefined(ofp?.general?.air_distance) ??
        toNumberOrUndefined(ofp?.general?.air_distance_nm);
    const cruiseFL = parseSimbriefCruiseFL(ofp?.general?.cruise_altitude) ??
        parseSimbriefCruiseFL(ofp?.general?.cruise_altitude_ft) ??
        parseSimbriefCruiseFL(ofp?.general?.crz_alt) ??
        parseSimbriefCruiseFL(ofp?.general?.initial_altitude) ??
        parseSimbriefCruiseFL(ofp?.general?.initial_altitude_ft);
    const paxCountCandidate = choosePaxCountCandidate([
        toNumberOrUndefined(ofp?.payload?.pax_count),
        toNumberOrUndefined(ofp?.payload?.pax),
        toNumberOrUndefined(ofp?.payload?.passengers),
        toNumberOrUndefined(ofp?.general?.pax_count),
        toNumberOrUndefined(ofp?.general?.pax),
        toNumberOrUndefined(ofp?.general?.passengers),
        toNumberOrUndefined(ofp?.weights?.pax_count),
        toNumberOrUndefined(ofp?.weights?.pax),
        toNumberOrUndefined(ofp?.payload?.pax_total),
        toNumberOrUndefined(ofp?.weights?.pax_total),
        toNumberOrUndefined(ofp?.general?.pax_total),
    ]);
    const paxAdults = toNumberOrUndefined(ofp?.payload?.pax_adults) ??
        toNumberOrUndefined(ofp?.payload?.pax_adult) ??
        toNumberOrUndefined(ofp?.payload?.pax_adl);
    const paxChildren = toNumberOrUndefined(ofp?.payload?.pax_children) ??
        toNumberOrUndefined(ofp?.payload?.pax_child) ??
        toNumberOrUndefined(ofp?.payload?.pax_chd);
    const paxInfants = toNumberOrUndefined(ofp?.payload?.pax_infants) ??
        toNumberOrUndefined(ofp?.payload?.pax_infant) ??
        toNumberOrUndefined(ofp?.payload?.pax_inf);
    const paxGroupSum = sumDefined([paxAdults, paxChildren, paxInfants]);
    // Prefer a positive group sum; if the group sum is zero, fall back to the candidate count when available.
    const paxCount = paxGroupSum != null && paxGroupSum > 0
        ? paxGroupSum
        : Math.max(0, paxCountCandidate ?? paxGroupSum ?? NaN);
    const paxCountFinal = Number.isFinite(paxCount) ? paxCount : undefined;
    const paxWeightRaw = ofp?.payload?.pax_weight ??
        ofp?.payload?.pax_wt ??
        ofp?.weights?.pax_weight ??
        ofp?.general?.pax_weight ??
        ofp?.payload?.pax_weight_kg ??
        ofp?.weights?.pax_weight_kg ??
        ofp?.general?.pax_weight_kg ??
        ofp?.payload?.pax_weight_total ??
        ofp?.weights?.pax_weight_total;
    const paxWeightUnit = ofp?.payload?.pax_weight_unit ??
        ofp?.weights?.pax_weight_unit ??
        ofp?.general?.pax_weight_unit ??
        ofp?.payload?.weight_unit ??
        ofp?.weights?.weight_unit ??
        ofp?.general?.weight_unit;
    const paxWeightKgRaw = parsePaxWeightKg(paxWeightRaw, paxWeightUnit);
    let paxWeightKg = paxWeightKgRaw;
    if (paxWeightKgRaw != null && paxCountFinal && paxCountFinal > 0) {
        const perPax = paxWeightKgRaw / paxCountFinal;
        if (perPax >= 50 && perPax <= 130)
            paxWeightKg = perPax;
    }
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
        paxCount: paxCountFinal,
        paxWeightKg,
    };
}
async function fetchSimbrief(usernameOrId) {
    const u = String(usernameOrId ?? "").trim();
    if (!u)
        throw new Error("Enter a SimBrief username/ID.");
    // SimBrief JSON endpoint
    const url = `https://www.simbrief.com/api/xml.fetcher.php?username=${encodeURIComponent(u)}&json=1`;
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok)
        throw new Error(`SimBrief fetch failed (${res.status}).`);
    const data = await res.json();
    const extracted = extractSimbrief(data);
    // Helpful error if the payload is not what we expect.
    if (!extracted.originIcao && !extracted.destIcao && !extracted.route && !extracted.distanceNm) {
        throw new Error("SimBrief response parsed, but expected fields were not found. (Check console for raw JSON)");
    }
    return extracted;
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
        pax_mass_kg: 84,
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
const CRUISE_CLIMB_STEP_FL = 20;
const CRUISE_CLIMB_START_FL = 500;
const SUPR_ACCEL_NM = 90;
const SUPR_ACCEL_TIME_H = 12 / 60;
function cruiseTasKtForFL(fl) {
    const clamped = clampCruiseFL(fl);
    if (clamped < 500) {
        // Sub/transonic sector approximation for short missions.
        const x = Math.max(0, Math.min(1, (clamped - 250) / 250));
        return 520 + 340 * x;
    }
    // Supersonic TAS increases slightly as cruise-climb progresses.
    const x = Math.max(0, Math.min(1, (clamped - 500) / 90));
    return 1135 + 55 * x;
}
function cruiseBurnKgPerNmAtFL(fl) {
    const base = CONSTANTS.fuel.burn_kg_per_nm * altitudeBurnFactor(fl);
    // Sub/transonic sectors are less efficient per NM than stabilized supersonic cruise.
    const shortSectorPenalty = fl < 500 ? 1.15 : 1;
    return base * shortSectorPenalty;
}
function buildCruiseClimbLevels(initialFL, targetFL) {
    const start = clampCruiseFL(initialFL);
    const end = clampCruiseFL(targetFL);
    if (end <= start)
        return [end];
    const levels = [];
    for (let fl = start; fl <= end; fl += CRUISE_CLIMB_STEP_FL)
        levels.push(fl);
    if (levels[levels.length - 1] !== end)
        levels.push(end);
    return levels;
}
function buildCruiseMissionProfile(plannedDistanceNM, selectedCruiseFL) {
    const distanceNM = Math.max(Number(plannedDistanceNM) || 0, 0);
    const targetFL = clampCruiseFL(selectedCruiseFL);
    const initialCruiseFL = targetFL >= CRUISE_CLIMB_START_FL ? CRUISE_CLIMB_START_FL : targetFL;
    const climb = estimateClimb(initialCruiseFL * 100);
    const descent = estimateDescent(Math.max(targetFL, initialCruiseFL) * 100);
    const coreRemainingNM = Math.max(distanceNM - (climb.dist_nm + descent.dist_nm), 0);
    const useSupersonicAccel = targetFL >= CRUISE_CLIMB_START_FL;
    const accelDistNM = useSupersonicAccel ? Math.min(SUPR_ACCEL_NM, coreRemainingNM * 0.4) : 0;
    const accelTimeH = useSupersonicAccel && SUPR_ACCEL_NM > 0 ? SUPR_ACCEL_TIME_H * (accelDistNM / SUPR_ACCEL_NM) : 0;
    const accelBurnKg = accelDistNM *
        (cruiseBurnKgPerNmAtFL(initialCruiseFL) * 2.1);
    const cruiseNM = Math.max(coreRemainingNM - accelDistNM, 0);
    const cruiseLevels = buildCruiseClimbLevels(initialCruiseFL, targetFL);
    const weights = cruiseLevels.map((_, i) => {
        if (cruiseLevels.length <= 1)
            return 1;
        const x = i / (cruiseLevels.length - 1);
        // Slightly bias distance toward higher FLs as weight burns off.
        return 0.8 + 0.5 * x;
    });
    const weightSum = Math.max(weights.reduce((s, w) => s + w, 0), 1);
    const cruiseSegments = cruiseLevels.map((fl, i) => {
        const segmentNM = cruiseNM * (weights[i] / weightSum);
        const tasKT = Math.max(cruiseTasKtForFL(fl), 1);
        const burnKgPerNm = cruiseBurnKgPerNmAtFL(fl);
        const timeH = segmentNM / tasKT;
        const burnKg = segmentNM * burnKgPerNm;
        return {
            fl,
            dist_nm: segmentNM,
            time_h: timeH,
            burn_kg: burnKg,
            burn_kg_per_nm: burnKgPerNm,
            tas_kt: tasKT,
        };
    });
    const cruiseTimeH = cruiseSegments.reduce((s, seg) => s + seg.time_h, 0);
    const cruiseKg = cruiseSegments.reduce((s, seg) => s + seg.burn_kg, 0);
    const climbKg = climb.dist_nm *
        cruiseBurnKgPerNmAtFL(initialCruiseFL) *
        CONSTANTS.fuel.climb_factor;
    const descentKg = descent.dist_nm *
        cruiseBurnKgPerNmAtFL(Math.max(targetFL, initialCruiseFL)) *
        CONSTANTS.fuel.descent_factor;
    const avgCruiseBurnKgPerNm = cruiseNM > 0
        ? cruiseKg / cruiseNM
        : cruiseBurnKgPerNmAtFL(targetFL);
    const avgCruiseTasKt = cruiseTimeH > 0
        ? cruiseNM / cruiseTimeH
        : cruiseTasKtForFL(targetFL);
    const tripKg = Math.max(climbKg + accelBurnKg + cruiseKg + descentKg, 0);
    const totalTimeH = Math.max(climb.time_h + accelTimeH + cruiseTimeH + descent.time_h, 0);
    return {
        climb,
        accel: { time_h: accelTimeH, dist_nm: accelDistNM },
        cruise: { time_h: cruiseTimeH, dist_nm: cruiseNM },
        descent,
        cruise_segments: cruiseSegments,
        climb_kg: climbKg,
        accel_kg: accelBurnKg,
        cruise_kg: cruiseKg,
        descent_kg: descentKg,
        trip_kg: tripKg,
        total_time_h: totalTimeH,
        avg_cruise_burn_kg_per_nm: avgCruiseBurnKgPerNm,
        avg_cruise_tas_kt: avgCruiseTasKt,
        initial_cruise_fl: initialCruiseFL,
        target_cruise_fl: targetFL,
    };
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
function takeoffFeasibleM(runwayLengthM, takeoffWeightKg, env) {
    const mtow = CONSTANTS.weights.mtow_kg;
    const baseReq = CONSTANTS.runway.min_takeoff_m_at_mtow;
    const ratio = Math.max(Math.min(takeoffWeightKg / mtow, 1.2), 0.5);
    const baseRequired = baseReq * ratio;
    const correction = runwayLengthCorrectionFactor("takeoff", env);
    const required = baseRequired * correction.factor;
    return {
        base_required_length_m_est: baseRequired,
        required_length_m_est: required,
        runway_length_m: runwayLengthM,
        feasible: runwayLengthM >= required,
        correction_factor: correction.factor,
        correction_breakdown_pct: correction.breakdownPct,
        correction_inputs: correction.inputs,
    };
}
function landingFeasibleM(runwayLengthM, landingWeightKg, env) {
    const mlw = CONSTANTS.weights.mlw_kg;
    const baseReq = CONSTANTS.runway.min_landing_m_at_mlw;
    const ratio = Math.max(Math.min((landingWeightKg || mlw) / mlw, 1.3), 0.6);
    const baseRequired = baseReq * Math.pow(ratio, 1.15);
    const correction = runwayLengthCorrectionFactor("landing", env);
    const required = baseRequired * correction.factor;
    return {
        base_required_length_m_est: baseRequired,
        required_length_m_est: required,
        runway_length_m: runwayLengthM,
        feasible: runwayLengthM >= required,
        correction_factor: correction.factor,
        correction_breakdown_pct: correction.breakdownPct,
        correction_inputs: correction.inputs,
    };
}
function qnhToHpa(qnh) {
    if (!qnh || !Number.isFinite(qnh.value))
        return null;
    if (qnh.unit === "hPa")
        return qnh.value;
    return qnh.value * 33.8638866667;
}
function isaTempCAtElevationFt(elevationFt) {
    return 15 - 1.98 * (elevationFt / 1000);
}
function runwayLengthCorrectionFactor(phase, env) {
    const runwayElevFt = Number.isFinite(env?.runwayElevFt ?? NaN) ? env?.runwayElevFt : 0;
    const qnhHpa = qnhToHpa(env?.qnh);
    const pressureAltFt = qnhHpa == null ? null : runwayElevFt + (1013.25 - qnhHpa) * 30;
    const isaTempC = isaTempCAtElevationFt(runwayElevFt);
    const oatC = Number.isFinite(env?.oatC ?? NaN) ? env?.oatC : null;
    const headwindKt = Number.isFinite(env?.headwindKt ?? NaN) ? env?.headwindKt : null;
    // Pressure altitude penalty.
    // Takeoff: +1.2% / 1000 ft above MSL, slight benefit when below.
    // Landing: +0.7% / 1000 ft above MSL, slight benefit when below.
    const pressurePctRaw = pressureAltFt == null
        ? 0
        : phase === "takeoff"
            ? (pressureAltFt / 1000) * 0.012
            : (pressureAltFt / 1000) * 0.007;
    const pressurePct = Math.max(Math.min(pressurePctRaw, 0.35), -0.08);
    // Temperature correction based on ISA deviation at runway elevation.
    const tempDelta = oatC == null ? null : oatC - isaTempC;
    let temperaturePct = 0;
    if (tempDelta != null) {
        if (phase === "takeoff") {
            temperaturePct = tempDelta >= 0 ? tempDelta * 0.01 : tempDelta * 0.004;
        }
        else {
            temperaturePct = tempDelta >= 0 ? tempDelta * 0.005 : tempDelta * 0.002;
        }
    }
    temperaturePct = Math.max(Math.min(temperaturePct, 0.35), -0.1);
    // Wind correction by headwind component.
    // Tailwind is strongly penalized, headwind gives limited credit.
    let windPct = 0;
    if (headwindKt != null) {
        if (headwindKt >= 0) {
            windPct = phase === "takeoff" ? -Math.min(headwindKt * 0.01, 0.2) : -Math.min(headwindKt * 0.01, 0.15);
        }
        else {
            const tailwind = Math.abs(headwindKt);
            windPct = phase === "takeoff" ? Math.min(tailwind * 0.03, 0.5) : Math.min(tailwind * 0.04, 0.65);
        }
    }
    const totalPct = pressurePct + temperaturePct + windPct;
    const factor = Math.max(0.7, 1 + totalPct);
    return {
        factor,
        breakdownPct: {
            pressure: pressurePct * 100,
            temperature: temperaturePct * 100,
            wind: windPct * 100,
            total: (factor - 1) * 100,
        },
        inputs: {
            runway_elev_ft: runwayElevFt,
            pressure_alt_ft: pressureAltFt,
            isa_temp_c: oatC == null ? null : isaTempC,
            oat_c: oatC,
            headwind_kt: headwindKt,
        },
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
function parseMetarQnh(raw) {
    const qMatch = raw.match(/\bQ(\d{4})\b/);
    if (qMatch)
        return { unit: "hPa", value: parseInt(qMatch[1], 10) };
    const aMatch = raw.match(/\bA(\d{4})\b/);
    if (aMatch)
        return { unit: "inHg", value: parseInt(aMatch[1], 10) / 100 };
    return null;
}
function parseMetarTempC(raw) {
    const m = raw.match(/\b(M?\d{2})\/(M?\d{2})\b/);
    if (!m)
        return null;
    const toNum = (v) => (v.startsWith("M") ? -parseInt(v.slice(1), 10) : parseInt(v, 10));
    const temp = toNum(m[1]);
    return Number.isFinite(temp) ? temp : null;
}
function parseMetarVisibilityKm(raw) {
    const upper = raw.toUpperCase();
    if (upper.includes("CAVOK"))
        return 10;
    const tokens = upper.split(/\s+/).filter(Boolean);
    const smIndex = tokens.findIndex((t) => t.endsWith("SM"));
    if (smIndex >= 0) {
        const token = tokens[smIndex].replace("SM", "");
        const prev = smIndex > 0 ? tokens[smIndex - 1] : "";
        const parseFraction = (v) => {
            const parts = v.split("/");
            if (parts.length !== 2)
                return NaN;
            const num = Number(parts[0]);
            const den = Number(parts[1]);
            if (!Number.isFinite(num) || !Number.isFinite(den) || den === 0)
                return NaN;
            return num / den;
        };
        let miles = 0;
        if (prev && /^\d+$/.test(prev))
            miles += parseInt(prev, 10);
        if (token.includes("/"))
            miles += parseFraction(token);
        else if (token)
            miles += Number(token);
        return Number.isFinite(miles) ? miles * 1.60934 : null;
    }
    for (const token of tokens) {
        if (/^(METAR|SPECI|AUTO|COR)$/i.test(token))
            continue;
        if (/^\d{6}Z$/.test(token))
            continue;
        if (/^(VRB|\d{3})\d{2}(G\d{2})?KT$/.test(token))
            continue;
        if (/^(A|Q)\d{4}$/.test(token))
            continue;
        if (/^R\d{2}[LRC]?\/\d{4}/.test(token))
            continue;
        if (/^(FEW|SCT|BKN|OVC|VV)\d{3}/.test(token))
            continue;
        if (token.includes("/"))
            continue;
        if (/^\d{4}$/.test(token)) {
            const meters = Number(token);
            if (!Number.isFinite(meters))
                continue;
            if (meters >= 9999)
                return 10;
            return meters / 1000;
        }
    }
    return null;
}
function parseMetarWeatherSummary(raw) {
    const upper = raw.toUpperCase();
    const tokens = upper.split(/\s+/).filter(Boolean);
    for (const token of tokens) {
        if (/^(METAR|SPECI|AUTO|COR)$/i.test(token))
            continue;
        if (/^\d{6}Z$/.test(token))
            continue;
        if (/^(VRB|\d{3})\d{2}(G\d{2})?KT$/.test(token))
            continue;
        if (/^\d{4}$/.test(token))
            continue;
        if (/^(A|Q)\d{4}$/.test(token))
            continue;
        if (/^[A-Z]{4}$/.test(token))
            continue;
        if (/^R\d{2}[LRC]?\/\d{4}/.test(token))
            continue;
        if (/^(FEW|SCT|BKN|OVC|VV)\d{3}/.test(token))
            continue;
        if (/^(SKC|CLR|NSC)$/.test(token))
            continue;
        if (token.includes("/"))
            continue;
        const cleaned = token.replace(/^(VC|\+|-)/, "");
        const hasTS = cleaned.includes("TS");
        const hasFZ = cleaned.includes("FZ");
        const hasSH = cleaned.includes("SH");
        if (cleaned.includes("FG")) {
            return { label: hasFZ ? "Freezing fog" : "Fog" };
        }
        if (cleaned.includes("BR"))
            return { label: "Mist" };
        if (cleaned.includes("HZ") || cleaned.includes("FU") || cleaned.includes("DU") || cleaned.includes("SA"))
            return { label: "Haze" };
        if (hasTS)
            return { label: "Thunderstorm" };
        if (cleaned.includes("RA") || cleaned.includes("DZ")) {
            return { label: hasFZ ? "Freezing rain" : hasSH ? "Showers" : "Rain" };
        }
        if (cleaned.includes("SN") || cleaned.includes("SG") || cleaned.includes("PL") || cleaned.includes("IC"))
            return { label: "Snow" };
    }
    if (upper.includes("OVC"))
        return { label: "Overcast" };
    if (upper.includes("BKN"))
        return { label: "Broken clouds" };
    if (upper.includes("SCT"))
        return { label: "Scattered clouds" };
    if (upper.includes("FEW"))
        return { label: "Few clouds" };
    if (upper.includes("SKC") || upper.includes("CLR") || upper.includes("NSC"))
        return { label: "Clear" };
    return null;
}
function parseMetarFlightCategory(raw) {
    const upper = raw.toUpperCase();
    let visSm = null;
    const sm = upper.match(/\b(\d+)(?:\s?)(?:SM)\b/);
    if (sm) {
        visSm = parseInt(sm[1], 10);
    }
    else {
        const meters = upper.match(/\b(\d{4})\b/);
        if (meters)
            visSm = parseInt(meters[1], 10) / 1609.344;
    }
    let ceilingFt = null;
    const layers = upper.match(/\b(BKN|OVC|VV)(\d{3})\b/g);
    if (layers) {
        for (const layer of layers) {
            const h = layer.match(/(BKN|OVC|VV)(\d{3})/);
            if (!h)
                continue;
            const ft = parseInt(h[2], 10) * 100;
            if (ceilingFt == null || ft < ceilingFt)
                ceilingFt = ft;
        }
    }
    if (visSm == null && ceilingFt == null)
        return "UNKNOWN";
    if ((visSm != null && visSm < 1) || (ceilingFt != null && ceilingFt < 500))
        return "LIFR";
    if ((visSm != null && visSm < 3) || (ceilingFt != null && ceilingFt < 1000))
        return "IFR";
    if ((visSm != null && visSm < 5) || (ceilingFt != null && ceilingFt < 3000))
        return "MVFR";
    return "VFR";
}
function flightCategoryTone(category) {
    if (category === "LIFR")
        return "lifr";
    if (category === "IFR")
        return "error";
    if (category === "MVFR")
        return "warning";
    if (category === "VFR")
        return "ok";
    return "neutral";
}
function flightCategoryStripClass(category) {
    switch (category) {
        case "LIFR":
            return "border-fuchsia-400/40 bg-fuchsia-500/15";
        case "IFR":
            return "border-rose-400/40 bg-rose-500/10";
        case "MVFR":
            return "border-amber-400/40 bg-amber-500/10";
        case "VFR":
            return "border-emerald-400/30 bg-emerald-500/10";
        default:
            return "border-white/10 bg-white/5";
    }
}
function windComponents(windDirDeg, windSpeedKt, runwayHeadingDeg) {
    if (windDirDeg == null || windSpeedKt == null)
        return { headwind_kt: null, crosswind_kt: null, crosswind_dir: null };
    const theta = (((windDirDeg - runwayHeadingDeg) % 360) + 360) % 360;
    const rad = toRad(theta);
    const head = windSpeedKt * Math.cos(rad);
    const crossSigned = windSpeedKt * Math.sin(rad);
    const cross = Math.abs(crossSigned);
    return {
        headwind_kt: Math.round(head * 10) / 10,
        crosswind_kt: Math.round(cross * 10) / 10,
        crosswind_dir: crossSigned === 0 ? null : crossSigned > 0 ? "R" : "L",
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
const NAVAIDS_CSV_URL = "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv";
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
        const elevationFt = Number(a?.elevation_ft);
        airportsMap[ident] = airportsMap[ident] || {
            name: a?.name || ident,
            lat,
            lon,
            elevation_ft: Number.isFinite(elevationFt) ? Math.round(elevationFt) : undefined,
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
        const leElev = Number(r?.le_elevation_ft);
        const heElev = Number(r?.he_elevation_ft);
        const leElevationFt = Number.isFinite(leElev) ? Math.round(leElev) : undefined;
        const heElevationFt = Number.isFinite(heElev) ? Math.round(heElev) : undefined;
        if (leIdent)
            airport.runways.push({
                id: leIdent,
                heading: Math.round(Number.isFinite(leHdg) ? leHdg : 0),
                length_m: lengthM,
                elevation_ft: leElevationFt,
            });
        if (heIdent)
            airport.runways.push({
                id: heIdent,
                heading: Math.round(Number.isFinite(heHdg) ? heHdg : 0),
                length_m: lengthM,
                elevation_ft: heElevationFt,
            });
    }
    return airportsMap;
}
function buildNavaidsDB(navaidsCsvText) {
    const rows = Papa.parse(navaidsCsvText, {
        header: true,
        skipEmptyLines: true,
    }).data;
    const navaids = {};
    for (const r of rows) {
        const ident = (r?.ident || "").trim().toUpperCase();
        if (!ident)
            continue;
        const lat = parseFloat(r?.latitude_deg ?? "");
        const lon = parseFloat(r?.longitude_deg ?? "");
        if (!Number.isFinite(lat) || !Number.isFinite(lon))
            continue;
        const entry = {
            ident,
            lat,
            lon,
            type: (r?.type || "NAVAID").toString(),
            name: (r?.name || ident).toString(),
        };
        if (!navaids[ident])
            navaids[ident] = [];
        navaids[ident].push(entry);
    }
    return navaids;
}
const LATLON_RE = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const AIRWAY_RE = /^[A-Z]{1,2}\d{1,3}$/;
const PROCEDURE_RE = /^(DCT|SID[A-Z0-9-]*|STAR[A-Z0-9-]*|VIA|VECTOR)$/;
function pickBestNavaidForRoute(ident, candidates, depInfo, arrInfo) {
    if (!candidates || candidates.length === 0)
        return null;
    if (!depInfo || !arrInfo)
        return candidates[0];
    // Choose candidate closest to the DEP->ARR corridor (min extra detour distance)
    const direct = greatCircleNM(depInfo.lat, depInfo.lon, arrInfo.lat, arrInfo.lon);
    let best = candidates[0];
    let bestExtra = Number.POSITIVE_INFINITY;
    for (const c of candidates) {
        const via = greatCircleNM(depInfo.lat, depInfo.lon, c.lat, c.lon) +
            greatCircleNM(c.lat, c.lon, arrInfo.lat, arrInfo.lon);
        const extra = via - direct;
        if (extra < bestExtra) {
            bestExtra = extra;
            best = c;
        }
    }
    return best;
}
function extractRouteEndpoints(tokens, airportsIndex) {
    const airportTokens = tokens.filter((t) => t.length === 4 && airportsIndex?.[t]);
    if (airportTokens.length >= 2) {
        return { dep: airportTokens[0], arr: airportTokens[airportTokens.length - 1] };
    }
    return {};
}
function normalizeRouteToken(raw) {
    const t0 = (raw || "").trim().toUpperCase();
    if (!t0)
        return null;
    // Remove common punctuation that shows up in OFP strings.
    const t = t0.replace(/[(),;]/g, "").replace(/\.+$/g, "");
    if (!t)
        return null;
    // Handle airport tokens with runway suffixes, e.g. "VIDP/27", "OMDB/30R".
    // We want the ICAO to resolve DEP/ARR correctly.
    const airportWithRw = /^([A-Z]{4})(?:\/[A-Z0-9]+)?$/;
    const m = airportWithRw.exec(t);
    if (m)
        return m[1];
    return t;
}
function parseRouteString(str) {
    if (!str)
        return [];
    return str
        .split(/\s+/)
        .map(normalizeRouteToken)
        .filter((t) => Boolean(t));
}
function resolveRouteTokens(tokens, airportsIndex, navaidsIndex, ctx) {
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
const Card = ({ title, children, right }) => (_jsxs("section", { className: "efb-surface p-6 transition-colors duration-500 hover:bg-white/10", children: [_jsxs("div", { className: "flex items-center justify-between mb-5", children: [_jsx("h2", { className: "text-lg font-semibold text-white/90", children: title }), right] }), children] }));
const Row = ({ children, cols = 2 }) => (_jsx("div", { className: `grid gap-6 ${cols === 3
        ? "grid-cols-1 md:grid-cols-3"
        : cols === 4
            ? "grid-cols-2 lg:grid-cols-4"
            : "grid-cols-1 md:grid-cols-2"}`, children: children }));
const Label = ({ children }) => (_jsx("label", { className: "efb-label block mb-2 ml-1", children: children }));
const SectionHeader = ({ children }) => (_jsx("div", { className: "text-sm font-semibold text-white/80 mt-4 mb-2", children: children }));
const Divider = () => _jsx("div", { className: "h-px bg-white/10 my-4" });
const Input = ({ className, ...props }) => (_jsx("input", { ...props, className: `efb-input ${className ?? ""}`.trim() }));
const Select = ({ className, ...props }) => (_jsx("select", { ...props, className: `efb-input appearance-none ${className ?? ""}`.trim() }));
const Button = ({ children, variant = "primary", className, ...props }) => (_jsx("button", { ...props, className: `rounded-2xl px-5 py-2.5 text-sm font-medium transition-all active:scale-95 disabled:opacity-50 disabled:pointer-events-none ${variant === "primary"
        ? "bg-[#0a84ff] text-white shadow-[0_14px_30px_-12px_rgba(10,132,255,0.9)] hover:bg-[#0c8fff]"
        : "bg-white/5 text-white/80 border border-white/10 hover:bg-white/10"} ${className ?? ""}`.trim(), children: children }));
const ThemeToggle = ({ theme, onToggle }) => {
    const isLight = theme === "light";
    return (_jsxs("button", { type: "button", onClick: onToggle, "aria-pressed": isLight, "aria-label": `Switch to ${isLight ? "dark" : "light"} mode`, className: "theme-toggle group relative inline-flex h-7 w-28 items-center rounded-full border border-white/10 bg-white/5 p-1 text-[9px] font-semibold uppercase tracking-[0.24em] text-white/60 transition hover:bg-white/10", children: [_jsxs("span", { className: "pointer-events-none relative z-10 grid w-full grid-cols-2 text-center", children: [_jsx("span", { className: `transition ${!isLight ? "text-white/90" : "text-white/50"}`, children: "Dark" }), _jsx("span", { className: `transition ${isLight ? "text-white/90" : "text-white/50"}`, children: "Light" })] }), _jsx("span", { "aria-hidden": "true", className: `theme-toggle-thumb absolute left-1 top-1 bottom-1 w-[calc(50%-4px)] rounded-full border border-white/10 bg-white/10 shadow transition ${isLight ? "translate-x-full" : "translate-x-0"}` })] }));
};
const LinkButton = ({ href, children, variant = "ghost", className, title }) => (_jsx("a", { href: href, target: "_blank", rel: "noreferrer", title: title, className: `inline-flex items-center justify-center rounded-2xl px-5 py-2.5 text-sm font-medium transition-all active:scale-95 ${variant === "primary"
        ? "bg-[#0a84ff] text-white shadow-[0_14px_30px_-12px_rgba(10,132,255,0.9)] hover:bg-[#0c8fff]"
        : "bg-white/5 text-white/80 border border-white/10 hover:bg-white/10"} ${className ?? ""}`.trim(), children: children }));
function StatPill({ label, value, ok }) {
    const valueClass = ok === undefined ? "text-white/90" : ok ? "text-emerald-300" : "text-rose-300";
    return (_jsxs("div", { className: "flex flex-col items-end", children: [_jsx("span", { className: "text-[10px] font-semibold uppercase tracking-[0.28em] text-white/35", children: label }), _jsx("span", { className: `text-sm font-medium ${valueClass}`, children: value })] }));
}
const STATUS_TONE_CLASS = {
    ok: UI_TOKENS.statusPill.ok,
    warning: UI_TOKENS.statusPill.warning,
    error: UI_TOKENS.statusPill.error,
    lifr: UI_TOKENS.statusPill.lifr,
    neutral: UI_TOKENS.statusPill.neutral,
};
const StatusPill = ({ tone, children, className }) => (_jsx("span", { className: `${UI_TOKENS.statusPill.base} ${STATUS_TONE_CLASS[tone]} ${className ?? ""}`.trim(), children: children }));
const WindSummaryChip = ({ windDir, windSpeed, windGust }) => {
    const hasSpeed = Number.isFinite(windSpeed ?? NaN);
    const hasDir = Number.isFinite(windDir ?? NaN);
    const dirText = hasDir ? `${String(Math.round(windDir)).padStart(3, "0")}°` : "VRB";
    const speedText = hasSpeed ? `${Math.round(windSpeed)}` : "—";
    const gustText = Number.isFinite(windGust ?? NaN) ? `G${Math.round(windGust)}` : "";
    return (_jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "Wind" }), _jsx("span", { className: "font-semibold text-white/90", children: hasSpeed ? `${dirText} ${speedText}${gustText} kt` : "—" })] }));
};
const VisibilityChip = ({ visibilityKm }) => {
    const val = visibilityKm == null
        ? "—"
        : visibilityKm >= 10
            ? "10+ km"
            : `${visibilityKm.toFixed(1)} km`;
    return (_jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "Vis" }), _jsx("span", { className: "font-semibold text-white/90", children: val })] }));
};
const RunwayWindViz = ({ runwayHeading, windDir }) => {
    const relWind = runwayHeading == null || windDir == null ? null : ((windDir - runwayHeading) % 360 + 360) % 360;
    const arrowRotation = relWind == null ? null : (relWind + 180) % 360;
    return (_jsxs("div", { className: "relative h-12 w-12 rounded-2xl border border-white/10 bg-black/30", children: [_jsx("div", { className: "absolute inset-0 flex items-center justify-center", children: _jsx("div", { className: "h-9 w-1 rounded-full bg-white/50" }) }), arrowRotation != null && (_jsx("div", { className: "absolute inset-0 flex items-center justify-center", children: _jsx("svg", { viewBox: "0 0 24 24", className: "h-6 w-6 text-sky-300", style: { transform: `rotate(${Math.round(arrowRotation)}deg)` }, "aria-hidden": "true", children: _jsx("path", { d: "M12 2l6 8h-4v12h-4V10H6z", fill: "currentColor" }) }) })), _jsx("div", { className: "absolute bottom-1 right-1 text-[9px] font-semibold text-white/50", children: runwayHeading != null ? Math.round(runwayHeading) : "—" })] }));
};
function HHMM({ hours }) {
    const totalMinutes = Math.round(hours * 60);
    const hh = Math.floor(totalMinutes / 60);
    const mm = totalMinutes % 60;
    return (_jsxs("span", { children: [hh, _jsx("span", { className: "ml-1 text-xs text-white/40", children: "h" }), " ", mm, _jsx("span", { className: "ml-1 text-xs text-white/40", children: "m" })] }));
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
        const calm = takeoffFeasibleM(4000, CONSTANTS.weights.mtow_kg, { headwindKt: 0 });
        const tail = takeoffFeasibleM(4000, CONSTANTS.weights.mtow_kg, { headwindKt: -10 });
        results.push({
            name: "T/O correction: 10 kt tailwind increases required length",
            pass: tail.required_length_m_est > calm.required_length_m_est,
            values: { calm: calm.required_length_m_est, tail: tail.required_length_m_est },
        });
    }
    catch (e) {
        results.push({ name: "takeoff tailwind correction throws", pass: false, err: String(e) });
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
            CPT: [{ ident: "CPT", lat: 51.514, lon: -1.005, type: "NAVAID", name: "CPT" }],
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
        const p = buildCruiseMissionProfile(3200, 590);
        results.push({
            name: "cruise-climb profile builds multi-FL cruise",
            pass: p.cruise_segments.length >= 3 && p.cruise.dist_nm > 0 && p.target_cruise_fl >= p.initial_cruise_fl,
            values: {
                segments: p.cruise_segments.length,
                cruiseNM: p.cruise.dist_nm,
                initialFL: p.initial_cruise_fl,
                targetFL: p.target_cruise_fl,
            },
        });
    }
    catch (e) {
        results.push({ name: "cruise-climb profile throws", pass: false, err: String(e) });
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
        const p = buildCruiseMissionProfile(2000, 580);
        results.push({
            name: "manual distance yields finite mission profile",
            pass: Number.isFinite(p.total_time_h) && p.total_time_h >= 0 && Number.isFinite(p.trip_kg) && p.trip_kg >= 0,
            values: { totalTimeH: p.total_time_h, tripKg: p.trip_kg },
        });
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
function readStoredTheme() {
    if (typeof window === "undefined")
        return null;
    try {
        const stored = localStorage.getItem("efb-theme");
        if (stored === "light" || stored === "dark")
            return stored;
    }
    catch {
        // Ignore storage access failures.
    }
    return null;
}
function resolveInitialTheme() {
    return readStoredTheme() ?? "dark";
}
function ConcordePlannerCanvas() {
    const [airports, setAirports] = useState({});
    const [dbLoaded, setDbLoaded] = useState(false);
    const [dbError, setDbError] = useState("");
    const [navaids, setNavaids] = useState({});
    const [depIcao, setDepIcao] = useState("EGLL");
    const [depRw, setDepRw] = useState("");
    const [arrIcao, setArrIcao] = useState("KJFK");
    const [arrRw, setArrRw] = useState("");
    const [manualDistanceNM, setManualDistanceNM] = useState(0);
    const [routeText, setRouteText] = useState("");
    const [routeDistanceNM, setRouteDistanceNM] = useState(null);
    const [routeInfo, setRouteInfo] = useState(null);
    const [routeNotice, setRouteNotice] = useState("");
    const [simbriefUser, setSimbriefUser] = useState(() => {
        try {
            return localStorage.getItem("simbrief_user") || "";
        }
        catch {
            return "";
        }
    });
    const [simbriefNotice, setSimbriefNotice] = useState("");
    const [simbriefCallSign, setSimbriefCallSign] = useState("");
    const [simbriefRegistration, setSimbriefRegistration] = useState("");
    const [simbriefPaxCount, setSimbriefPaxCount] = useState(null);
    const [simbriefPaxWeightKg, setSimbriefPaxWeightKg] = useState(null);
    const [simbriefLoading, setSimbriefLoading] = useState(false);
    const [simbriefImported, setSimbriefImported] = useState(false);
    const [simbriefSnapshot, setSimbriefSnapshot] = useState(null);
    const [simbriefStaleReason, setSimbriefStaleReason] = useState("");
    const [plannedDistanceOverridden, setPlannedDistanceOverridden] = useState(false);
    const [distanceSource, setDistanceSource] = useState("none");
    const [simbriefCruiseFL, setSimbriefCruiseFL] = useState(null);
    const simbriefRouteSetRef = useRef(false);
    const lastAutoDistanceRef = useRef(null);
    const cruiseFLFocusValueRef = useRef(null);
    const cruiseFLEditedRef = useRef(false);
    const [altIcao, setAltIcao] = useState("");
    const [trimTankKg, setTrimTankKg] = useState(0);
    // Start at a valid non-RVSM level (580 is NOT valid).
    const INITIAL_CRUISE_FL = 590;
    const [cruiseFL, setCruiseFL] = useState(INITIAL_CRUISE_FL);
    const [cruiseFLText, setCruiseFLText] = useState(String(INITIAL_CRUISE_FL));
    const [cruiseFLNotice, setCruiseFLNotice] = useState("");
    // If true, user has overridden FL and we should not auto-change it from distance.
    const [cruiseFLTouched, setCruiseFLTouched] = useState(false);
    const [taxiKg, setTaxiKg] = useState(2500);
    const [contingencyPct, setContingencyPct] = useState(5);
    const [finalReserveKg, setFinalReserveKg] = useState(3600);
    const [metarDep, setMetarDep] = useState("");
    const [metarArr, setMetarArr] = useState("");
    const [metarErr, setMetarErr] = useState("");
    const [tests, setTests] = useState([]);
    const [showDiagnostics, setShowDiagnostics] = useState(false);
    const [appIconMode, setAppIconMode] = useState("primary");
    const [theme, setTheme] = useState(resolveInitialTheme);
    const [themeStored, setThemeStored] = useState(() => readStoredTheme() !== null);
    const [updateAvailable, setUpdateAvailable] = useState(false);
    const [updateVersion, setUpdateVersion] = useState(null);
    useEffect(() => {
        console.log(`[ConcordeEFB.tsx] v${APP_VERSION}`);
        document.title = `Concorde EFB v${APP_VERSION}`;
    }, []);
    useEffect(() => {
        let active = true;
        const isTauri = typeof window !== "undefined" &&
            ("__TAURI__" in window || "__TAURI_INTERNALS__" in window);
        const checkForUpdates = async () => {
            try {
                if (isTauri) {
                    const { check } = await import("@tauri-apps/plugin-updater");
                    const update = await check();
                    if (!active || !update?.available)
                        return;
                    const nextVersion = normalizeVersionTag(update.version ?? null);
                    setUpdateAvailable(true);
                    setUpdateVersion(nextVersion || (update.version ?? null));
                    return;
                }
                let cachedLatestVersion = null;
                try {
                    const raw = localStorage.getItem(UPDATE_CHECK_CACHE_KEY);
                    if (raw) {
                        const parsed = JSON.parse(raw);
                        const checkedAt = Number(parsed?.checkedAt || 0);
                        const latestVersion = normalizeVersionTag(parsed?.latestVersion ?? "");
                        const fresh = checkedAt > 0 && Date.now() - checkedAt <= UPDATE_CHECK_CACHE_TTL_MS;
                        if (fresh && latestVersion)
                            cachedLatestVersion = latestVersion;
                    }
                }
                catch {
                    // Ignore cache parse/storage errors.
                }
                if (cachedLatestVersion) {
                    if (active && isNewerVersion(cachedLatestVersion, APP_VERSION)) {
                        setUpdateAvailable(true);
                        setUpdateVersion(cachedLatestVersion);
                    }
                    return;
                }
                const response = await fetch(GITHUB_LATEST_RELEASE_API, {
                    headers: { Accept: "application/vnd.github+json" },
                });
                if (!active || !response.ok)
                    return;
                const payload = (await response.json());
                const latestVersion = normalizeVersionTag(payload?.tag_name ?? "");
                if (latestVersion) {
                    try {
                        localStorage.setItem(UPDATE_CHECK_CACHE_KEY, JSON.stringify({
                            checkedAt: Date.now(),
                            latestVersion,
                        }));
                    }
                    catch {
                        // Ignore cache storage errors.
                    }
                }
                if (latestVersion && isNewerVersion(latestVersion, APP_VERSION)) {
                    setUpdateAvailable(true);
                    setUpdateVersion(latestVersion);
                }
            }
            catch (err) {
                if (!active)
                    return;
                console.warn("Updater check failed:", err);
            }
        };
        void checkForUpdates();
        return () => {
            active = false;
        };
    }, []);
    useEffect(() => {
        const root = document.documentElement;
        root.dataset.theme = theme;
        document.body.dataset.theme = theme;
        if (themeStored) {
            try {
                localStorage.setItem("efb-theme", theme);
            }
            catch {
                // Ignore storage access failures.
            }
        }
    }, [theme, themeStored]);
    const depKey = (depIcao || "").toUpperCase();
    const arrKey = (arrIcao || "").toUpperCase();
    const altKey = (altIcao || "").toUpperCase();
    useEffect(() => {
        if (!simbriefImported || !simbriefSnapshot) {
            if (simbriefStaleReason)
                setSimbriefStaleReason("");
            return;
        }
        const currentRoute = (routeText || "").trim().toUpperCase();
        const snapshotRoute = (simbriefSnapshot.route || "").trim().toUpperCase();
        let reason = "";
        if (simbriefSnapshot.dep && depKey && depKey !== simbriefSnapshot.dep) {
            reason = `Departure changed from ${simbriefSnapshot.dep}.`;
        }
        else if (simbriefSnapshot.arr && arrKey && arrKey !== simbriefSnapshot.arr) {
            reason = `Arrival changed from ${simbriefSnapshot.arr}.`;
        }
        else if (snapshotRoute && !currentRoute) {
            reason = "Route cleared after SimBrief import.";
        }
        else if (snapshotRoute && currentRoute && currentRoute !== snapshotRoute) {
            reason = "Route edited after SimBrief import.";
        }
        setSimbriefStaleReason(reason);
    }, [simbriefImported, simbriefSnapshot, depKey, arrKey, routeText, simbriefStaleReason]);
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
            }
            catch (e) {
                setDbError(String(e));
                setDbLoaded(false);
            }
        })();
    }, []);
    useEffect(() => {
        try {
            localStorage.setItem("simbrief_user", simbriefUser);
        }
        catch {
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
    const altInfo = altKey ? airports[altKey] : undefined;
    const directionEW = useMemo(() => inferDirectionEW(depInfo, arrInfo), [depInfo, arrInfo]);
    const applyCruiseFL = useCallback((raw, note) => {
        const next = normalizeCruiseFLByRules(raw, directionEW);
        // Keep both numeric + text states in sync.
        if (next !== cruiseFL)
            setCruiseFL(next);
        const nextText = String(next);
        if (nextText !== cruiseFLText)
            setCruiseFLText(nextText);
        if (typeof note === "string" && note.trim())
            setCruiseFLNotice(note);
    }, [directionEW, cruiseFL, cruiseFLText]);
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
    const lastAppliedAutoFLRef = useRef(null);
    const autoFLRec = useMemo(() => {
        if (!Number.isFinite(plannedDistance) || plannedDistance <= 0)
            return null;
        const rec = recommendCruiseFLForDistance(plannedDistance, directionEW, {
            minCruiseMin: 15,
            targetCruiseMin: 20,
        });
        if (!rec)
            return null;
        // Default: our model-driven recommendation
        let fl = normalizeCruiseFLByRules(rec.fl, directionEW);
        let note = rec.note;
        // Short-sector fallback: if we cannot meet minimum cruise time, prefer SimBrief cruise FL (if available).
        if (!rec.meetsMinimum && simbriefImported && Number.isFinite(simbriefCruiseFL ?? NaN)) {
            const sb = normalizeCruiseFLByRules(simbriefCruiseFL, directionEW);
            fl = sb;
            note = `Warning: short sector — unable to guarantee ≥15 min cruise with our profile model. Using SimBrief cruise FL${sb}.`;
        }
        return { fl, note };
    }, [plannedDistance, directionEW, simbriefImported, simbriefCruiseFL]);
    useEffect(() => {
        // Don't fight the user while they're typing.
        if (cruiseFLFocusValueRef.current !== null)
            return;
        // Respect manual override.
        if (cruiseFLTouched)
            return;
        if (!autoFLRec)
            return;
        const next = autoFLRec.fl;
        const nextText = String(next);
        // Guard against loops / no-op updates.
        if (lastAppliedAutoFLRef.current === next &&
            cruiseFL === next &&
            cruiseFLText === nextText) {
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
        if (!DEBUG_FL_AUTOPICK)
            return;
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
        if (cruiseFLFocusValueRef.current !== null)
            return;
        const base = Number.isFinite(cruiseFL) ? cruiseFL : Number(cruiseFLText);
        const next = normalizeCruiseFLByRules(base, directionEW);
        const nextText = String(next);
        if (next !== cruiseFL)
            setCruiseFL(next);
        if (nextText !== cruiseFLText)
            setCruiseFLText(nextText);
    }, [directionEW, cruiseFL, cruiseFLText]);
    const missionProfile = useMemo(() => buildCruiseMissionProfile(plannedDistance, clampCruiseFL(cruiseFL)), [plannedDistance, cruiseFL]);
    const climb = missionProfile.climb;
    const descent = missionProfile.descent;
    const reheat = useMemo(() => reheatGuard(climb.time_h), [climb.time_h]);
    const cruiseNM = useMemo(() => (missionProfile.accel.dist_nm || 0) + (missionProfile.cruise.dist_nm || 0), [missionProfile.accel.dist_nm, missionProfile.cruise.dist_nm]);
    const cruiseTimeH = useMemo(() => (missionProfile.accel.time_h || 0) + (missionProfile.cruise.time_h || 0), [missionProfile.accel.time_h, missionProfile.cruise.time_h]);
    const totalTimeH = missionProfile.total_time_h;
    const eteHours = totalTimeH;
    const tripKg = missionProfile.trip_kg;
    const burnKgPerNmAdj = missionProfile.avg_cruise_burn_kg_per_nm;
    const burnKgPerHour = useMemo(() => {
        if (!Number.isFinite(eteHours) || eteHours <= 0)
            return 1;
        if (!Number.isFinite(tripKg) || tripKg <= 0)
            return 1;
        return Math.max(tripKg / eteHours, 1);
    }, [tripKg, eteHours]);
    const alternateDistanceNM = useMemo(() => {
        if (!arrInfo || !altInfo)
            return 0;
        return greatCircleNM(arrInfo.lat, arrInfo.lon, altInfo.lat, altInfo.lon);
    }, [arrInfo, altInfo]);
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
    const reserveFuelKg = useMemo(() => {
        return Math.max((blocks.contingency_kg || 0) + (blocks.final_reserve_kg || 0) + (blocks.alternate_kg || 0), 0);
    }, [blocks.contingency_kg, blocks.final_reserve_kg, blocks.alternate_kg]);
    const reserveTimeH = useMemo(() => {
        return reserveFuelKg / burnKgPerHour;
    }, [reserveFuelKg, burnKgPerHour]);
    const airborneFuelKg = useMemo(() => {
        return Math.max((totalFuelRequiredKg || 0) - (taxiKg || 0), 0);
    }, [totalFuelRequiredKg, taxiKg]);
    const enduranceHours = useMemo(() => {
        return airborneFuelKg / burnKgPerHour;
    }, [airborneFuelKg, burnKgPerHour]);
    const enduranceMeets = enduranceHours >= eteHours + reserveTimeH;
    const fuelCapacityKg = CONSTANTS.weights.fuel_capacity_kg;
    const fuelWithinCapacity = totalFuelRequiredKg <= fuelCapacityKg;
    const fuelExcessKg = Math.max(totalFuelRequiredKg - fuelCapacityKg, 0);
    const paxCount = simbriefPaxCount ?? CONSTANTS.weights.pax_full_count;
    const paxMassKg = simbriefPaxWeightKg ?? CONSTANTS.weights.pax_mass_kg;
    const paxKg = paxCount * paxMassKg;
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
        if (!depInfo || !depRw)
            return null;
        return depInfo.runways.find((r) => r.id === depRw) ?? null;
    }, [depInfo, depRw]);
    const arrRunway = useMemo(() => {
        if (!arrInfo || !arrRw)
            return null;
        return arrInfo.runways.find((r) => r.id === arrRw) ?? null;
    }, [arrInfo, arrRw]);
    const depRunwayElevFt = depRunway?.elevation_ft ?? depInfo?.elevation_ft;
    const arrRunwayElevFt = arrRunway?.elevation_ft ?? arrInfo?.elevation_ft;
    const depWind = useMemo(() => {
        const parsed = parseMetarWind(metarDep || "");
        const comps = windComponents(parsed.wind_dir_deg, parsed.wind_speed_kt, depRunway?.heading ?? 0);
        return {
            parsed,
            comps,
            qnh: parseMetarQnh(metarDep || ""),
            category: parseMetarFlightCategory(metarDep || ""),
            tempC: parseMetarTempC(metarDep || ""),
            weather: parseMetarWeatherSummary(metarDep || ""),
            visibilityKm: parseMetarVisibilityKm(metarDep || ""),
        };
    }, [metarDep, depRunway?.heading]);
    const arrWind = useMemo(() => {
        const parsed = parseMetarWind(metarArr || "");
        const comps = windComponents(parsed.wind_dir_deg, parsed.wind_speed_kt, arrRunway?.heading ?? 0);
        return {
            parsed,
            comps,
            qnh: parseMetarQnh(metarArr || ""),
            category: parseMetarFlightCategory(metarArr || ""),
            tempC: parseMetarTempC(metarArr || ""),
            weather: parseMetarWeatherSummary(metarArr || ""),
            visibilityKm: parseMetarVisibilityKm(metarArr || ""),
        };
    }, [metarArr, arrRunway?.heading]);
    const tkoCheck = useMemo(() => {
        const len = depRunway?.length_m ?? 0;
        return takeoffFeasibleM(len, tkoWeightKgAuto, {
            runwayElevFt: depRunwayElevFt,
            qnh: depWind.qnh,
            oatC: depWind.tempC,
            headwindKt: depWind.comps.headwind_kt,
        });
    }, [depRunway?.length_m, tkoWeightKgAuto, depRunwayElevFt, depWind.qnh, depWind.tempC, depWind.comps.headwind_kt]);
    const ldgCheck = useMemo(() => {
        const len = arrRunway?.length_m ?? 0;
        return landingFeasibleM(len, estLandingWeightKg, {
            runwayElevFt: arrRunwayElevFt,
            qnh: arrWind.qnh,
            oatC: arrWind.tempC,
            headwindKt: arrWind.comps.headwind_kt,
        });
    }, [arrRunway?.length_m, estLandingWeightKg, arrRunwayElevFt, arrWind.qnh, arrWind.tempC, arrWind.comps.headwind_kt]);
    const depRunwayStatus = useMemo(() => {
        if (depKey.length !== 4)
            return { ready: false, message: "Enter ICAO" };
        if (!depInfo)
            return { ready: false, message: "Unknown ICAO" };
        if (!depInfo.runways?.length)
            return { ready: false, message: "No runway data" };
        if (!depRunway)
            return { ready: false, message: "Select runway" };
        return { ready: true, message: "" };
    }, [depKey.length, depInfo, depRunway]);
    const arrRunwayStatus = useMemo(() => {
        if (arrKey.length !== 4)
            return { ready: false, message: "Enter ICAO" };
        if (!arrInfo)
            return { ready: false, message: "Unknown ICAO" };
        if (!arrInfo.runways?.length)
            return { ready: false, message: "No runway data" };
        if (!arrRunway)
            return { ready: false, message: "Select runway" };
        return { ready: true, message: "" };
    }, [arrKey.length, arrInfo, arrRunway]);
    const operationalAlerts = useMemo(() => {
        const alerts = [];
        if (!enduranceMeets) {
            const reqH = eteHours + reserveTimeH;
            const missingH = Math.max(reqH - enduranceHours, 0);
            const missingKg = missingH * burnKgPerHour;
            alerts.push({
                id: "fuel-endurance-deficit",
                level: "error",
                message: `Fuel endurance short by ${Math.round(missingKg).toLocaleString()} kg (~${Math.round(missingH * 60)} min).`,
            });
        }
        if (altKey.length === 4 && alternateDistanceNM > 0) {
            const fuelAtDestinationKg = airborneFuelKg - tripKg;
            const minForAltAndFinalKg = (blocks.alternate_kg || 0) + (blocks.final_reserve_kg || 0);
            if (fuelAtDestinationKg < minForAltAndFinalKg) {
                alerts.push({
                    id: "alternate-unreachable",
                    level: "error",
                    message: `Alternate risk: fuel at destination is below alternate + final reserve by ${Math.round(minForAltAndFinalKg - fuelAtDestinationKg).toLocaleString()} kg.`,
                });
            }
        }
        if (tkoWeightKgAuto > CONSTANTS.weights.mtow_kg) {
            alerts.push({
                id: "over-mtow",
                level: "error",
                message: `Takeoff weight exceeds MTOW by ${Math.round(tkoWeightKgAuto - CONSTANTS.weights.mtow_kg).toLocaleString()} kg.`,
            });
        }
        if (estLandingWeightKg > CONSTANTS.weights.mlw_kg) {
            alerts.push({
                id: "over-mlw",
                level: "error",
                message: `Estimated landing weight exceeds MLW by ${Math.round(estLandingWeightKg - CONSTANTS.weights.mlw_kg).toLocaleString()} kg.`,
            });
        }
        if (depRunwayStatus.ready && !tkoCheck.feasible) {
            alerts.push({
                id: "takeoff-runway-short",
                level: "error",
                message: `Takeoff runway short by ${Math.round(tkoCheck.required_length_m_est - tkoCheck.runway_length_m).toLocaleString()} m.`,
            });
        }
        if (arrRunwayStatus.ready && !ldgCheck.feasible) {
            alerts.push({
                id: "landing-runway-short",
                level: "error",
                message: `Landing runway short by ${Math.round(ldgCheck.required_length_m_est - ldgCheck.runway_length_m).toLocaleString()} m.`,
            });
        }
        if (Number.isFinite(depWind.comps.headwind_kt ?? NaN) && depWind.comps.headwind_kt < -8) {
            alerts.push({
                id: "takeoff-tailwind",
                level: "warning",
                message: `Takeoff tailwind ${Math.round(Math.abs(depWind.comps.headwind_kt))} kt on selected runway.`,
            });
        }
        if (Number.isFinite(arrWind.comps.headwind_kt ?? NaN) && arrWind.comps.headwind_kt < -10) {
            alerts.push({
                id: "landing-tailwind",
                level: "warning",
                message: `Landing tailwind ${Math.round(Math.abs(arrWind.comps.headwind_kt))} kt on selected runway.`,
            });
        }
        return alerts;
    }, [
        enduranceMeets,
        eteHours,
        reserveTimeH,
        enduranceHours,
        burnKgPerHour,
        altKey.length,
        alternateDistanceNM,
        airborneFuelKg,
        tripKg,
        blocks.alternate_kg,
        blocks.final_reserve_kg,
        tkoWeightKgAuto,
        estLandingWeightKg,
        depRunwayStatus.ready,
        arrRunwayStatus.ready,
        tkoCheck.feasible,
        tkoCheck.required_length_m_est,
        tkoCheck.runway_length_m,
        ldgCheck.feasible,
        ldgCheck.required_length_m_est,
        ldgCheck.runway_length_m,
        depWind.comps.headwind_kt,
        arrWind.comps.headwind_kt,
    ]);
    const passCount = useMemo(() => tests.filter((t) => t.pass).length, [tests]);
    const failedTests = useMemo(() => tests.filter((t) => !t.pass), [tests]);
    function computeRouteDistanceFromText(text) {
        const tokens = parseRouteString(text);
        const { dep: depFromRoute, arr: arrFromRoute } = extractRouteEndpoints(tokens, airports);
        const depForCalc = (depFromRoute ? airports[depFromRoute] : depInfo) ?? undefined;
        const arrForCalc = (arrFromRoute ? airports[arrFromRoute] : arrInfo) ?? undefined;
        if (!depForCalc || !arrForCalc)
            return null;
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
        setSimbriefPaxCount(null);
        setSimbriefPaxWeightKg(null);
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
            setSimbriefCruiseFL(Number.isFinite(extracted.cruiseFL) ? extracted.cruiseFL : null);
            if (extracted.callSign)
                setSimbriefCallSign(extracted.callSign);
            if (extracted.registration)
                setSimbriefRegistration(extracted.registration);
            if (typeof extracted.paxCount === "number")
                setSimbriefPaxCount(extracted.paxCount);
            if (typeof extracted.paxWeightKg === "number")
                setSimbriefPaxWeightKg(extracted.paxWeightKg);
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
            if (extracted.depRunway)
                setDepRw(extracted.depRunway);
            if (extracted.arrRunway)
                setArrRw(extracted.arrRunway);
            // Auto-fill METARs from SimBrief (if available) so wind components populate immediately.
            if (extracted.depMetar)
                setMetarDep(extracted.depMetar);
            if (extracted.arrMetar)
                setMetarArr(extracted.arrMetar);
            if (extracted.depMetar || extracted.arrMetar)
                setMetarErr("");
            // Prefer live METARs when possible; fall back to SimBrief if fetch fails.
            const liveDepIcao = normalizeIcao4(extracted.originIcao) ?? normalizeIcao4(depKey);
            const liveArrIcao = normalizeIcao4(extracted.destIcao) ?? normalizeIcao4(arrKey);
            if (liveDepIcao || liveArrIcao) {
                const [depLive, arrLive] = await Promise.all([
                    liveDepIcao ? fetchMetarByICAO(liveDepIcao) : Promise.resolve(null),
                    liveArrIcao ? fetchMetarByICAO(liveArrIcao) : Promise.resolve(null),
                ]);
                const liveErrors = [];
                if (depLive) {
                    if (depLive.ok)
                        setMetarDep(depLive.raw);
                    else if (!extracted.depMetar)
                        liveErrors.push(depLive.error);
                }
                if (arrLive) {
                    if (arrLive.ok)
                        setMetarArr(arrLive.raw);
                    else if (!extracted.arrMetar)
                        liveErrors.push(arrLive.error);
                }
                if (liveErrors.length) {
                    setMetarErr(`Live METAR fetch failed: ${liveErrors.join(" | ")}`);
                }
                else {
                    setMetarErr("");
                }
            }
            const hasSimbriefDistance = typeof extracted.distanceNm === "number" && extracted.distanceNm > 0;
            if (extracted.route) {
                // If SimBrief provided a distance, we will trust it and avoid auto-recomputing once.
                if (hasSimbriefDistance)
                    simbriefRouteSetRef.current = true;
                setRouteText(extracted.route);
            }
            if (hasSimbriefDistance) {
                const rounded = Math.round(extracted.distanceNm);
                setManualDistanceNM(rounded);
                setRouteDistanceNM(extracted.distanceNm);
                setRouteInfo(null);
                setRouteNotice("");
                setDistanceSource("simbrief");
                setPlannedDistanceOverridden(false);
                lastAutoDistanceRef.current = null;
                // IMPORTANT: SimBrief distance should drive auto-FL again.
                setCruiseFLTouched(false);
                setCruiseFLNotice("");
            }
            else {
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
            setSimbriefSnapshot({
                dep: (extracted.originIcao || depKey).toUpperCase(),
                arr: (extracted.destIcao || arrKey).toUpperCase(),
                route: extracted.route || "",
                distanceNm: hasSimbriefDistance ? extracted.distanceNm : null,
            });
            const dep = extracted.originIcao ? ` ${extracted.originIcao}` : "";
            const arr = extracted.destIcao ? ` → ${extracted.destIcao}` : "";
            const alt = extracted.alternateIcao ? ` (ALT ${extracted.alternateIcao})` : "";
            setSimbriefNotice(`Imported SimBrief OFP${dep}${arr}${alt}.`);
        }
        catch (e) {
            setSimbriefNotice(String(e));
        }
        finally {
            setSimbriefLoading(false);
        }
    };
    useEffect(() => {
        const text = (routeText || "").trim();
        if (!text) {
            setRouteDistanceNM(null);
            if (distanceSource === "auto")
                setDistanceSource("none");
            return;
        }
        // Only auto-compute route distance when we're explicitly in auto mode.
        // This prevents manual Planned Distance edits from overwriting the imported/estimated route distance.
        if (distanceSource !== "auto")
            return;
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
            setRouteNotice("Could not compute route distance. Ensure Nav DB is loaded, and either set DEP/ARR or include airport ICAOs inside the route.");
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
        const parts = [`Planned Distance set to ${rounded.toLocaleString()} NM.`];
        if (out.depFromRoute && out.arrFromRoute) {
            parts.push(`Derived DEP/ARR: ${out.depFromRoute} → ${out.arrFromRoute}.`);
        }
        if (out.detour_factor > 1.001) {
            const pct = Math.round((out.detour_factor - 1) * 100);
            parts.push(`Applied airway detour factor (+${pct}%) due to limited waypoint resolution.`);
        }
        if (unresolved > 0)
            parts.push("Some waypoints couldn’t be resolved; distance is approximate.");
        setRouteNotice(parts.join(" "));
    }
    const metricBox = UI_TOKENS.metric.box;
    const metricLabel = UI_TOKENS.metric.label;
    const metricValue = UI_TOKENS.metric.value;
    const flightPlanSection = (_jsx(Card, { title: "FLIGHT PLAN", children: _jsxs("div", { className: UI_TOKENS.spacing.sectionStack, children: [_jsx(Label, { children: "SimBrief Username / ID (optional)" }), _jsxs("div", { className: "grid gap-6 sm:grid-cols-12 items-start", children: [_jsx("div", { className: "sm:col-span-4", children: _jsx(Input, { className: "h-12 text-sm", value: simbriefUser, placeholder: "SimBrief username", onChange: (e) => setSimbriefUser(e.target.value) }) }), _jsx("div", { className: "sm:col-span-2", children: _jsx(Button, { className: "h-12 px-4 text-sm w-full whitespace-nowrap", onClick: importFromSimbrief, disabled: simbriefLoading, children: _jsxs("span", { className: "inline-flex items-center justify-center gap-2 w-full", children: [_jsxs("svg", { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "currentColor", className: "h-4 w-4", "aria-hidden": "true", children: [_jsx("path", { d: "M12 3a1 1 0 0 1 1 1v8.586l2.293-2.293a1 1 0 1 1 1.414 1.414l-4.007 4.007a1 1 0 0 1-1.4.012l-4.02-4.02a1 1 0 1 1 1.414-1.414L11 12.586V4a1 1 0 0 1 1-1Z" }), _jsx("path", { d: "M5 20a1 1 0 0 1-1-1v-2a1 1 0 1 1 2 0v1h12v-1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1H5Z" })] }), simbriefLoading ? "Importing…" : "Import"] }) }) }), _jsx("div", { className: "hidden sm:block sm:col-span-6", children: _jsxs("div", { className: "grid grid-cols-3 gap-4", children: [_jsx("div", { className: `h-12 px-4 rounded-2xl border flex items-center justify-center min-w-0 text-center ${simbriefImported
                                            ? "bg-[#348939]/45 border-[#348939] shadow-[0_0_30px_rgba(52,137,57,0.55)]"
                                            : "bg-white/5 border-white/10"}`, children: _jsxs("div", { className: "min-w-0 text-center", children: [_jsx("div", { className: "text-[10px] uppercase tracking-[0.28em] text-white/40", children: "Call Sign" }), _jsx("div", { className: `text-sm font-semibold truncate ${simbriefImported ? "text-white" : "text-white/90"}`, children: simbriefImported ? (simbriefCallSign || "—") : "—" })] }) }), _jsx("div", { className: `h-12 px-4 rounded-2xl border flex items-center justify-center min-w-0 text-center ${simbriefImported
                                            ? "bg-[#FDBF02]/45 border-[#FDBF02] shadow-[0_0_30px_rgba(253,191,2,0.55)]"
                                            : "bg-white/5 border-white/10"}`, children: _jsxs("div", { className: "min-w-0 text-center", children: [_jsx("div", { className: "text-[10px] uppercase tracking-[0.28em] text-white/40", children: "Registration" }), _jsx("div", { className: `text-sm font-semibold truncate ${simbriefImported ? "text-white" : "text-white/90"}`, children: simbriefImported ? (simbriefRegistration || "—") : "—" })] }) }), _jsx("div", { className: `h-12 px-4 rounded-2xl border flex items-center justify-center min-w-0 text-center ${simbriefImported
                                            ? "bg-white/10 border-white/20"
                                            : "bg-white/5 border-white/10"}`, children: _jsxs("div", { className: "min-w-0 text-center", children: [_jsx("div", { className: "text-[10px] uppercase tracking-[0.28em] text-white/40", children: "Passengers" }), _jsx("div", { className: "text-sm font-semibold text-white/90 truncate", children: simbriefImported ? (simbriefPaxCount ?? "—") : "—" })] }) })] }) }), _jsx("div", { className: "sm:col-span-9", children: _jsx("textarea", { className: "efb-input h-12 text-xs leading-tight resize-none overflow-y-auto", placeholder: "Route will auto-fill from SimBrief (or paste here)", value: routeText, onChange: (e) => {
                                    setDistanceSource("auto");
                                    setPlannedDistanceOverridden(false);
                                    setRouteText(e.target.value);
                                } }) }), _jsx("div", { className: "sm:col-span-3", children: _jsxs("div", { className: `${metricBox} h-12`, children: [_jsx("div", { className: metricLabel, children: "Estimated Route Distance" }), _jsx("div", { className: "text-sm font-semibold text-white/90 tabular-nums", children: routeDistanceNM != null
                                            ? `${Math.round(routeDistanceNM).toLocaleString()} NM`
                                            : "—" })] }) })] }), _jsxs("div", { className: "grid grid-cols-12 gap-6 -mt-2", children: [_jsx("div", { className: "col-span-12 sm:col-span-9", children: simbriefNotice && (_jsx("div", { className: `text-xs ${simbriefNotice.startsWith("Imported")
                                    ? "text-emerald-300"
                                    : "text-rose-300"}`, children: simbriefNotice })) }), _jsxs("div", { className: "col-span-12 sm:col-span-3 flex flex-wrap justify-start sm:justify-end gap-2", children: [simbriefImported && !plannedDistanceOverridden && distanceSource === "simbrief" && (_jsx(StatusPill, { tone: "ok", children: "Imported" })), simbriefImported && plannedDistanceOverridden && (_jsx(StatusPill, { tone: "warning", children: "Planned Distance Override" }))] })] }), simbriefStaleReason && (_jsxs("div", { className: "flex items-center justify-between gap-3 rounded-2xl border border-amber-400/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-400", children: [_jsx(StatusPill, { tone: "warning", children: "SimBrief Stale" }), _jsxs("span", { className: "flex-1 text-center", children: [simbriefStaleReason, " Re-import recommended."] }), _jsx(Button, { variant: "ghost", className: "h-8 px-3 text-[11px] flex items-center justify-center leading-none", onClick: importFromSimbrief, disabled: simbriefLoading || !simbriefUser.trim(), children: "Re-import" })] })), routeNotice && _jsx("div", { className: "text-xs text-white/45", children: routeNotice })] }) }));
    const fuelSection = (_jsxs(Card, { title: "CRUISE & FUEL MANAGEMENT", children: [_jsxs(Row, { children: [_jsxs("div", { children: [_jsx(Label, { children: "Planned Distance (NM)" }), _jsx(Input, { type: "number", value: manualDistanceNM, onChange: (e) => {
                                    if (simbriefImported)
                                        setPlannedDistanceOverridden(true);
                                    lastAutoDistanceRef.current = null;
                                    const next = parseFloat(e.target.value || "0");
                                    setManualDistanceNM(Number.isFinite(next) ? next : 0);
                                    setCruiseFLTouched(false);
                                    setCruiseFLNotice("");
                                } }), _jsx("div", { className: "text-xs text-white/45 mt-2", children: simbriefImported
                                    ? "SimBrief imported: you can override Planned Distance manually (this won’t change the imported route distance shown above)."
                                    : "Enter distance from your flight planner. We’ll compute Climb/Cruise/Descent from this and FL." })] }), _jsxs("div", { children: [_jsx(Label, { children: "Cruise Flight Level (FL)" }), _jsx(Input, { type: "number", value: cruiseFLText, min: MIN_CONCORDE_FL, max: MAX_CONCORDE_FL, step: 10, onChange: (e) => {
                                    const next = e.target.value;
                                    setCruiseFLText(next);
                                    if (cruiseFLFocusValueRef.current !== null && next !== cruiseFLFocusValueRef.current) {
                                        cruiseFLEditedRef.current = true;
                                    }
                                    const n = Number(next);
                                    if (Number.isFinite(n))
                                        setCruiseFL(n);
                                }, onFocus: () => {
                                    cruiseFLFocusValueRef.current = cruiseFLText;
                                    cruiseFLEditedRef.current = false;
                                }, onBlur: () => {
                                    const n = Number(cruiseFLText);
                                    if (!Number.isFinite(n)) {
                                        setCruiseFLNotice("Invalid FL value.");
                                        setCruiseFLText(String(cruiseFL));
                                        cruiseFLFocusValueRef.current = null;
                                        return;
                                    }
                                    applyCruiseFL(n);
                                    cruiseFLFocusValueRef.current = null;
                                    if (cruiseFLEditedRef.current)
                                        setCruiseFLTouched(true);
                                } }), _jsx("div", { className: "text-xs text-white/45 mt-2", children: directionEW ? (_jsxs("span", { children: ["Direction (auto): ", _jsx("b", { children: directionEW === "E" ? "Eastbound" : "Westbound" }), ". Above FL410 we snap to Non-RVSM levels."] })) : (_jsxs("span", { children: ["Direction: ", _jsx("b", { children: "unknown" }), " (enter valid DEP/ARR ICAO to enable Non-RVSM snapping)."] })) }), cruiseFLNotice && (_jsx("div", { className: `text-xs mt-1 ${cruiseFLNotice.startsWith("Invalid")
                                    ? "text-rose-300"
                                    : cruiseFLNotice.startsWith("Adjusted")
                                        ? "text-amber-400"
                                        : "text-white/50"}`, children: cruiseFLNotice }))] })] }), _jsxs("div", { className: "mt-6 grid gap-4 lg:grid-cols-[1.1fr_2fr]", children: [_jsxs("div", { className: `${metricBox} lg:border-r lg:border-white/10`, children: [_jsx("div", { className: metricLabel, children: "Total Flight Time" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: totalTimeH }) })] }), _jsxs("div", { className: "grid gap-4 sm:grid-cols-3", children: [_jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "Climb" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: climb.time_h }) })] }), _jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "Cruise" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: cruiseTimeH }) })] }), _jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "Descent" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: descent.time_h }) })] })] })] }), _jsxs("div", { className: "mt-2 text-xs text-white/45", children: ["Cruise-climb profile: FL", missionProfile.initial_cruise_fl, missionProfile.target_cruise_fl > missionProfile.initial_cruise_fl
                        ? ` to FL${missionProfile.target_cruise_fl}`
                        : ` hold at FL${missionProfile.target_cruise_fl}`, ", with acceleration phase included in cruise time/fuel."] }), _jsxs("div", { className: "mt-6 grid gap-6 lg:grid-cols-[1.3fr_0.7fr]", children: [_jsxs("div", { className: "space-y-6", children: [_jsxs("div", { className: `${UI_TOKENS.surface.panel} p-5 space-y-4`, children: [_jsx("div", { className: "flex items-center justify-between", children: _jsx("div", { className: "text-xs font-semibold uppercase tracking-[0.28em] text-white/60", children: "Advanced" }) }), _jsxs("div", { className: "grid gap-4 sm:grid-cols-2", children: [_jsxs("div", { children: [_jsx(Label, { children: "Taxi Fuel (kg)" }), _jsx(Input, { type: "number", value: taxiKg, onChange: (e) => setTaxiKg(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Contingency (%)" }), _jsx(Input, { type: "number", value: contingencyPct, onChange: (e) => setContingencyPct(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Final Reserve (kg)" }), _jsx(Input, { type: "number", value: finalReserveKg, onChange: (e) => setFinalReserveKg(parseFloat(e.target.value || "0")) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Trim Tank Fuel (kg)" }), _jsx(Input, { type: "number", value: trimTankKg, onChange: (e) => setTrimTankKg(parseFloat(e.target.value || "0")) })] })] }), _jsxs("div", { className: "pt-4 border-t border-white/10", children: [_jsx(Label, { children: "Alternate ICAO" }), _jsx(Input, { value: altIcao, onChange: (e) => setAltIcao(e.target.value.toUpperCase()) }), _jsxs("div", { className: "text-xs text-white/45 mt-2", children: ["ARR \u2192 ALT distance: ", _jsx("b", { children: Math.round(alternateDistanceNM || 0).toLocaleString() }), " NM"] })] })] }), _jsxs("div", { className: "grid gap-4 sm:grid-cols-2 lg:grid-cols-4", children: [_jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "Computed TOW" }), _jsxs("div", { className: metricValue, children: [Math.round(tkoWeightKgAuto).toLocaleString(), " kg"] })] }), _jsxs("div", { className: `efb-metric flex flex-col justify-center ${enduranceMeets ? "" : "border-rose-500/40"}`, children: [_jsx("div", { className: metricLabel, children: "Fuel Endurance" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: enduranceHours }) }), _jsxs("div", { className: "text-xs text-white/55", children: [Math.round(burnKgPerHour).toLocaleString(), " kg/h burn"] })] }), _jsxs("div", { className: `efb-metric flex flex-col justify-center ${enduranceMeets ? "border-emerald-500/30" : "border-rose-500/40"}`, children: [_jsx("div", { className: metricLabel, children: "ETE + Reserves" }), _jsx("div", { className: metricValue, children: _jsx(HHMM, { hours: eteHours + reserveTimeH }) })] }), _jsxs("div", { className: "efb-metric flex flex-col justify-center", children: [_jsx("div", { className: metricLabel, children: "Passengers" }), _jsxs("div", { className: metricValue, children: [paxCount.toLocaleString(), " pax"] }), _jsxs("div", { className: "text-xs text-white/55", children: [Math.round(paxKg).toLocaleString(), " kg @ ", Math.round(paxMassKg), " kg each"] })] })] }), _jsxs("div", { className: `text-xs ${reheat.within_cap ? "text-white/45" : "text-rose-300"}`, children: ["Reheat safety: climb reheat within ", CONSTANTS.fuel.reheat_minutes_cap, " min cap."] }), !enduranceMeets && (_jsx("div", { className: "text-xs text-rose-300", children: "Fuel endurance is less than required ETE + reserves." }))] }), _jsxs("div", { className: `${UI_TOKENS.surface.panel} p-5 space-y-3 divide-y divide-white/10`, children: [_jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsx("span", { className: "text-sm text-white/70", children: "Trip Fuel" }), _jsx("span", { className: "text-xl font-mono text-white/95", children: Math.round(tripKg).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsx("span", { className: "text-sm text-white/50", children: "Taxi Fuel" }), _jsx("span", { className: "text-base font-mono text-white/85", children: Math.round(taxiKg || 0).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsx("span", { className: "text-sm text-white/50", children: "Contingency" }), _jsx("span", { className: "text-base font-mono text-white/85", children: Math.round(blocks.contingency_kg || 0).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsx("span", { className: "text-sm text-white/50", children: "Trim Fuel" }), _jsx("span", { className: "text-base font-mono text-white/85", children: Math.round(trimTankKg || 0).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsxs("span", { className: "text-sm text-white/50", children: ["Alt Fuel (", Math.round(alternateDistanceNM || 0), " NM)"] }), _jsx("span", { className: "text-base font-mono text-white/85", children: Math.round(blocks.alternate_kg || 0).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1", children: [_jsx("span", { className: "text-sm text-white/70 font-medium", children: "Block Fuel" }), _jsx("span", { className: "text-xl font-mono text-white", children: Math.round(blocks.block_kg).toLocaleString() })] }), _jsxs("div", { className: "flex justify-between items-center py-1 pt-3", children: [_jsxs("div", { className: "flex flex-col", children: [_jsx("span", { className: "text-sm text-white/70 font-medium", children: "Total Required" }), _jsxs("span", { className: "text-[10px] text-white/40", children: ["Block + Trim (", trimTankKg, " kg)"] })] }), _jsxs("div", { className: "text-right", children: [_jsx("span", { className: `text-2xl font-mono ${fuelWithinCapacity ? "text-emerald-400" : "text-rose-400"}`, children: Number.isFinite(blocks.block_kg) ? Math.round(blocks.block_kg + (trimTankKg || 0)).toLocaleString() : "—" }), _jsx("span", { className: "text-sm text-white/50 ml-1", children: "kg" })] })] })] })] }), !fuelWithinCapacity && (_jsxs("div", { className: "mt-3 text-xs text-rose-300", children: ["Warning: Total fuel ", _jsxs("b", { children: [Math.round(totalFuelRequiredKg).toLocaleString(), " kg"] }), " exceeds Concorde fuel capacity", " ", _jsxs("b", { children: [Math.round(fuelCapacityKg).toLocaleString(), " kg"] }), " by ", _jsxs("b", { children: [Math.round(fuelExcessKg).toLocaleString(), " kg"] }), ". Reduce block or trim fuel to stay within limits."] }))] }));
    const performanceSection = (_jsxs(Card, { title: "PERFORMANCE CALCULATOR", right: _jsx(Button, { onClick: async () => {
                setMetarErr("");
                const dep = depKey;
                const arr = arrKey;
                if (!dep || dep.length !== 4 || !arr || arr.length !== 4) {
                    setMetarErr("Enter valid DEP and ARR ICAOs first.");
                    return;
                }
                const [d, a] = await Promise.all([fetchMetarByICAO(dep), fetchMetarByICAO(arr)]);
                const errs = [];
                if (d.ok)
                    setMetarDep(d.raw);
                else
                    errs.push(d.error);
                if (a.ok)
                    setMetarArr(a.raw);
                else
                    errs.push(a.error);
                if (errs.length)
                    setMetarErr(errs.join(" | "));
            }, children: "Fetch METARs" }), children: [_jsx(SectionHeader, { children: "Airports & Runways" }), metarErr && _jsxs("div", { className: "text-xs text-rose-300 mt-2", children: ["METAR fetch error: ", metarErr] }), _jsxs("div", { className: "grid gap-5 lg:grid-cols-2", children: [_jsxs("div", { className: "space-y-3", children: [_jsxs("div", { className: "grid gap-3 sm:grid-cols-2", children: [_jsxs("div", { children: [_jsx(Label, { children: "Departure ICAO" }), _jsx(Input, { value: depIcao, onChange: (e) => setDepIcao(e.target.value.toUpperCase()) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Departure Runway" }), _jsxs(Select, { value: depRw, onChange: (e) => setDepRw(e.target.value), children: [_jsx("option", { value: "", children: "\u2014" }), (depInfo?.runways ?? []).map((r) => (_jsx("option", { value: r.id, children: `RWY ${r.id} • ${Number(r.length_m || 0).toLocaleString()} m • ${Math.round(Number(r.heading || 0))}°` }, `dep-${r.id}`)))] })] })] }), _jsxs("div", { className: `rounded-2xl border px-4 py-3 ${flightCategoryStripClass(depWind.category)}`, children: [_jsxs("div", { className: "flex items-center justify-between text-[10px] uppercase tracking-[0.28em] text-white/60", children: [_jsx("span", { children: "DEP METAR" }), _jsxs("div", { className: "flex items-center gap-2", children: [_jsxs("span", { className: "text-white/60", children: [depWind.weather?.label ?? "—", Number.isFinite(depWind.tempC ?? NaN) ? ` • ${Math.round(depWind.tempC)}°C` : ""] }), _jsx(StatusPill, { tone: flightCategoryTone(depWind.category), className: "text-[9px]", children: depWind.category === "UNKNOWN" ? "—" : depWind.category })] })] }), _jsxs("div", { className: "mt-3 flex items-start gap-3", children: [_jsxs("div", { className: "flex flex-col items-center gap-1", children: [_jsx(RunwayWindViz, { runwayHeading: depRunway?.heading ?? null, windDir: depWind.parsed.wind_dir_deg }), _jsx("div", { className: "text-[11px] font-semibold text-white/70", children: depRunway ? depRunway.id : "—" })] }), _jsxs("div", { className: "flex-1", children: [_jsx("div", { className: "text-xs text-white/90 font-mono break-words", children: metarDep || "—" }), _jsxs("div", { className: "mt-2 flex flex-wrap gap-2", children: [_jsx(WindSummaryChip, { windDir: depWind.parsed.wind_dir_deg, windSpeed: depWind.parsed.wind_speed_kt, windGust: depWind.parsed.wind_gust_kt }), _jsx(VisibilityChip, { visibilityKm: depWind.visibilityKm }), _jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "QNH" }), _jsxs("span", { className: "font-semibold text-white/90", children: [depWind.qnh ? depWind.qnh.value.toFixed(depWind.qnh.unit === "hPa" ? 0 : 2) : "—", _jsx("span", { className: "ml-1 text-[10px] text-white/40", children: depWind.qnh?.unit ?? "" })] })] }), _jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "RWY ELEV" }), _jsxs("span", { className: "font-semibold text-white/90", children: [Number.isFinite(depRunwayElevFt ?? NaN) ? Math.round(depRunwayElevFt) : "—", _jsx("span", { className: "ml-1 text-[10px] text-white/40", children: "ft" })] })] })] })] })] })] })] }), _jsxs("div", { className: "space-y-3", children: [_jsxs("div", { className: "grid gap-3 sm:grid-cols-2", children: [_jsxs("div", { children: [_jsx(Label, { children: "Arrival ICAO" }), _jsx(Input, { value: arrIcao, onChange: (e) => setArrIcao(e.target.value.toUpperCase()) })] }), _jsxs("div", { children: [_jsx(Label, { children: "Arrival Runway" }), _jsxs(Select, { value: arrRw, onChange: (e) => setArrRw(e.target.value), children: [_jsx("option", { value: "", children: "\u2014" }), (arrInfo?.runways ?? []).map((r) => (_jsx("option", { value: r.id, children: `RWY ${r.id} • ${Number(r.length_m || 0).toLocaleString()} m • ${Math.round(Number(r.heading || 0))}°` }, `arr-${r.id}`)))] })] })] }), _jsxs("div", { className: `rounded-2xl border px-4 py-3 ${flightCategoryStripClass(arrWind.category)}`, children: [_jsxs("div", { className: "flex items-center justify-between text-[10px] uppercase tracking-[0.28em] text-white/60", children: [_jsx("span", { children: "ARR METAR" }), _jsxs("div", { className: "flex items-center gap-2", children: [_jsxs("span", { className: "text-white/60", children: [arrWind.weather?.label ?? "—", Number.isFinite(arrWind.tempC ?? NaN) ? ` • ${Math.round(arrWind.tempC)}°C` : ""] }), _jsx(StatusPill, { tone: flightCategoryTone(arrWind.category), className: "text-[9px]", children: arrWind.category === "UNKNOWN" ? "—" : arrWind.category })] })] }), _jsxs("div", { className: "mt-3 flex items-start gap-3", children: [_jsxs("div", { className: "flex flex-col items-center gap-1", children: [_jsx(RunwayWindViz, { runwayHeading: arrRunway?.heading ?? null, windDir: arrWind.parsed.wind_dir_deg }), _jsx("div", { className: "text-[11px] font-semibold text-white/70", children: arrRunway ? arrRunway.id : "—" })] }), _jsxs("div", { className: "flex-1", children: [_jsx("div", { className: "text-xs text-white/90 font-mono break-words", children: metarArr || "—" }), _jsxs("div", { className: "mt-2 flex flex-wrap gap-2", children: [_jsx(WindSummaryChip, { windDir: arrWind.parsed.wind_dir_deg, windSpeed: arrWind.parsed.wind_speed_kt, windGust: arrWind.parsed.wind_gust_kt }), _jsx(VisibilityChip, { visibilityKm: arrWind.visibilityKm }), _jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "QNH" }), _jsxs("span", { className: "font-semibold text-white/90", children: [arrWind.qnh ? arrWind.qnh.value.toFixed(arrWind.qnh.unit === "hPa" ? 0 : 2) : "—", _jsx("span", { className: "ml-1 text-[10px] text-white/40", children: arrWind.qnh?.unit ?? "" })] })] }), _jsxs("div", { className: "flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] text-white/75 whitespace-nowrap", children: [_jsx("span", { className: "uppercase tracking-[0.2em] text-white/45", children: "RWY ELEV" }), _jsxs("span", { className: "font-semibold text-white/90", children: [Number.isFinite(arrRunwayElevFt ?? NaN) ? Math.round(arrRunwayElevFt) : "—", _jsx("span", { className: "ml-1 text-[10px] text-white/40", children: "ft" })] })] })] })] })] })] })] })] }), _jsx(Divider, {}), _jsxs("div", { className: "grid gap-6 lg:grid-cols-2", children: [_jsxs("div", { className: `rounded-3xl border p-5 space-y-4 ${depRunwayStatus.ready
                            ? tkoCheck.feasible
                                ? "border-white/10 bg-black/30"
                                : "border-rose-500/40 bg-rose-500/10 shadow-[0_0_45px_rgba(244,63,94,0.25)]"
                            : "border-white/10 bg-black/30"}`, children: [_jsxs("div", { className: "flex items-start justify-between", children: [_jsxs("div", { children: [_jsx("div", { className: "text-xs font-semibold uppercase tracking-[0.28em] text-white/70", children: "TAKEOFF PERFORMANCE" }), _jsxs("div", { className: "text-2xl font-semibold text-white/90 mt-2", children: [Math.round(tkoWeightKgAuto).toLocaleString(), _jsx("span", { className: "text-sm text-white/40", children: " kg" })] })] }), _jsx(StatusPill, { tone: depRunwayStatus.ready ? (tkoCheck.feasible ? "ok" : "error") : "error", children: depRunwayStatus.ready ? (tkoCheck.feasible ? "Within limits" : "Runway short") : depRunwayStatus.message })] }), _jsxs("div", { className: "grid grid-cols-3 gap-3", children: [_jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "V1" }), _jsx("div", { className: metricValue, children: tkSpeeds.V1 })] }), _jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "VR" }), _jsx("div", { className: metricValue, children: tkSpeeds.VR })] }), _jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "V2" }), _jsx("div", { className: metricValue, children: tkSpeeds.V2 })] })] }), _jsxs("div", { className: "text-xs text-white/45", children: ["Runway required: ", _jsxs("b", { children: [Math.round(tkoCheck.required_length_m_est).toLocaleString(), " m"] })] }), tkoCheck.correction_breakdown_pct && (_jsxs("div", { className: "text-[11px] text-white/50 leading-relaxed", children: ["Weather/elevation correction:", " ", _jsxs("b", { className: tkoCheck.correction_breakdown_pct.total >= 0 ? "text-amber-300" : "text-emerald-300", children: [tkoCheck.correction_breakdown_pct.total >= 0 ? "+" : "", tkoCheck.correction_breakdown_pct.total.toFixed(1), "%"] }), " ", "(Pressure ", tkoCheck.correction_breakdown_pct.pressure >= 0 ? "+" : "", tkoCheck.correction_breakdown_pct.pressure.toFixed(1), "%, Temperature", " ", tkoCheck.correction_breakdown_pct.temperature >= 0 ? "+" : "", tkoCheck.correction_breakdown_pct.temperature.toFixed(1), "%, Wind", " ", tkoCheck.correction_breakdown_pct.wind >= 0 ? "+" : "", tkoCheck.correction_breakdown_pct.wind.toFixed(1), "%)"] }))] }), _jsxs("div", { className: `rounded-3xl border p-5 space-y-4 ${arrRunwayStatus.ready
                            ? ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                                ? "border-white/10 bg-black/30"
                                : "border-rose-500/40 bg-rose-500/10 shadow-[0_0_45px_rgba(244,63,94,0.25)]"
                            : "border-white/10 bg-black/30"}`, children: [_jsxs("div", { className: "flex items-start justify-between", children: [_jsxs("div", { children: [_jsx("div", { className: "text-xs font-semibold uppercase tracking-[0.28em] text-white/70", children: "LANDING PERFORMANCE" }), _jsxs("div", { className: "text-2xl font-semibold text-white/90 mt-2", children: [Math.round(estLandingWeightKg).toLocaleString(), _jsx("span", { className: "text-sm text-white/40", children: " kg" })] })] }), _jsx(StatusPill, { tone: arrRunwayStatus.ready
                                            ? ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                                                ? "ok"
                                                : "error"
                                            : "error", children: arrRunwayStatus.ready
                                            ? ldgCheck.feasible && estLandingWeightKg <= CONSTANTS.weights.mlw_kg
                                                ? "Within limits"
                                                : estLandingWeightKg > CONSTANTS.weights.mlw_kg
                                                    ? "Over MLW"
                                                    : "Runway short"
                                            : arrRunwayStatus.message })] }), _jsxs("div", { className: "grid grid-cols-2 gap-3", children: [_jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "VLS" }), _jsx("div", { className: metricValue, children: ldSpeeds.VLS })] }), _jsxs("div", { className: metricBox, children: [_jsx("div", { className: metricLabel, children: "VAPP" }), _jsx("div", { className: metricValue, children: ldSpeeds.VAPP })] })] }), _jsxs("div", { className: "text-xs text-white/45", children: ["Runway required: ", _jsxs("b", { children: [Math.round(ldgCheck.required_length_m_est).toLocaleString(), " m"] })] }), ldgCheck.correction_breakdown_pct && (_jsxs("div", { className: "text-[11px] text-white/50 leading-relaxed", children: ["Weather/elevation correction:", " ", _jsxs("b", { className: ldgCheck.correction_breakdown_pct.total >= 0 ? "text-amber-300" : "text-emerald-300", children: [ldgCheck.correction_breakdown_pct.total >= 0 ? "+" : "", ldgCheck.correction_breakdown_pct.total.toFixed(1), "%"] }), " ", "(Pressure ", ldgCheck.correction_breakdown_pct.pressure >= 0 ? "+" : "", ldgCheck.correction_breakdown_pct.pressure.toFixed(1), "%, Temperature", " ", ldgCheck.correction_breakdown_pct.temperature >= 0 ? "+" : "", ldgCheck.correction_breakdown_pct.temperature.toFixed(1), "%, Wind", " ", ldgCheck.correction_breakdown_pct.wind >= 0 ? "+" : "", ldgCheck.correction_breakdown_pct.wind.toFixed(1), "%)"] }))] })] }), operationalAlerts.length > 0 && (_jsxs("div", { className: "mt-4 rounded-2xl border border-rose-500/35 bg-rose-500/10 px-4 py-3", children: [_jsx("div", { className: "text-xs font-semibold uppercase tracking-[0.2em] text-rose-200 mb-2", children: "Operational Alerts" }), _jsx("div", { className: "space-y-1.5", children: operationalAlerts.map((alert) => (_jsxs("div", { className: `text-xs ${alert.level === "error" ? "text-rose-100" : "text-amber-200"}`, children: [alert.level === "error" ? "ERROR" : "WARN", ": ", alert.message] }, alert.id))) })] })), _jsx("div", { className: "text-xs text-white/45 mt-3", children: "Speeds scale with \u221A(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim." })] }));
    return (_jsxs("div", { className: "relative min-h-screen text-slate-100", children: [_jsxs("div", { className: "pointer-events-none fixed inset-0 -z-10", children: [_jsx("div", { className: "absolute -top-24 left-1/2 h-72 w-[52rem] -translate-x-1/2 rounded-full bg-sky-500/10 blur-[140px]" }), _jsx("div", { className: "absolute top-1/3 left-8 h-60 w-60 rounded-full bg-cyan-400/10 blur-[120px]" }), _jsx("div", { className: "absolute bottom-24 right-8 h-64 w-64 rounded-full bg-slate-500/20 blur-[140px]" })] }), _jsxs("div", { className: `mx-auto max-w-7xl px-6 pb-16 pt-8 ${UI_TOKENS.spacing.pageStack}`, children: [_jsxs("header", { className: "flex flex-col gap-6 md:flex-row md:items-center md:justify-between", children: [_jsxs("div", { className: "flex items-center gap-4", children: [appIconMode !== "none" ? (_jsx("img", { src: appIconMode === "primary" ? APP_ICON_SRC_PRIMARY : APP_ICON_SRC_FALLBACK, alt: "Concorde EFB", className: "h-20 w-20 object-contain shrink-0 rounded-2xl border border-white/10 bg-white/5 p-2 shadow-[0_12px_30px_-18px_rgba(0,0,0,0.8)]", onError: (e) => {
                                            const failedSrc = e.currentTarget.src;
                                            console.warn("App icon failed to load:", failedSrc);
                                            // 1st failure: switch to fallback icon.png
                                            // 2nd failure: show the simple SVG placeholder
                                            setAppIconMode((prev) => (prev === "primary" ? "fallback" : "none"));
                                        }, draggable: false })) : (_jsx("div", { className: "h-20 w-20 flex items-center justify-center shrink-0 rounded-2xl border border-white/10 bg-white/5", children: _jsx("svg", { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "currentColor", className: "h-8 w-8 text-white/80", "aria-hidden": "true", children: _jsx("path", { d: "M21.5 13.5c.3 0 .5.2.5.5v1a1 1 0 0 1-1 1H14l-2.2 3.6a1 1 0 0 1-1.8-.5V16H6l-1.2 1.2a1 1 0 0 1-1.7-.7V15a1 1 0 0 1 .3-.7L6 12 3.4 9.7a1 1 0 0 1-.3-.7V7.5a1 1 0 0 1 1.7-.7L6 8h3.9V4.4a1 1 0 0 1 1.8-.5L14 7.5h7a1 1 0 0 1 1 1v1c0 .3-.2.5-.5.5H14v3.5h7Z" }) }) })), _jsxs("div", { children: [_jsx("div", { className: "text-3xl font-semibold tracking-tight text-white", children: "Concorde EFB" }), _jsx("div", { className: "text-sm text-white/45", children: "Flight planning & performance for MSFS." }), _jsx("div", { className: "mt-3 flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-[0.3em] text-white/35", children: _jsxs("span", { className: "rounded-full border border-white/10 bg-white/5 px-3 py-1", children: ["v", APP_VERSION] }) })] })] }), _jsxs("div", { className: "flex flex-col items-end gap-3", children: [_jsx(ThemeToggle, { theme: theme, onToggle: () => {
                                            setThemeStored(true);
                                            setTheme(theme === "light" ? "dark" : "light");
                                        } }), _jsxs("div", { className: "flex flex-wrap justify-end gap-6", children: [_jsx(StatPill, { label: "Nav DB", value: dbLoaded ? "Loaded" : "Loading", ok: dbLoaded }), _jsx(StatPill, { label: "TAS", value: `${CONSTANTS.speeds.cruise_tas_kt} kt` }), _jsx(StatPill, { label: "MTOW", value: `${CONSTANTS.weights.mtow_kg.toLocaleString()} kg` }), _jsx(StatPill, { label: "MLW", value: `${CONSTANTS.weights.mlw_kg.toLocaleString()} kg` }), _jsx(StatPill, { label: "Fuel cap", value: `${CONSTANTS.weights.fuel_capacity_kg.toLocaleString()} kg` })] })] })] }), _jsx("div", { className: `flex w-full justify-end ${updateAvailable ? "mt-4" : ""}`, children: updateAvailable && (_jsxs("div", { className: "flex items-center gap-3 rounded-lg border border-amber-400/50 bg-amber-500/15 px-3 py-2 text-[11px] text-amber-50 shadow-[0_10px_24px_-18px_rgba(251,191,36,0.8)]", children: [_jsx("span", { className: "uppercase tracking-[0.24em] text-amber-200/80", children: "New update available. Click Download Latest" }), _jsx("span", { className: "font-semibold", children: updateVersion ? `v${updateVersion}` : "" }), _jsx(LinkButton, { href: DOWNLOAD_LATEST_URL, className: "h-7 px-2 text-[10px]", title: "Download the latest release", children: "Download Latest" })] })) }), _jsxs("main", { className: UI_TOKENS.spacing.pageStack, children: [dbError && (_jsxs("div", { className: "rounded-2xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-xs text-rose-200", children: ["Nav DB load error: ", dbError] })), flightPlanSection, fuelSection, performanceSection, _jsx(Card, { title: "Notes & Assumptions", children: _jsxs("ul", { className: "list-disc pl-5 text-sm text-white/70 space-y-2", children: [_jsxs("li", { children: ["All masses in ", _jsx("b", { children: "kg" }), ". Distances in ", _jsx("b", { children: "NM" }), ". Runway lengths in ", _jsx("b", { children: "m" }), " only."] }), _jsx("li", { children: "Nav DB loads Airports/Runways/NAVAIDs from OurAirports at runtime." }), _jsx("li", { children: "Routes accept SID/STAR tokens but do not expand full procedure geometry." }), _jsx("li", { children: "SimBrief import drives DEP/ARR, route, alternates, and METAR when available." }), _jsx("li", { children: "Fuel model is heuristic and altitude-sensitive; verify against DC Designs data and in\u2011sim results." }), _jsx("li", { children: "Reheat safety is a climb-time cap check; it does not change calculations." })] }) }), _jsxs("div", { className: "flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-white/10 bg-black/25 px-4 py-3 text-xs text-white/60", children: [_jsxs("div", { className: "flex flex-wrap items-center gap-2", children: [_jsx(Button, { variant: "ghost", className: "h-8 px-3 text-xs", onClick: () => {
                                                    setTests(runSelfTests());
                                                    setShowDiagnostics(true);
                                                }, children: "Run Self-Tests" }), tests.length > 0 && (_jsxs("span", { className: "text-white/70", children: ["Diagnostics: ", passCount, "/", tests.length, " passed"] })), failedTests.length > 0 && (_jsx(Button, { variant: "ghost", className: "h-8 px-3 text-xs", onClick: () => setShowDiagnostics((prev) => !prev), children: showDiagnostics ? "Hide Details" : "Show Details" }))] }), _jsxs("div", { className: "flex flex-wrap items-center gap-2", children: [_jsx(LinkButton, { href: DONATE_PAGE_URL, className: "h-8 px-3 text-xs", title: "Support the project", children: "Donate" }), _jsx(LinkButton, { href: "https://github.com/dwaipayanray95/Concorde-EFB/issues/new/choose", className: "h-8 px-3 text-xs", title: "Create a GitHub issue", children: "Bug / Feature" }), _jsx(LinkButton, { href: "https://github.com/dwaipayanray95/Concorde-EFB", className: "h-8 px-3 text-xs", title: "GitHub repository", children: "GitHub" }), _jsx(LinkButton, { href: CHANGELOG_PAGE_URL, className: "h-8 px-3 text-xs", title: "View raw changes", children: "View Changelog" }), _jsx(LinkButton, { href: DOWNLOAD_LATEST_URL, className: "h-8 px-3 text-xs", title: "Download latest release", children: "Download Latest" })] })] }), showDiagnostics && failedTests.length > 0 && (_jsx("div", { className: "mt-2 grid gap-2 sm:grid-cols-2", children: failedTests.map((t, i) => (_jsxs("div", { className: "text-[10px] px-2 py-1 rounded border border-rose-500/30 text-rose-300 bg-rose-500/5", children: [t.name, " ", t.err ? `— ${t.err}` : ""] }, `fail-${i}`))) }))] }), _jsx("footer", { className: "pt-6 text-center text-xs text-white/45", children: "Manual values \u00A9 DC Designs Concorde (MSFS). Planner is for training/planning only; always verify in-sim. Made with love by @theawesomeray" })] }), _jsx("a", { className: "fixed bottom-4 right-4 z-50 opacity-70 transition hover:opacity-100", href: OPENS_COUNTER_PATH, target: "_blank", rel: "noreferrer", title: "EFB launches (counts every app load)", children: _jsx("img", { src: OPENS_BADGE_SRC, alt: "EFB launches counter", className: "h-6 w-auto rounded-md border border-white/10 bg-black/60 backdrop-blur", loading: "lazy" }) })] }));
}
export default ConcordePlannerCanvas;
