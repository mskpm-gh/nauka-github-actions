Write-Host "Simulating Process" -NoNewline
foreach ($i in 1..3) {
  [System.Threading.Thread]::Sleep(1000)
  Write-Host "." -NoNewline
  [Console]::Out.Flush()
}
Write-Host ""