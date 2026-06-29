# Builds per-state exact-block fiber files: blocks/<NN>.js, each setting
#   window.STATEBLK["<NN>"] = { any:"<csv of 13-digit block ids>", nogig:"<csv>" }
# where a block id = its 15-digit 2020 census-block GEOID minus the 2-digit state prefix, "any" = blocks
# with >=1 residential fiber-serviceable location, "nogig" = those that have fiber but not gigabit.
#
# SOURCE: each state's FCC "Fiber to the Premises" fixed-broadband LOCATION file, e.g.
#   bdc_06_FibertothePremises_fixed_broadband_D25_*.zip  (06 = California's FIPS).
#   Download per state at https://broadbandmap.fcc.gov/data-download (By State) into ~\Downloads.
# This is the PENDING step to extend exact-block fiber beyond WV (see CLAUDE.md "TODO").
#
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\build_state_blocks.ps1
param(
  [string]$Dir    = "$HOME\Downloads",
  [string]$OutDir = (Join-Path $PSScriptRoot "..\blocks")
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force $OutDir | Out-Null
$files = Get-ChildItem $Dir -Filter 'bdc_*_FibertothePremises_*.zip'
if (-not $files) { throw "No bdc_*_FibertothePremises_*.zip files found in $Dir" }
$ok = 0; $fail = @(); $swAll = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($f in $files) {
  if ($f.Name -notmatch 'bdc_(\d+)_') { continue }
  $fips = $matches[1]; $sr = $null; $zip = $null
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($f.FullName)
    $entry = $zip.Entries | Sort-Object Length -Descending | Select-Object -First 1   # the CSV
    $sr = New-Object System.IO.StreamReader($entry.Open())
    $any = New-Object 'System.Collections.Generic.HashSet[string]'
    $gig = New-Object 'System.Collections.Generic.HashSet[string]'
    $null = $sr.ReadLine()                                  # header
    while (-not $sr.EndOfStream) {
      $t = $sr.ReadLine().Split(','); $c = $t.Length; if ($c -lt 9) { continue }
      # right-anchored cols: location_id(c-9),technology(c-8),max_dl(c-7),max_ul(c-6),low_latency(c-5),
      # biz_res(c-4),state(c-3),block_geoid(c-2),h3(c-1).
      $maxdl = $t[$c-7]; $br = $t[$c-4]; $blk = $t[$c-2]
      if (($br -ne 'R' -and $br -ne 'X') -or $blk.Length -ne 15) { continue }
      $key = $blk.Substring(2)
      [void]$any.Add($key)
      $dl = 0; [void][int]::TryParse($maxdl, [ref]$dl)
      if ($dl -ge 1000) { [void]$gig.Add($key) }
    }
    $sr.Close(); $zip.Dispose()
    $nogig = New-Object 'System.Collections.Generic.List[string]'
    foreach ($b in $any) { if (-not $gig.Contains($b)) { $nogig.Add($b) } }
    $js = 'window.STATEBLK=window.STATEBLK||{};window.STATEBLK["' + $fips + '"]={any:"' +
          ($any -join ',') + '",nogig:"' + ($nogig -join ',') + '"};'
    [System.IO.File]::WriteAllText((Join-Path $OutDir "$fips.js"), $js, [System.Text.Encoding]::ASCII)
    $ok++
    Write-Host ("{0}: any={1} nogig={2}  ({3:n0}s)" -f $fips, $any.Count, $nogig.Count, $sw.Elapsed.TotalSeconds)
  } catch {
    $fail += $fips
    Write-Warning ("{0}: FAILED - {1}" -f $fips, $_.Exception.Message)
    if ($sr)  { try { $sr.Close() }   catch {} }
    if ($zip) { try { $zip.Dispose() } catch {} }
  }
}
Write-Host ("Done in {0:n0}s. OK={1} Failed={2} [{3}]. Per-state files in {4} (wire on-demand <script src> in index.html)." -f `
  $swAll.Elapsed.TotalSeconds, $ok, $fail.Count, ($fail -join ','), $OutDir)
