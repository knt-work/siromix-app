param([ValidateRange(1,2147483647)][int]$BuildNumber = 21)
$ErrorActionPreference = 'Stop'
$repoDir = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat' }
Push-Location $repoDir
try {
    & $flutterPath build apk --release --target-platform=android-arm,android-arm64,android-x64 "--build-number=$BuildNumber"
    if ($LASTEXITCODE -ne 0) { throw 'Phone APK build failed.' }
    $sourceApk = Join-Path $repoDir 'build\app\outputs\flutter-apk\app-release.apk'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($sourceApk)
    try {
        $entries = @($zip.Entries | ForEach-Object { $_.FullName })
        foreach ($abi in @('arm64-v8a','armeabi-v7a','x86_64')) {
            if ($entries -notcontains "lib/$abi/libflutter.so") { throw "Missing Flutter engine for $abi" }
        }
    } finally { $zip.Dispose() }
    $distDir = Join-Path $repoDir 'dist'
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null
    $artifact = Join-Path $distDir "SiroMix-build-$BuildNumber-universal.apk"
    Copy-Item -LiteralPath $sourceApk -Destination $artifact -Force
    Write-Output "Phone APK: $artifact"
    Get-FileHash -LiteralPath $artifact -Algorithm SHA256
} finally { Pop-Location }
