param(
    [string]$EnvPython = "C:\Users\under\.conda\envs\xiaozhi310\python.exe",
    [string]$PrimaryLibraryBin = "C:\Users\under\.conda\envs\xiaozhi310\Library\bin",
    [string]$FallbackLibraryBin = "C:\Users\under\.conda\envs\xiaozhi-esp32-server\Library\bin",
    [string]$FallbackOpusDll = "C:\Users\under\.conda\pkgs\libopus-1.6.1-h6a83c73_0\Library\bin\opus.dll",
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Add-PathPrefix([string]$PathToAdd) {
    if (-not (Test-Path $PathToAdd)) {
        return
    }
    $current = $env:PATH -split ";"
    if ($current -contains $PathToAdd) {
        return
    }
    $env:PATH = "$PathToAdd;$env:PATH"
}

if (-not (Test-Path $EnvPython)) {
    throw "Python not found: $EnvPython"
}

if (-not (Test-Path $PrimaryLibraryBin)) {
    New-Item -ItemType Directory -Path $PrimaryLibraryBin -Force | Out-Null
}

$opusTarget = Join-Path $PrimaryLibraryBin "opus.dll"
if (-not (Test-Path $opusTarget)) {
    $opusCandidates = @(
        (Join-Path $FallbackLibraryBin "opus.dll"),
        $FallbackOpusDll
    )

    $copied = $false
    foreach ($candidate in $opusCandidates) {
        if (Test-Path $candidate) {
            Copy-Item $candidate $opusTarget -Force
            $copied = $true
            break
        }
    }

    if (-not $copied) {
        throw "opus.dll not found. Checked: $($opusCandidates -join ', ')"
    }
}

Add-PathPrefix $PrimaryLibraryBin
Add-PathPrefix $FallbackLibraryBin

$configPath = Join-Path $PSScriptRoot "data\.config.yaml"
if (Test-Path $configPath) {
    $serverPort = Select-String -Path $configPath -Pattern "^\s*port:\s*9000\s*$" -SimpleMatch:$false
    if (-not $serverPort) {
        Write-Warning "data/.config.yaml does not contain 'port: 9000'. Please verify websocket port."
    }
}

& $EnvPython -c "import ctypes.util, shutil, sys; opus=ctypes.util.find_library('opus'); ffmpeg=shutil.which('ffmpeg'); print(f'python={sys.executable}'); print(f'opus={opus}'); print(f'ffmpeg={ffmpeg}'); sys.exit(0 if opus and ffmpeg else 1)"
if ($LASTEXITCODE -ne 0) {
    throw "Dependency check failed. opus or ffmpeg is missing in current PATH."
}

if ($CheckOnly) {
    Write-Host "Dependency check passed."
    exit 0
}

& $EnvPython app.py
exit $LASTEXITCODE
