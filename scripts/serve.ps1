# Minimal static file server for previewing Area Recon locally (no Node/Python needed).
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\serve.ps1
# Then open http://localhost:8123/  (Ctrl+C to stop)
$port = 8123
$root = Split-Path $PSScriptRoot -Parent
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Area Recon serving $root at http://localhost:$port/  (Ctrl+C to stop)"
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.LocalPath).TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($path)) { $path = "index.html" }
    $file = Join-Path $root $path
    if (Test-Path $file -PathType Leaf) {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      switch ([System.IO.Path]::GetExtension($file).ToLower()) {
        ".html" { $ctx.Response.ContentType = "text/html; charset=utf-8" }
        ".js"   { $ctx.Response.ContentType = "application/javascript" }
        ".json" { $ctx.Response.ContentType = "application/json" }
        ".css"  { $ctx.Response.ContentType = "text/css" }
        ".csv"  { $ctx.Response.ContentType = "text/csv" }
        default { $ctx.Response.ContentType = "application/octet-stream" }
      }
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $ctx.Response.StatusCode = 404 }
    $ctx.Response.Close()
  } catch {}
}
