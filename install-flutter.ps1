$ErrorActionPreference = 'Stop'
$installParent = 'C:\Users\nhutt\develop'
$sdkPath = Join-Path $installParent 'flutter'
$sdkBin = Join-Path $sdkPath 'bin'
if (Test-Path -LiteralPath $sdkPath) { throw "Flutter destination already exists: $sdkPath. Inspect before continuing." }
New-Item -ItemType Directory -Force -Path $installParent | Out-Null
Write-Output 'Cloning official Flutter stable SDK...'
& git clone --branch stable --depth 1 https://github.com/flutter/flutter.git $sdkPath
if ($LASTEXITCODE -ne 0) { throw 'Flutter clone failed.' }
if (-not (Test-Path -LiteralPath (Join-Path $sdkBin 'flutter.bat'))) { throw 'flutter.bat missing after extraction.' }
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $sdkBin) {
    [Environment]::SetEnvironmentVariable('Path', ($sdkBin + ';' + $userPath), 'User')
}
$env:Path = $sdkBin + ';' + $env:Path
Write-Output 'Flutter SDK installed; user PATH updated.'
& (Join-Path $sdkBin 'flutter.bat') config --no-analytics
& (Join-Path $sdkBin 'flutter.bat') --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter version check failed.' }
& (Join-Path $sdkBin 'dart.bat') --version
& (Join-Path $sdkBin 'flutter.bat') doctor -v
