# ---------------------------------------------------------------------------
# sign_msix_for_test.ps1 -- Sign an MSIX with a local self-signed certificate.
#
# For sideloaded TEST builds only. Store builds are uploaded unsigned and
# Microsoft signs them.
#
# The certificate lives in the current user's store (Cert:\CurrentUser\My);
# it is created on first use and reused after that. Nothing is trusted on this
# machine. The public .cer is exported next to the package so a TEST machine
# can trust it (LocalMachine\TrustedPeople) before Add-AppxPackage.
# signtool signs straight from the certificate store, so there is no .pfx file
# and no password to keep.
#
# Usage:
#   .\windows\packaging\sign_msix_for_test.ps1 -MsixPath build\msix\Zedu_0.1.0.0.msix
# ---------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MsixPath,
    # Must equal the Publisher in the package's AppxManifest.xml.
    [string]$Subject = "CN=Zedu Desktop Test"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $MsixPath)) { throw "Not found: $MsixPath" }
$MsixPath = (Resolve-Path $MsixPath).Path

# Refuse to sign with a subject the package does not declare: Add-AppxPackage
# would reject the result with a publisher mismatch.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($MsixPath)
try {
    $entry = $zip.GetEntry("AppxManifest.xml")
    $reader = New-Object IO.StreamReader($entry.Open())
    [xml]$manifest = $reader.ReadToEnd()
    $reader.Dispose()
} finally { $zip.Dispose() }
$declared = $manifest.Package.Identity.Publisher
if ($declared -ne $Subject) {
    throw "Manifest Publisher '$declared' does not match the certificate subject '$Subject'."
}

$cert = Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $Subject -and $_.NotAfter -gt (Get-Date).AddDays(7) -and $_.HasPrivateKey } |
        Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $cert) {
    Write-Host "==> Creating a self-signed code-signing certificate: $Subject (CurrentUser\My)"
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject `
        -KeyUsage DigitalSignature -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(2) `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
}
Write-Host "    Certificate $($cert.Thumbprint), expires $($cert.NotAfter.ToString('yyyy-MM-dd'))"

$sdkBin = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
$signTool = Get-ChildItem -Path $sdkBin -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $signTool) { throw "signtool.exe not found under $sdkBin. Install the Windows 10/11 SDK." }

& $signTool.FullName sign /fd SHA256 /s My /sha1 $cert.Thumbprint $MsixPath
if ($LASTEXITCODE -ne 0) { throw "signtool sign failed ($LASTEXITCODE)." }

$cer = Join-Path (Split-Path $MsixPath -Parent) "zedu_test.cer"
Export-Certificate -Cert $cert -FilePath $cer -Type CERT | Out-Null
Write-Host "==> Signed. Test machines trust it with (admin):"
Write-Host "    Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
Write-Host "    then: Add-AppxPackage -Path $MsixPath"
