# Area Recon — guide for a new agent

> Read this first. It explains what the project is, how the code and data fit together,
> and what's done (it's all shipped). Self-contained — assumes no prior context.

## What it is

**Area Recon** is an interactive map for "scouting" a U.S. area on three axes — **fiber-internet
availability**, **violent crime**, and **terrain** — with an **address search** that drops a pin and
reports details down to the **2020 census block**. It opens on West Virginia (the most detailed
state) over a national backdrop.

- **Live site:** https://seerstaffing.github.io/area-recon/ (GitHub Pages, `main` branch root)
- **Repo:** https://github.com/SeerStaffing/area-recon (owner/account: `SeerStaffing`)

## TL;DR architecture

- **One static page, no build step, no framework.** `index.html` contains all the HTML, CSS, UI logic,
  and the *state-level* data. It loads three small **companion data files** via `<script src>`:
  `county_fiber.js`, `county_crime.js`, `wv_blocks.js`.
- Map is **Leaflet** over topographic raster tiles; the choropleths are **GeoJSON overlays** styled by
  data. County/state **boundaries** (TopoJSON) and **basemap tiles** load from CDNs at runtime; a few
  **geo APIs** are called client-side (geocoding, elevation, census block).
- **To change the app, edit `index.html` directly.** To change data, regenerate a companion file with a
  script in `scripts/` (see *Data pipeline*).

## Run / preview

No build. Needs internet at view time (CDN libs, map tiles, geo APIs).

- Quickest: open `index.html` in a browser. *Caveat:* the WV exact-block lookup needs `wv_blocks.js`
  beside it (it is). The other 49 states load on demand from `blocks/<NN>.js`, which must be beside the
  page — over `file://` you only get WV; use a local server or the hosted site for the full lookup:
- Windows (no Node/Python needed): `powershell -ExecutionPolicy Bypass -File scripts\serve.ps1` → http://localhost:8123/
- Anywhere: `python -m http.server 8123` or `npx serve`.
- When verifying changes, load it and **check the browser console for errors**; exercise: US bivariate
  view, drill into a state, the four county toggles, the elevation probe, and an address search.

## Repository layout

```
index.html            The entire app: HTML/CSS, all JS logic, and state-level data (DATA, WV).
county_fiber.js       window.COUNTYFIBER = { "<fips5>": {g:gigabit%, a:anyFiber%} }  — all 3,232 counties.
county_crime.js       window.COUNTYCRIME = { "<fips5>": violentCrimePer100k }         — ~3,041 counties.
wv_blocks.js          window.WVBLK = { any:"<csv of 13-digit blocks>", nogig:"..." }  — WV exact-block fiber (loaded upfront).
blocks/<NN>.js        window.STATEBLK["<NN>"] = { any:"...", nogig:"..." }  — per-state exact-block fiber, loaded on demand.
data/wv_fiber_counts.csv   Intermediate (per-county WV fiber counts). Not used at runtime.
scripts/serve.ps1     Minimal local static server (Windows).
scripts/build_*.ps1   Regenerate the companion data files from source downloads (see Data pipeline).
README.md             User-facing description.
CLAUDE.md             This file.
```

## Data layers & sources

