$ErrorActionPreference = 'Stop'
$sdkDir = 'C:\Users\nhutt\AppData\Local\Android\Sdk'
$flutterBin = 'C:\Users\nhutt\develop\flutter\bin'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = $sdkDir
$env:Path = (Join-Path $env:JAVA_HOME 'bin') + ';' + $flutterBin + ';' + $env:Path
$toolsDir = Join-Path $sdkDir 'cmdline-tools\latest'
$manager = Join-Path $toolsDir 'bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $manager)) {
    if (Test-Path -LiteralPath $toolsDir) { throw 'Command-line Tools destination exists but sdkmanager is missing; inspect before continuing.' }
    $staging = Join-Path ([System.IO.Path]::GetTempPath()) ('siromix-android-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $staging | Out-Null
    $archive = Join-Path $staging 'commandlinetools.zip'
    Write-Output 'Downloading official Android Command-line Tools...'
    & curl.exe --fail --location --retry 3 --silent --show-error --output $archive 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
    if ($LASTEXITCODE -ne 0) { throw 'Command-line Tools download failed.' }
    Write-Output 'Verifying SHA-256...'
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a') { throw 'Checksum mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    Copy-Item -Path (Join-Path $staging 'cmdline-tools\*') -Destination $toolsDir -Recurse
}
[Environment]::SetEnvironmentVariable('ANDROID_HOME',$sdkDir,'User')
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
foreach ($newPath in @((Join-Path $sdkDir 'platform-tools'), (Join-Path $toolsDir 'bin'))) {
    if (($userPath -split ';') -notcontains $newPath) { $userPath = $newPath + ';' + $userPath }
}
[Environment]::SetEnvironmentVariable('Path',$userPath,'User')
& (Join-Path $flutterBin 'flutter.bat') config --android-sdk $sdkDir
& $manager --version
if ($LASTEXITCODE -ne 0) { throw 'sdkmanager version check failed.' }
Write-Output 'Installing platform tools and Android API 36 for Flutter...'
@('y','y','y','y','y','y','y','y','y','y') | & $manager "--sdk_root=$sdkDir" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
if ($LASTEXITCODE -ne 0) { throw 'Android SDK package installation failed.' }
Write-Output 'Checking SDK licenses...'
@('y','y','y','y','y','y','y','y','y','y') | & $manager "--sdk_root=$sdkDir" --licenses
if ($LASTEXITCODE -ne 0) { throw 'Android SDK licenses check failed.' }
& (Join-Path $sdkDir 'platform-tools\adb.exe') version
& (Join-Path $flutterBin 'flutter.bat') doctor -v
