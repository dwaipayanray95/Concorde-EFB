#!/usr/bin/env python3
"""Generate the bundled offline airport database asset.

Downloads the OurAirports airports + runways CSVs, prunes them to the
fields Concorde EFB actually uses, and writes a gzipped JSON asset to
assets/airport_db.json.gz.

Run this before cutting a release to refresh the bundled data:
    python3 scripts/generate_airport_db.py
"""
import csv
import gzip
import io
import json
import os
import urllib.request
from datetime import date

AIRPORTS_URL = "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv"
RUNWAYS_URL = "https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv"
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "airport_db.json.gz")


def fetch_csv(url):
    print(f"Downloading {url} ...")
    with urllib.request.urlopen(url, timeout=60) as resp:
        return list(csv.DictReader(io.TextIOWrapper(resp, encoding="utf-8")))


def main():
    airports_rows = fetch_csv(AIRPORTS_URL)
    runways_rows = fetch_csv(RUNWAYS_URL)

    airports = {}
    for row in airports_rows:
        icao = row["ident"].strip().upper()
        if len(icao) != 4:
            continue
        try:
            lat = float(row["latitude_deg"])
            lon = float(row["longitude_deg"])
        except ValueError:
            continue
        elev = None
        try:
            elev = float(row["elevation_ft"])
        except ValueError:
            pass
        # [name, lat, lon, elevationFt, runways[]]
        airports[icao] = [row["name"], round(lat, 5), round(lon, 5), elev, []]

    runway_count = 0
    for row in runways_rows:
        icao = row["airport_ident"].strip().upper()
        airport = airports.get(icao)
        if airport is None:
            continue
        try:
            length_m = round(float(row["length_ft"]) * 0.3048, 1)
        except ValueError:
            length_m = 0.0

        for end, hdg_col, elev_col in (
            ("le_ident", "le_heading_degT", "le_elevation_ft"),
            ("he_ident", "he_heading_degT", "he_elevation_ft"),
        ):
            ident = row[end].strip().upper()
            if not ident:
                continue
            try:
                heading = round(float(row[hdg_col]))
            except ValueError:
                heading = 0
            elev = None
            try:
                elev = float(row[elev_col])
            except ValueError:
                pass
            # [id, headingDeg, lengthM, elevationFt]
            airport[4].append([ident, heading, length_m, elev])
            runway_count += 1

    payload = {"generated": date.today().isoformat(), "airports": airports}
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    with gzip.open(OUT_PATH, "wb", compresslevel=9) as f:
        f.write(raw)

    print(f"Wrote {OUT_PATH}")
    print(f"  airports: {len(airports)}  runway ends: {runway_count}")
    print(f"  raw: {len(raw) / 1e6:.1f} MB  gzipped: {os.path.getsize(OUT_PATH) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
