# Builds county_crime.js (window.COUNTYCRIME = {"<fips5>": violentCrimePer100k}) — the nationwide
# "older" crime backfill. The app prefers newer per-county figures where available (see crimeOf()).
#
# SOURCE: County Health Rankings dataset (long format, FBI UCR-based "Violent crime rate" measure).
#   Convenient copy: https://public.tableau.com/app/sample-data/County_Health_Rankings.csv  (~2009-2011).
#   For a newer vintage, use the official CHR analytic-data CSV (~2014-2016) and adapt the column names.
# We take the LATEST "Year span" per county. fipscode is the 5-digit FIPS (may lack a leading zero).
#
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\build_county_crime.ps1
param(
  [string]$Csv = "$HOME\Downloads\County_Health_Rankings.csv",
  [string]$Out = (Join-Path $PSScriptRoot "..\county_crime.js")
)
if (-not (Test-Path $Csv)) { throw "CHR CSV not found at $Csv" }
$latest = @{}
Import-Csv $Csv |
  Where-Object { $_.'Measure name' -eq 'Violent crime rate' -and $_.'Raw value' -ne '' -and [int]$_.'County code' -ne 0 } |
  ForEach-Object {
    $fips = $_.fipscode.PadLeft(5,'0'); $ys = $_.'Year span'
    if (-not $latest.ContainsKey($fips) -or $ys -gt $latest[$fips][1]) { $latest[$fips] = @($_.'Raw value', $ys) }
  }
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('window.COUNTYCRIME={'); $n = 0
foreach ($k in ($latest.Keys | Sort-Object)) {
  $v = [math]::Round([double]$latest[$k][0], 1)
  if ($n -gt 0) { [void]$sb.Append(',') }
  [void]$sb.Append('"' + $k + '":' + $v); $n++
}
[void]$sb.Append('};')
[System.IO.File]::WriteAllText($Out, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host "Wrote $Out  ($n counties)"
