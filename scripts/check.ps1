# The 4 checks (Windows). Same as check.sh.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
function Run($label, [scriptblock]$cmd) {
    Write-Host "== $label"
    & $cmd
    if ($LASTEXITCODE -ne 0) { throw "$label failed" }
}
if (-not (Test-Path roblox.yml)) { selene generate-roblox-std | Out-Null }
New-Item -ItemType Directory -Force build | Out-Null
Run '1/4 rojo build' { rojo build -o build/game.rbxl }
Run '2/4 tests' { lune run tests/run }
Run '3/4 selene' { selene src tests }
Run '4/4 stylua' { stylua --check src tests }
Write-Host 'ALL CHECKS PASSED'
