# ---------------------------------------------------------------------------
# make_msix_logos.ps1 -- Generate the MSIX tile and splash images.
#
# Writes the seven PNGs referenced by windows/packaging/AppxManifest.template.xml
# into windows/packaging/Assets. Run it again whenever the app icon changes, and
# commit the result. No Python or extra tools: System.Drawing only.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File windows\packaging\make_msix_logos.ps1
#   ... -Source path\to\icon.png -Background "#6458F5"
# ---------------------------------------------------------------------------

[CmdletBinding()]
param(
    # A square icon, at least 310 px, so nothing is upscaled.
    [string]$Source = "macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png",
    # Fill for the wide tile and splash screen (AppPalette.light.primary).
    [string]$Background = "#6458F5",
    [string]$OutDir = "windows\packaging\Assets"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$srcPath = if ([IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $repoRoot $Source }
$outPath = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
if (-not (Test-Path $srcPath)) { throw "Source icon not found: $srcPath" }
New-Item -ItemType Directory -Force $outPath | Out-Null

$src = [System.Drawing.Image]::FromFile($srcPath)
try {
    if ($src.Width -lt 310 -or $src.Height -lt 310) {
        throw "Source is $($src.Width)x$($src.Height); needs at least 310x310 so tiles are not upscaled."
    }
    $bg = [System.Drawing.ColorTranslator]::FromHtml($Background)

    # name, width, height, padded (centred on the brand colour) or plain resize
    $targets = @(
        @("StoreLogo.png",         50,  50, $false),
        @("Square44x44Logo.png",   44,  44, $false),
        @("Square71x71Logo.png",   71,  71, $false),
        @("Square150x150Logo.png", 150, 150, $false),
        @("Square310x310Logo.png", 310, 310, $false),
        @("Wide310x150Logo.png",   310, 150, $true),
        @("SplashScreen.png",      620, 300, $true)
    )

    foreach ($t in $targets) {
        $name, $w, $h, $padded = $t
        $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            if ($padded) {
                $g.Clear($bg)
                $side = [int]([Math]::Min($w, $h) * 0.62)
                $g.DrawImage($src, [int](($w - $side) / 2), [int](($h - $side) / 2), $side, $side)
            } else {
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.DrawImage($src, 0, 0, $w, $h)
            }
            $file = Join-Path $outPath $name
            $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "  $name  ${w}x${h}"
        } finally {
            $g.Dispose()
            $bmp.Dispose()
        }
    }
} finally {
    $src.Dispose()
}
Write-Host "==> Logos written to $outPath"