| Layer (where shown) | Source | File / object | Coverage | Vintage / notes |
|---|---|---|---|---|
| **State fiber %** (US "fiber" + bivariate) | Reviews.org | `DATA` in index.html | 50 + DC | US avg ≈52%. Whole-state estimate. |
| **State violent crime** (US "crime" + bivariate) | FBI 2024 | `DATA` in index.html | 50 + DC | rate /100k; US avg **359.1** (`NAT_CRIME`). |
| **County fiber** gigabit + any (county view) | **FCC BDC, Dec 2025** | `COUNTYFIBER` (county_fiber.js) | all counties | **Official** residential FTTP availability %. gig = ≥1000/100 Mbps. |
| **County violent crime** (county view) | hybrid | `COUNTYCRIME` (crime.js) + `WV` recent | ~3,041 counties | **Newest where available** (FBI UCR via PlainCrime, e.g. WV's larger counties), else **County Health Rankings ~2009–2011** backfill. |
| **County broadband adoption** (county view, **WV only**) | Census ACS 2014–18 | `WV[fips].bb` | WV 55 | households subscribing to *any* broadband (not fiber). |
| **Exact census-block fiber** (address popup, **all 50 states**) | FCC BDC location file | `STATEBLK` (blocks/<NN>.js; WV via wv_blocks.js) | all states | yes/gig/no at the searched block; each state's file loads on demand. |
| **Elevation** (labels + probe) | Open-Meteo (Copernicus DEM) | runtime fetch | everywhere | per-county centroid labels + click-to-probe. |
| Geocoding | U.S. Census Geocoder (JSONP → 2020 block); Photon (autocomplete); Nominatim (fallback); geo.fcc.gov (block) | runtime | everywhere | Census geocoder handles rural addresses + returns the block. |
| Basemaps | USGS Topo, OpenTopoMap, Esri hillshade/relief, CARTO | runtime tiles | — | switch via the map's layer control. |
| Boundaries | us-atlas (Census) via jsDelivr | runtime | — | states-10m / counties-10m TopoJSON. |

## How `index.html` is organized

The `<script>` is split by comment banners — search for `===` to jump around:
`DATA` · `COLORS` · `FORMAT` · `STATE` · `MAP (Leaflet + terrain)` · `VIEW SWITCHING` · `TOOLTIP` ·
`CONTROLS` · `HEADER / BANNER` · `LEGEND` · `CALLOUTS` · `TABLE` · `FOOTER` · `RENDER ALL`.

Key globals & accessors:
- `level` = `"us"` | `"county"`; `usView` = `"biv"|"fiber"|"crime"`; `coView` = `"gig"|"fiberAny"|"crime"|"bb"`.
- `currentFips` / `currentName` (drilled state); `coRows` (current state's county rows for the table/callouts).
- `cf(fips)` → county fiber `{g,a}`; `ccr(fips)` → CHR crime; `crimeOf(fips)` → **hybrid** crime (recent else CHR);
  `crimeRecentOf(fips)` → was it the recent figure; `fipsToName` (built once from county geometry).
- `countyData(fips)` → `{name, gig, any, bb, crime, crimeRecent}` — the one accessor most UI uses.
- Colors: `colorFor` (state), `countyCell` (county fill by `coView`), scales `fiberCoColor`/`coCrimeCol`/`bbColor`/`fiberColor`/`crimeColor`, bivariate `BIV`.

Map flow:
- `drillDown(fips,name)` loads `counties-10m` (once), filters to the state, draws a GeoJSON layer
  (`dataLayer`), builds `coRows`, fits bounds, adds elevation labels, `renderAll()`.
- `backToUS()` swaps `dataLayer` to the states GeoJSON.
- `styleUS` / `styleCounty` set fill+border; `fillOpacityForZoom`/`borderForZoom` make fills fade and
  borders thicken as you zoom in (so the topo shows but county lines stay visible). `zoomend` re-styles.
- `renderControls/Legend/Callouts/Table/updateHeader` rebuild the UI per `level`/`view`. The county
  toggle set is gig/any/crime for every state, **plus adoption only for WV** (`currentFips==="54"`).

Address search (bottom of script): `suggest()` (Photon autocomplete), `resolveAddress()` →
`censusGeocode()` (JSONP, returns coords + 2020 block) → popup with elevation, block fiber
(`blockFiberHtml`, nationwide via `STATEBLK`; `ensureStateBlocks` loads each state's `blocks/<NN>.js` on
demand, WV embedded), and county stats (`countyFromBlockHtml`, all states).

## Data pipeline (regenerating companion files)

Each companion file is generated by a script in `scripts/` from a public download. They were built on
this machine with PowerShell (no Node/Python). Sources:
- `county_fiber.js` ← FCC **"Fixed Broadband Summary by Geography"** zip (one nationwide file) →
  `scripts/build_county_fiber.ps1`.
- `county_crime.js` ← County Health Rankings CSV (`Measure name = "Violent crime rate"`) →
  `scripts/build_county_crime.ps1`.
- `wv_blocks.js` ← WV's **"Fiber to the Premises"** location zip →
  `scripts/build_state_blocks.ps1` (general; emits `window.STATEBLK[fips]` — see below).

FCC files come from **broadbandmap.fcc.gov/data-download**. Heads-up: that portal is an Angular SPA
behind **Akamai bot-detection**, so downloads can't be reliably scripted — they're grabbed manually in
a real browser and dropped in `~/Downloads`, then processed locally.

## STATUS

**Done:** county fiber (all states, official FCC) · county crime (all states, hybrid) · per-county
elevation + probe · topo basemaps + zoom-responsive fills · US bivariate + state/county drill-down ·
**exact-block fiber nationwide** (address search; WV embedded, the other 49 states load on demand from
`blocks/<NN>.js`) · deployed to Pages.

### DONE: exact-block fiber for all 50 states (wired Jun 2026)

`scripts/build_state_blocks.ps1` processes every `bdc_<NN>_FibertothePremises_*.zip` in `~/Downloads`
into `blocks/<NN>.js` (`window.STATEBLK["<NN>"]={any,nogig}`; block id = 15-digit GEOID minus the 2-digit
state prefix). `index.html` loads a state's file on demand the first time an address there is searched:
`ensureStateBlocks(fips)` injects `<script src="blocks/<NN>.js">` (a script tag, **not** `fetch`, so it
also works from `file://`), then `blockFiberHtml` reads `STATEBLK[block.slice(0,2)]` through `blkSets`
(string → `Set`, cached). WV stays embedded in `wv_blocks.js` (loaded upfront, folded into
`STATEBLK["54"]`) so it still works on the `file://` working copy with no `blocks/` folder beside it; the
hosted Pages site serves all 50. **To refresh:** re-download the state zips and re-run the script.

The block set = "≥1 residential (`biz_res` R/X) fiber-serviceable location in this block" (any), with
`nogig` for blocks that have fiber but not gigabit (`max_advertised_download_speed` < 1000) — the best
address-level signal from public FCC data, not a guarantee at the exact parcel.

### Other extension ideas
- Widen the **recent** crime layer beyond WV (add a `RECENTCRIME` object `{fips:rate}`; `crimeOf` already
  prefers WV's recent — generalize it to prefer `RECENTCRIME` over `COUNTYCRIME`).
- A **live** exact-block lookup was considered but rejected: the FCC fiber API blocks CORS from the
  static site, and a Cloudflare-Worker proxy would likely be blocked by the same bot-detection.

## Deploy

`gh` is authed as `SeerStaffing`. Standard flow from the repo:
```
git add -A
git commit -m "..."   # end with: Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
git push              # GitHub Pages rebuilds main automatically (~1 min)
```
On this Windows box `gh` is **not on PATH** — call it at `C:\Program Files\GitHub CLI\gh.exe`. Shell
network needs the sandbox disabled for git/gh to reach GitHub.

## Conventions / gotchas
- Edit `index.html` directly; keep its `<title>`/wordmark "Area Recon".
- Companion data files must sit beside `index.html` (loaded by relative `<script src>`).
- County FIPS are **5-digit strings with leading zeros** ("01001"); state FIPS are 2-digit ("06").
- Big CSVs are parsed by **right-anchored** comma split (fields after a possibly-comma'd name are taken
  from the end) — see the scripts.
- Numbers: county fiber values in `COUNTYFIBER` are already **percentages**; crime is **rate /100k**.
