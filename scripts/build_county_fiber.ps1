# Builds county_fiber.js (window.COUNTYFIBER = {"<fips5>":{g:gigabit%, a:anyFiber%}}) for all U.S. counties.
#
# SOURCE: FCC "Fixed Broadband Summary by Geography Type - Other Geographies" (one nationwide zip).
#   Get it at https://broadbandmap.fcc.gov/data-download  -> the "Fixed Broadband Summary by Geography
#   Type" row -> "Download zipped ... Other Geographies file". Save the zip to ~\Downloads.
# The CSV inside is one row per (area_data_type, geography_type, geography_id, biz_res, technology) with
# availability fractions per speed tier. We keep:  area_data_type=Total, geography_type=County,
# biz_res=R (residential), technology=Fiber (NOT "Cable/Fiber").  gig=speed_1000_100, any=speed_02_02.
#
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\build_county_fiber.ps1
param(
  [string]$Zip = (Get-ChildItem "$HOME\Downloads\bdc_us_fixed_broadband_summary_by_geography_*.zip" |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName),
  [string]$Out = (Join-Path $PSScriptRoot "..\county_fiber.js")
)
if (-not $Zip) { throw "No summary-by-geography zip found in ~\Downloads." }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($Zip)
$sr  = New-Object System.IO.StreamReader($zip.Entries[0].Open())
$null = $sr.ReadLine()                                   # header
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('window.COUNTYFIBER={'); $count = 0
while (-not $sr.EndOfStream) {
  $t = $sr.ReadLine().Split(','); $n = $t.Length; if ($n -lt 9) { continue }
  # right-anchored: trailing comma-free fields are ...,total_units(n-9),biz_res(n-8),technology(n-7),
  # speed_02_02(n-6),...,speed_1000_100(n-1).  Front: area_data_type(0),geography_type(1),geography_id(2).
  if ($t[0] -ne 'Total' -or $t[1] -ne 'County' -or $t[$n-8] -ne 'R' -or $t[$n-7] -ne 'Fiber') { continue }
  $any = [math]::Round([double]$t[$n-6] * 100, 1)
  $gig = [math]::Round([double]$t[$n-1] * 100, 1)
  if ($count -gt 0) { [void]$sb.Append(',') }
  [void]$sb.Append('"' + $t[2] + '":{g:' + $gig + ',a:' + $any + '}'); $count++
}
$sr.Close(); $zip.Dispose()
[void]$sb.Append('};')
[System.IO.File]::WriteAllText($Out, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host "Wrote $Out  ($count counties)"
