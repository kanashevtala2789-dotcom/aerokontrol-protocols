$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:8765/')
$listener.Start()
Write-Host 'Локальный сайт: http://127.0.0.1:8765/' -ForegroundColor Cyan
Write-Host 'Остановить сервер: Ctrl+C'
Start-Process 'http://127.0.0.1:8765/'
$mime = @{
  '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'
  '.wasm'='application/wasm'; '.gz'='application/gzip'; '.css'='text/css; charset=utf-8'
  '.json'='application/json; charset=utf-8'; '.svg'='image/svg+xml'; '.png'='image/png'
  '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.webp'='image/webp'
}
try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    try {
      $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
      $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
      if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $context.Response.StatusCode = 404
        $bytes = [Text.Encoding]::UTF8.GetBytes('Not found')
      } else {
        $context.Response.StatusCode = 200
        $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
        if ($full.EndsWith('.traineddata.gz')) { $ext = '.gz' }
        $context.Response.ContentType = $mime[$ext]
        $context.Response.AddHeader('X-Content-Type-Options','nosniff')
        $bytes = [IO.File]::ReadAllBytes($full)
      }
      $context.Response.ContentLength64 = $bytes.Length
      $context.Response.OutputStream.Write($bytes,0,$bytes.Length)
      $context.Response.Close()
    } catch { try { $context.Response.Abort() } catch {} }
  }
} finally { $listener.Stop(); $listener.Close() }
