# ---------------------------------------------------------------------------
# package_msix.ps1 -- Build Zedu Desktop for Windows and pack it as an MSIX.
#
# Steps: flutter build windows --release -> stage the Release folder plus the
# MSVC runtime -> render windows/packaging/AppxManifest.template.xml -> copy
# the logos -> sanity checks -> MakeAppx pack -> (optional) test-sign.
#
# Output: build\msix\Zedu_<version>.msix (build\ is git-ignored).
#
# Usage (from the repo root, PowerShell):
#   .\windows\packaging\package_msix.ps1 -Sign
#   .\windows\packaging\package_msix.ps1 -SkipBuild -Sign      # reuse the last build
#   .\windows\packaging\package_msix.ps1 -Version 0.1.0.7       # explicit version
#
# Needs: Flutter, Visual Studio 2022+ with "Desktop development with C++"
# (including "C++ ATL" for flutter_secure_storage), and the Windows 10/11 SDK
# (MakeAppx.exe, signtool.exe).
# ---------------------------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$Sign,

    # Four-part MSIX version. Default: pubspec "x.y.z+n" -> "x.y.z.0".
    # Store submissions must use 0 as the last part and always increase.
    [string]$Version,

    # Package identity. The defaults are for sideloaded test builds; a Store
    # build uses the Partner Center "Product identity" values instead.
    [string]$IdentityName = "Zedu.Desktop",
    # Must equal the signing certificate's subject (see sign_msix_for_test.ps1).
    [string]$Publisher = "CN=Zedu Desktop Test",
    [string]$PublisherDisplayName = "Zedu",
    [string]$DisplayName = "Zedu",

    # Pin CMake to a Visual Studio instance, e.g.
    #   "C:\Program Files\Microsoft Visual Studio\18\Community"
    # Use this when several VS installs exist and CMake picks one without ATL
    # (atlstr.h not found). Applied on a fresh build\windows\x64 only.
    [string]$VsInstance,

    [string]$OutDir = "build\msix"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $repoRoot
$outRoot = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
$staging = Join-Path $outRoot "staging"
$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"

function Find-SdkTool([string]$Name) {
    $sdkBin = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    $tool = Get-ChildItem -Path $sdkBin -Recurse -Filter $Name -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\' } |
            Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $tool) { throw "$Name not found under $sdkBin. Install the Windows 10/11 SDK." }
    return $tool.FullName
}

function Find-VsInstance {
    if ($VsInstance) { return $VsInstance }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $null }
    # Prefer an instance that has ATL: flutter_secure_storage needs atlstr.h.
    $withAtl = & $vswhere -products * -latest -requires Microsoft.VisualStudio.Component.VC.ATL -property installationPath
    if ($withAtl) { return ($withAtl | Select-Object -First 1) }
    return (& $vswhere -products * -latest -property installationPath | Select-Object -First 1)
}

# --- 1. Version ------------------------------------------------------------
if (-not $Version) {
    $line = Select-String -Path (Join-Path $repoRoot "pubspec.yaml") -Pattern '^version:\s*(\S+)' | Select-Object -First 1
    if (-not $line) { throw "No version: line in pubspec.yaml" }
    $semver = ($line.Matches[0].Groups[1].Value -split '\+')[0]
    $parts = @($semver -split '\.' | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    $Version = ($parts[0..3] -join '.')
}
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "Version must have four numeric parts, got '$Version'." }
Write-Host "==> Zedu MSIX $Version  ($IdentityName, $Publisher)"

