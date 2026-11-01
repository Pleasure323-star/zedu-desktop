# ---------------------------------------------------------------------------
# vm_test_msix.ps1 -- Install the Zedu MSIX on a clean VMware VM and check it.
#
# The clean-machine test for the Windows installer: a guest that has never
# built this repo gets only what the package carries. Checks:
#   1. the test certificate is trusted and the package installs
#   2. "Zedu" appears in the Start menu (Get-StartApps)
#   3. the app launches through its package identity and is still running
#   4. a zedu:// link starts the app (protocol registration)
#   5. uninstalling removes the package
# Evidence (guest command logs, screenshots, a summary) is written to
# build\msix\vm-test\<timestamp>\.
#
# Requirements:
#   - VMware Workstation (vmrun.exe) and a Windows 10/11 guest with VMware
#     Tools, snapshotted with -GuestUser SIGNED IN at the desktop (interactive
#     vmrun calls run in that user's session; the user must be an admin).
#   - A signed package and its .cer: package_msix.ps1 -Sign.
#
# Passwords are never parameters on the command line by default: the guest
# login comes from $env:ZEDU_VM_GUEST_PASSWORD and, for an encrypted VM
# (Windows 11 + vTPM), the VM password from $env:ZEDU_VM_PASSWORD.
#
# Usage:
#   $env:ZEDU_VM_GUEST_PASSWORD = '...'; $env:ZEDU_VM_PASSWORD = '...'
#   .\windows\packaging\vm_test_msix.ps1 -VmxPath "E:\VMs\Win11\Windows 11 x64.vmx" `
#       -SnapshotName "Clean Base" -GuestUser tester
#
# Lessons carried over from the MeBrain VM tests are kept as comments below:
# they look like odd choices and each one fixes a real hang or failure.
# ---------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$VmxPath,
    [Parameter(Mandatory = $true)][string]$SnapshotName,
    [Parameter(Mandatory = $true)][string]$GuestUser,
    [string]$GuestPassword = $env:ZEDU_VM_GUEST_PASSWORD,
    # The VM ENCRYPTION password, not the guest login. A Windows 11 VM needs a
    # vTPM, which requires an encrypted VM; every vmrun call then fails with
    # "A password is required for this operation" until -vp is supplied.
    [string]$VmPassword = $env:ZEDU_VM_PASSWORD,

    [string]$MsixPath,
    [string]$CerPath,
    [string]$GuestDir = "C:\zedutest",
    [string]$Vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe",
    [int]$ObserveSeconds = 30,
    [string]$ProtocolUrl = "zedu://credits/payment-success?session_id=vm_test",
    [switch]$NoRevertAfter
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if (-not (Test-Path $Vmrun)) {
    $alt = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
    if (Test-Path $alt) { $Vmrun = $alt } else { throw "vmrun.exe not found. Pass -Vmrun." }
}
if (-not (Test-Path $VmxPath)) { throw "VM not found: $VmxPath" }
if (-not $GuestPassword) { throw "Set `$env:ZEDU_VM_GUEST_PASSWORD (guest login) or pass -GuestPassword." }

$msixDir = Join-Path $repoRoot "build\msix"
if (-not $MsixPath) {
    $newest = Get-ChildItem (Join-Path $msixDir "Zedu_*.msix") -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { throw "No build\msix\Zedu_*.msix. Run package_msix.ps1 -Sign first." }
    $MsixPath = $newest.FullName
}
if (-not $CerPath) { $CerPath = Join-Path (Split-Path $MsixPath -Parent) "zedu_test.cer" }
foreach ($p in @($MsixPath, $CerPath)) { if (-not (Test-Path $p)) { throw "Not found: $p" } }

