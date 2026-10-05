$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path -LiteralPath '.local/database.ini')) { throw 'Existing local database configuration is required.' }
if (-not (Test-Path -LiteralPath 'canary.exe')) { throw 'Build the server using Build-Foundation.cmd first.' }
if (-not (Test-Path -LiteralPath 'data-canary/world/nostalgia-sandbox.otbm')) { throw 'Save the native RME sandbox map first.' }
$listening = Get-NetTCPConnection -State Listen -LocalPort 3307 -ErrorAction SilentlyContinue
if (-not $listening) {
    Start-Process -FilePath '.local/mariadb-11.4.13-winx64/bin/mariadbd.exe' -ArgumentList '--defaults-file=C:/AI/NostalgiaServer/.local/database.ini','--console' -WindowStyle Hidden -RedirectStandardOutput '.local/database.stdout.log' -RedirectStandardError '.local/database.stderr.log'
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 200
        if (Get-NetTCPConnection -State Listen -LocalPort 3307 -ErrorAction SilentlyContinue) { break }
    }
}
& python tools/provision-nostalgia.py
if ($LASTEXITCODE) { throw 'Local sandbox provisioning failed.' }
& ./canary.exe
exit $LASTEXITCODE