# --- 2. Build --------------------------------------------------------------
if (-not (Test-Path (Join-Path $repoRoot ".env"))) {
    throw ".env is missing. It is bundled as an asset: copy .env.example to .env first (no secrets)."
}
if (-not $SkipBuild) {
    $vs = Find-VsInstance
    $cmake = if ($vs) { Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" }
    if ($cmake -and (Test-Path $cmake)) {
        # Flutter re-runs CMake configure on every build, and CMake keeps the
        # generator instance recorded in an existing cache. Pin it to the VS
        # install that has ATL, so a Build Tools install without it is not
        # picked (atlstr.h not found). --config-only first writes
        # windows\flutter\ephemeral\generated_config.cmake, which CMake needs.
        Write-Host "==> flutter build windows --release --config-only"
        & flutter build windows --release --config-only
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows --config-only failed." }

        $cacheDir = Join-Path $repoRoot "build\windows\x64"
        $cache = Join-Path $cacheDir "CMakeCache.txt"
        $want = $vs -replace '\\', '/'
        $have = if (Test-Path $cache) {
            (Select-String -Path $cache -Pattern '^CMAKE_GENERATOR_INSTANCE:[A-Z]+=(.*)$' | Select-Object -First 1).Matches.Groups[1].Value
        }
        if ($have -ne $want) {
            Write-Host "==> Pinning CMake to $vs"
            if (Test-Path $cacheDir) { Remove-Item $cacheDir -Recurse -Force }
            $gen = & $cmake --help | Select-String -Pattern '^\* (Visual Studio \d+ \d+)' | Select-Object -First 1
            if (-not $gen) { throw "Could not find the default Visual Studio generator in cmake --help." }
            & $cmake -S windows -B build\windows\x64 -G $gen.Matches[0].Groups[1].Value -A x64 `
                "-DCMAKE_GENERATOR_INSTANCE=$want" -DFLUTTER_TARGET_PLATFORM=windows-x64 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (run it without | Out-Null to see why)." }
        }
    }
    Write-Host "==> flutter build windows --release"
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed." }
}
if (-not (Test-Path (Join-Path $releaseDir "zedu.exe"))) { throw "No release build at $releaseDir. Run without -SkipBuild." }

# --- 3. Stage --------------------------------------------------------------
Write-Host "==> Staging $staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force $staging | Out-Null
# Flutter finds data\ next to the exe, so the Release layout is kept as-is.
robocopy $releaseDir $staging /MIR /NFL /NDL /NJH /NJS /NP /XF *.pdb *.exp *.lib *.ilk | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)." }

# The Release folder does not include the MSVC runtime; a clean machine may
# not have it. Ship it in the package.
$vs = Find-VsInstance
$crt = $null
if ($vs) {
    $crt = Get-ChildItem -Path (Join-Path $vs "VC\Redist\MSVC") -Directory -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending |
           ForEach-Object { Get-ChildItem (Join-Path $_.FullName "x64") -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue } |
           Select-Object -First 1
}
if (-not $crt) { throw "MSVC runtime (VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT) not found. Install VS C++ tools." }
Copy-Item (Join-Path $crt.FullName "*.dll") $staging -Force
Write-Host "    MSVC runtime from $($crt.FullName)"

# --- 4. Manifest and logos -------------------------------------------------
$template = Get-Content -Raw (Join-Path $repoRoot "windows\packaging\AppxManifest.template.xml")
$esc = { param($s) [Security.SecurityElement]::Escape($s) }
$manifest = $template.
    Replace("{{IDENTITY_NAME}}", (& $esc $IdentityName)).
    Replace("{{PUBLISHER}}", (& $esc $Publisher)).
    Replace("{{VERSION}}", $Version).
    Replace("{{DISPLAY_NAME}}", (& $esc $DisplayName)).
    Replace("{{PUBLISHER_DISPLAY_NAME}}", (& $esc $PublisherDisplayName))
if ($manifest -match '\{\{[A-Z_]+\}\}') { throw "Unfilled placeholder left in the manifest: $($Matches[0])" }
[xml]$null = $manifest   # fail here, not inside MakeAppx, on bad XML
Set-Content -Path (Join-Path $staging "AppxManifest.xml") -Value $manifest -Encoding UTF8
Copy-Item (Join-Path $repoRoot "windows\packaging\Assets") (Join-Path $staging "Assets") -Recurse -Force

# --- 5. Checks -------------------------------------------------------------
$markers = @(
    "zedu.exe", "flutter_windows.dll", "AppxManifest.xml",
    "data\icudtl.dat", "data\app.so", "data\flutter_assets\AssetManifest.bin",
    "data\flutter_assets\.env", "vcruntime140.dll", "msvcp140.dll",
    "Assets\StoreLogo.png", "Assets\Square44x44Logo.png", "Assets\Square150x150Logo.png"
)
$missing = @($markers | Where-Object { -not (Test-Path (Join-Path $staging $_)) })
if ($missing.Count) { throw "Staging is missing: $($missing -join ', ')" }

# --- 6. Pack ---------------------------------------------------------------
$makeAppx = Find-SdkTool "makeappx.exe"
$msix = Join-Path $outRoot "Zedu_$Version.msix"
Write-Host "==> MakeAppx pack -> $msix"
$out = & $makeAppx pack /d $staging /p $msix /overwrite 2>&1
if ($LASTEXITCODE -ne 0) {
    $out | Where-Object { $_ -match 'error|warning' } | ForEach-Object { Write-Host "    $_" }
    throw "MakeAppx failed ($LASTEXITCODE)."
}
Write-Host ("    {0:N1} MB" -f ((Get-Item $msix).Length / 1MB))

# --- 7. Sign ---------------------------------------------------------------
if ($Sign) {
    & (Join-Path $PSScriptRoot "sign_msix_for_test.ps1") -MsixPath $msix -Subject $Publisher
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Signing failed." }
} else {
    Write-Host "    Unsigned (Store upload, or add -Sign for a sideload test build)."
}
Write-Host "==> Done: $msix"
