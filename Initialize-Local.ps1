$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$localDir = Join-Path $PSScriptRoot '.local'
$maria = Join-Path $localDir 'mariadb-11.4.13-winx64\bin'
$dbDir = Join-Path $localDir 'database'
$credentialsPath = Join-Path $localDir 'credentials.json'
if (Test-Path $credentialsPath) { throw 'Local setup already exists; preserving credentials and database.' }
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
function New-Password { $b = New-Object byte[] 24; $rng.GetBytes($b); return [Convert]::ToBase64String($b) }
$credentials = @{ root = New-Password; database = New-Password; account = New-Password; email = 'phasea@nostalgia.local' }
$credentials | ConvertTo-Json | Set-Content $credentialsPath -Encoding UTF8
& "$maria\mariadb-install-db.exe" "--datadir=$dbDir" "--password=$($credentials.root)" '--port=3307'
if ($LASTEXITCODE) { throw 'Database initialization failed' }
$dbConfig = @"
[mysqld]
basedir=$($localDir.Replace('\','/'))/mariadb-11.4.13-winx64
datadir=$($dbDir.Replace('\','/'))
port=3307
bind-address=127.0.0.1
skip-name-resolve
max_connections=32
innodb_buffer_pool_size=128M
[client]
host=127.0.0.1
port=3307
user=root
password=$($credentials.root)
"@
$dbConfig | Set-Content "$localDir\database.ini" -Encoding ASCII
$process = Start-Process "$maria\mariadbd.exe" -ArgumentList "--defaults-file=$localDir\database.ini",'--console' -WindowStyle Hidden -PassThru -RedirectStandardOutput "$localDir\database.stdout.log" -RedirectStandardError "$localDir\database.stderr.log"
$process.Id | Set-Content "$localDir\database.pid"
Start-Sleep -Seconds 3
$sql = "CREATE DATABASE nostalgia CHARACTER SET utf8mb4; CREATE USER 'nostalgia'@'127.0.0.1' IDENTIFIED BY '$($credentials.database)'; GRANT ALL PRIVILEGES ON nostalgia.* TO 'nostalgia'@'127.0.0.1'; USE nostalgia;" + [Environment]::NewLine + (Get-Content schema.sql -Raw)
$sql | & "$maria\mariadb.exe" "--defaults-file=$localDir\database.ini"
if ($LASTEXITCODE) { throw 'Schema initialization failed' }
$config = Get-Content config.lua.dist -Raw
$config = $config.Replace('dataPackDirectory = "data-otservbr-global"','dataPackDirectory = "data-canary"').Replace('mapName = "otservbr"','mapName = "phase-a"').Replace('toggleDownloadMap = true','toggleDownloadMap = false').Replace('bindOnlyGlobalAddress = false','bindOnlyGlobalAddress = true').Replace('mysqlUser = "root"','mysqlUser = "nostalgia"').Replace('mysqlPass = "root"',"mysqlPass = `"$($credentials.database)`"").Replace('mysqlDatabase = "otservbr-global"','mysqlDatabase = "nostalgia"').Replace('mysqlPort = 3306','mysqlPort = 3307')
$config | Set-Content config.lua -Encoding UTF8
Copy-Item data-canary\world\canary.otbm data-canary\world\phase-a.otbm
Write-Output 'Local database/schema/configuration initialized. Credentials are in ignored .local/credentials.json.'
