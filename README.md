# Area Recon

An interactive map for **scouting an area** — fiber-internet availability, violent crime, and terrain — with address search that resolves down to the **FCC census block**. Currently loaded with full detail for **West Virginia**, on a national backdrop.

It's a single self-contained web page (HTML + a small data file + map libraries from a CDN). No build step, no server required.

## Features

- **Two map levels**
  - **United States** — state choropleth with three views: a bivariate *fiber × crime* overlay, fiber availability, and violent crime relative to the national average.
  - **County drill-down** — click any state (West Virginia is fully wired up) to zoom into its counties.
- **Topographic basemaps** — USGS Topo (contour lines), OpenTopoMap, hillshade, shaded relief, or plain; switchable on the map.
- **Elevation** — every county is labeled with its elevation, plus a click-anywhere **elevation probe** (feet + meters).
- **Fiber, from the FCC** — county-level **gigabit** and **any-fiber** availability built from the FCC Broadband Data Collection, plus broadband-adoption and violent-crime layers.
- **Address search** — type a full address (e.g. `401 Charles Way, Purgitsville, WV 26852`), with **autocomplete**. The result pin shows the address, elevation, the **2020 census block**, **whether fiber is available in that block** (from the FCC data), and the block's county stats.
- Sortable/searchable data tables and at-a-glance callouts.

## Live demo

If deployed with **GitHub Pages**, the map is served from the repository root:
`https://seerstaffing.github.io/area-recon/`

## Run it locally

The page pulls map tiles and a few geo APIs at runtime, so it needs an internet connection, but **no build step**.

- **Easiest:** open `index.html` in a modern browser. Keep `wv_blocks.js` in the same folder (it powers the per-census-block fiber lookup).
- **Via a local server** (avoids any `file://` quirks), using the included PowerShell static server — handy on Windows with no Node/Python:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\serve.ps1
  # then open http://localhost:8123/
  ```

## Repository layout

```
index.html                 The app (map, UI, data, logic)
wv_blocks.js               Per-census-block fiber index for WV (derived from FCC BDC)
data/wv_fiber_counts.csv   Per-county fiber-serviceable location counts (intermediate)
scripts/serve.ps1          Minimal local static server for previewing
```

## Data sources

- **Fiber availability** — [FCC Broadband Data Collection](https://broadbandmap.fcc.gov/) (Fiber-to-the-Premises, Dec 2025 release). County % and the per-block index are derived from the public location file; gigabit = ≥ 1000 Mbps download.
- **Broadband adoption** — U.S. Census ACS (households subscribing to any broadband).
- **Violent crime** — FBI 2024 (national) and FBI UCR / PlainCrime (WV counties that report).
- **Housing units** (denominator) — U.S. Census.
- **Geocoding** — [U.S. Census Geocoder](https://geocoding.geo.census.gov/) (returns the 2020 census block), with [Photon](https://photon.komoot.io/) autocomplete and Nominatim fallback.
- **Elevation** — [Open-Meteo Elevation API](https://open-meteo.com/) (Copernicus DEM).
- **Basemaps** — USGS The National Map, Esri (hillshade / shaded relief), OpenTopoMap (CC-BY-SA), CARTO.
- **Boundaries** — U.S. Census via [us-atlas](https://github.com/topojson/us-atlas).

## Methodology & caveats

- County fiber % is an **estimate** = FCC fiber-serviceable locations ÷ Census housing units; it runs a few points below the FCC's official location-based figure (which uses a denominator that isn't in the public file).
- Block-level **"fiber available here"** means the FCC reports **≥ 1 fiber-serviceable location in that census block** — the best address-level signal from public data, not a guarantee at the exact parcel.
- Violent crime at the county level is reported for only 8 of WV's 55 counties (state reporting is sparse).
- The result's **county is taken from the census block**, which can differ from the mailing city (e.g. a Purgitsville mailing address whose block is in Hardy County).

## Extending to other states

Each state's fiber layers come from that state's FCC BDC "Fiber to the Premises" file (`bdc_<stateFIPS>_FibertothePremises_…`). Process it the same way (aggregate residential locations to counties and to census blocks) to add another state.

## License

[MIT](LICENSE).

---

*Built with [Claude Code](https://claude.com/claude-code).*