$runDir = Join-Path $msixDir ("vm-test\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force $runDir | Out-Null

$guestArgs = @("-gu", $GuestUser, "-gp", $GuestPassword)
# -vp belongs with the authentication flags, before the command.
$vpArgs = @(); if ($VmPassword) { $vpArgs = @("-vp", $VmPassword) }
$VmRunTimeoutMs = 20 * 60 * 1000

function Invoke-VmRun {
    param([string[]]$VmArgs, [switch]$AllowFail, [string]$What = "vmrun")
    # Never `& vmrun ... 2>&1`: `vmrun start` launches the Workstation GUI,
    # which inherits the stdout pipe and keeps it open forever, so the script
    # hangs with no output. Start-Process with files gives the child its own
    # handles. Start-Process does not quote arguments, so quote any with spaces.
    $quoted = @($vpArgs + $VmArgs) | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $so = [IO.Path]::GetTempFileName(); $se = [IO.Path]::GetTempFileName()
    try {
        # No -Wait: it also waits for descendants, and a revert makes VMware's
        # own processes descendants that never exit.
        $proc = Start-Process -FilePath $Vmrun -ArgumentList $quoted -NoNewWindow -PassThru `
                              -RedirectStandardOutput $so -RedirectStandardError $se
        # Read .Handle now, or .ExitCode is lost once the process exits.
        $null = $proc.Handle
        if (-not $proc.WaitForExit($VmRunTimeoutMs)) {
            try { $proc.Kill() } catch { }
            throw "$What did not finish within $($VmRunTimeoutMs / 60000) minutes; killed it."
        }
        $code = $proc.ExitCode
        $out = (@($so, $se) | ForEach-Object { Get-Content $_ -Raw -ErrorAction SilentlyContinue }) -join "`n"
    } finally { Remove-Item $so, $se -Force -ErrorAction SilentlyContinue }
    if ($null -eq $code) { throw "${What}: exit code lost." }
    if ($code -ne 0 -and -not $AllowFail) { throw "$What failed (exit $code): $($out.Trim())" }
    return @{ Output = $out; ExitCode = $code }
}

function Copy-ToGuest([string]$Local, [string]$Guest) {
    Invoke-VmRun -VmArgs ($guestArgs + @("copyFileFromHostToGuest", $VmxPath, $Local, $Guest)) -What "copy -> $Guest" | Out-Null
}
function Copy-FromGuest([string]$Guest, [string]$Local) {
    return (Invoke-VmRun -VmArgs ($guestArgs + @("copyFileFromGuestToHost", $VmxPath, $Guest, $Local)) -AllowFail).ExitCode -eq 0
}

# Run a generated .cmd in the guest and bring its transcript back. Quoting does
# not survive vmrun + cmd intact, so commands always go through a file.
#
# -Elevated OMITS -interactive, and that is what elevates it: without
# -interactive the program runs in the VMware Tools service context with a full
# admin token; with -interactive it runs in the signed-in user's desktop with a
# filtered (non-elevated) token. The certificate import needs the former; the
# install and the app launch need the latter (AppX deployment needs the user's
# interactive session, otherwise 0x80073D19 "a user was logged off").
function Invoke-GuestScript {
    param([string]$Name, [string]$Body, [switch]$NoWait, [int]$SettleSeconds = 0, [switch]$Elevated)
    $local = Join-Path $runDir "$Name.cmd"; $guest = "$GuestDir\$Name.cmd"
    $gLog = "$GuestDir\$Name.log"; $hLog = Join-Path $runDir "$Name.log"
    @"
@echo off
> "$gLog" 2>&1 (
$Body
)
echo EXITCODE=%ERRORLEVEL%>> "$gLog"
"@ | Set-Content $local -Encoding ASCII
    Copy-ToGuest $local $guest
    $runArgs = $guestArgs + @("runProgramInGuest", $VmxPath)
    if ($NoWait) { $runArgs += "-noWait" }
    if (-not $Elevated) { $runArgs += @("-activeWindow", "-interactive") }
    $runArgs += $guest
    $r = Invoke-VmRun -VmArgs $runArgs -AllowFail -What "runProgramInGuest($Name)"
    if ($SettleSeconds -gt 0) { Start-Sleep -Seconds $SettleSeconds }
    $text = ""
    if (Copy-FromGuest $gLog $hLog) { $text = Get-Content $hLog -Raw -ErrorAction SilentlyContinue }
    # No guest log means the script never ran; vmrun's own message says why
    # (e.g. "guest user does not match the user currently logged in").
    return @{ Text = $text; VmrunExit = $r.ExitCode; VmrunText = $r.Output }
}

function Capture([string]$Name) {
    $png = Join-Path $runDir "$Name.png"
    Invoke-VmRun -VmArgs ($guestArgs + @("captureScreen", $VmxPath, $png)) -AllowFail | Out-Null
    if (Test-Path $png) { Write-Host "    screenshot: $png" }
}

$results = [ordered]@{}
function Check([string]$Name, [bool]$Ok, [string]$Detail) {
    $results[$Name] = @{ Ok = $Ok; Detail = $Detail }
    Write-Host ("    [{0}] {1}  {2}" -f ($(if ($Ok) { "PASS" } else { "FAIL" }), $Name, $Detail))
}
function Revert {
    Invoke-VmRun -VmArgs @("revertToSnapshot", $VmxPath, $SnapshotName) -What "revertToSnapshot" | Out-Null
    # A memory snapshot is already powered on, so `start` failing is fine.
    Invoke-VmRun -VmArgs @("start", $VmxPath) -AllowFail | Out-Null
}

Write-Host "==> Zedu MSIX clean-VM test"
Write-Host "    vm: $VmxPath  snapshot: $SnapshotName"
Write-Host "    msix: $MsixPath ($([math]::Round((Get-Item $MsixPath).Length / 1MB, 1)) MB)"
Write-Host "    evidence: $runDir"

# --- 1. Clean machine ------------------------------------------------------
Write-Host "==> Reverting to '$SnapshotName'"
Revert
# A start right after reverting a running VM can fail while locks are released
# and leave the VM off; check and retry.
for ($try = 1; $try -le 5; $try++) {
    if ((Invoke-VmRun -VmArgs @("list") -AllowFail).Output -match [regex]::Escape($VmxPath)) { break }
    Start-Sleep -Seconds 10
    Invoke-VmRun -VmArgs @("start", $VmxPath) -AllowFail | Out-Null
}
# "Tools running" comes before the guest accepts a login; wait for a real
# authenticated round-trip instead.
Write-Host "==> Waiting for the guest to accept a login"
$deadline = (Get-Date).AddMinutes(5)
do {
    $probe = Invoke-VmRun -VmArgs ($guestArgs + @("directoryExistsInGuest", $VmxPath, "C:\Windows")) -AllowFail
    if ($probe.ExitCode -eq 0) { break }
    Start-Sleep -Seconds 10
} while ((Get-Date) -lt $deadline)
if ($probe.ExitCode -ne 0) { throw "Guest never accepted a login: $($probe.Output.Trim())" }
Invoke-VmRun -VmArgs ($guestArgs + @("createDirectoryInGuest", $VmxPath, $GuestDir)) -AllowFail | Out-Null

try {
    # --- 2. Copy, trust, install -------------------------------------------
    Write-Host "==> Copying the package and certificate"
    Copy-ToGuest $CerPath "$GuestDir\zedu_test.cer"
    Copy-ToGuest $MsixPath "$GuestDir\Zedu.msix"

    Write-Host "==> Trusting the test certificate (elevated)"
    $trust = Invoke-GuestScript -Name "01-trust-cert" -Elevated -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Certificate -FilePath '$GuestDir\zedu_test.cer' -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Format-List Subject,Thumbprint"
"@
    Check "certificate trusted" ($trust.Text -match 'Thumbprint') ""

    Write-Host "==> Installing (interactive session)"
    $install = Invoke-GuestScript -Name "02-install" -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Add-AppxPackage -Path '$GuestDir\Zedu.msix' -ErrorAction Stop; 'INSTALL OK' } catch { 'INSTALL FAILED: ' + `$_.Exception.Message }"
powershell -NoProfile -ExecutionPolicy Bypass -Command "`$p = Get-AppxPackage -Name 'Zedu.Desktop*'; if (`$p) { 'PACKAGE ' + `$p.PackageFullName + ' STATUS ' + `$p.Status } else { 'PACKAGE NOT FOUND' }"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-StartApps | Where-Object { `$_.Name -like 'Zedu*' } | ForEach-Object { 'STARTAPP ' + `$_.Name + ' ' + `$_.AppID }"
"@
    $installed = $install.Text -match 'INSTALL OK' -and $install.Text -match 'PACKAGE Zedu'
    Check "package installs" $installed (($install.Text -split "`r?`n" | Where-Object { $_ -match 'INSTALL|PACKAGE' }) -join '; ')
    Check "Start menu entry" ($install.Text -match 'STARTAPP Zedu') (($install.Text -split "`r?`n" | Where-Object { $_ -match 'STARTAPP' }) -join '; ')

    if ($installed) {
        # --- 3. Launch through the package identity -------------------------
        Write-Host "==> Launching from the Start menu identity, observing $ObserveSeconds s"
        Invoke-GuestScript -Name "03-launch" -NoWait -SettleSeconds $ObserveSeconds -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "`$p = Get-AppxPackage -Name 'Zedu.Desktop*'; `$id = (Get-AppxPackageManifest `$p).Package.Applications.Application.Id; Start-Process ('shell:AppsFolder\' + `$p.PackageFamilyName + '!' + `$id); 'LAUNCHED'"
"@ | Out-Null
        $running = Invoke-GuestScript -Name "03b-running" -Body @"
tasklist /FI "IMAGENAME eq zedu.exe" /FO CSV /NH
"@
        Check "app launches and stays running" ($running.Text -match '"zedu\.exe"') ""
        Capture "03-app-running"

        # --- 4. zedu:// protocol -------------------------------------------
        Write-Host "==> Closing the app, then opening $ProtocolUrl"
        Invoke-GuestScript -Name "04a-close" -Body "taskkill /IM zedu.exe /F" | Out-Null
        Start-Sleep -Seconds 3
        Invoke-GuestScript -Name "04-protocol" -NoWait -SettleSeconds 20 -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '$ProtocolUrl'; 'OPENED'"
"@ | Out-Null
        $proto = Invoke-GuestScript -Name "04b-running" -Body @"
tasklist /FI "IMAGENAME eq zedu.exe" /FO CSV /NH
"@
        Check "zedu:// link starts the app" ($proto.Text -match '"zedu\.exe"') ""
        Capture "04-after-protocol"

        # Crashes show up here even when the window flashed and vanished.
        $events = Invoke-GuestScript -Name "05-app-errors" -Elevated -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue | Where-Object { `$_.Message -match 'zedu.exe' -and `$_.LevelDisplayName -eq 'Error' } | ForEach-Object { 'APPERROR ' + `$_.Id + ' ' + (`$_.Message -split [Environment]::NewLine)[0] }; 'EVENTS DONE'"
"@
        $appErrors = @($events.Text -split "`r?`n" | Where-Object { $_ -match '^APPERROR' })
        Check "no zedu.exe errors in the event log" ($appErrors.Count -eq 0) ($appErrors -join '; ')

        # --- 5. Uninstall -------------------------------------------------
        Write-Host "==> Uninstalling"
        Invoke-GuestScript -Name "06a-close" -Body "taskkill /IM zedu.exe /F" | Out-Null
        $remove = Invoke-GuestScript -Name "06-uninstall" -Body @"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -Name 'Zedu.Desktop*' | Remove-AppxPackage; if (Get-AppxPackage -Name 'Zedu.Desktop*') { 'STILL INSTALLED' } else { 'REMOVED' }"
"@
        Check "uninstall removes the package" ($remove.Text -match 'REMOVED') ""
    }
} finally {
    $summary = Join-Path $runDir "summary.txt"
    $results.GetEnumerator() | ForEach-Object {
        "{0}  {1}  {2}" -f ($(if ($_.Value.Ok) { "PASS" } else { "FAIL" }), $_.Key, $_.Value.Detail)
    } | Set-Content $summary -Encoding UTF8
    if ($NoRevertAfter) { Write-Host "==> Leaving the VM as-is (-NoRevertAfter)." }
    else { Write-Host "==> Reverting to '$SnapshotName'"; Revert }
}

$failed = @($results.Values | Where-Object { -not $_.Ok }).Count
Write-Host ""
Write-Host "==> $($results.Count - $failed) of $($results.Count) checks passed. Evidence: $runDir"
if ($failed) { exit 1 }
