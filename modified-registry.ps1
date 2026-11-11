<#
.SYNOPSIS
    VMware Lab Toolkit (PowerShell) v2.0.1 - Masrul Hadi | Youserroot

.DESCRIPTION
    Menyiapkan Windows agar VMware bisa memakai VT-x / AMD-V (nested virtualization / KVM).

      [1] Cek kesiapan sistem
      [2] Mode Lab    : matikan Hyper-V, VBS, HVCI, Credential Guard, dll
      [3] Mode Normal : kembalikan ke kondisi semula

    Kondisi asli dibackup ke C:\LabMode_Backup\original_state.json sebelum Mode Lab,
    sehingga Mode Normal bisa mengembalikan persis seperti semula.
    Backup lama dari modified-registry.bat (original_state.txt) tetap bisa dibaca.

.PARAMETER Action
    Menu (default) | Check | Lab | Normal

.PARAMETER RestoreMode
    Exact (default) | Default. Hanya dipakai bila -Action Normal.
    Exact   = kembalikan persis kondisi sebelum Mode Lab (butuh backup).
    Default = reset ke default Windows (hapus override), tanpa backup.

.PARAMETER NoRestart
    Jangan tanyakan restart di akhir Mode Lab / Mode Normal.

.PARAMETER Yes
    Non-interaktif: semua prompt konfirmasi dijawab "Ya".
    PERINGATAN: dengan -Yes, skrip TIDAK lagi menanyakan konfirmasi BitLocker
    atau VMware yang sedang berjalan. Pastikan recovery key sudah disimpan.

.PARAMETER ForceReBackup
    Paksa menimpa backup kondisi asli (backup lama di-archive dulu).
    Berguna jika state sistem sudah berubah sejak backup dibuat.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1
    powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1 -Action Check
    powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1 -Action Lab -Yes -NoRestart
    powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1 -Action Normal -RestoreMode Exact

.NOTES
    Perubahan v2.0.1 dibanding v2.0.0:
      [P0] Cek: tidak lagi melaporkan "OK" palsu saat CIM DeviceGuard / ComputerSystem gagal dibaca
      [P0] Save-State mengembalikan status; Mode Lab DIBATALKAN jika backup gagal diverifikasi
      [P0] UEFI unlock: setiap bcdedit /set diperiksa; rollback otomatis jika ada yang gagal
      [P0] Ditambah policy GPO yang hilang: LsaCfgFlags + HVCI\Enabled (dengan PolicyOnly guard)
      [P1] Feature map di-cache per operasi (Check / Lab / Normal = 1x DISM masing-masing)
      [P1] bcd_original dihapus dulu sebelum bcdedit /export (hindari gagal karena file ada)
      [P1] Restore-Exact null-safe: @($state.reg | Where-Object { $_ })
      [P1] Deteksi + bersihkan entry BCD SecConfig (cegah boot loop setelah UEFI unlock)
      [P1] Parser BCD pakai regex yang di-anchor ke nama key (tidak false-match header)
      [P1] Relaunch otomatis ke 64-bit powershell bila skrip dijalankan dari SysWOW64
      [P1] Parameter -Yes / -RestoreMode / -ForceReBackup untuk otomasi
      [P2] No-op dilaporkan sebagai [SKIP], bukan [OK]
      [P2] Kegagalan reg/bcd export dilaporkan (tidak lagi di-void)
      [P2] #Requires -Version 5.1
      [P2] Laporan Windows build + peringatan bila build < 19041
      [P2] Deteksi Secure Boot (INFO di Check, guard di UEFI unlock)
      [P2] Stop vmms / vmcompute / LxssManager sebelum reboot
      [P2] PENTING dicetak sebelum Finish (agar tidak terlewat saat user pilih restart)
      [P2] Restore-Default juga meng-archive backup (agar tidak mengejutkan di run berikutnya)
      [P2] Firewall dibackup per-profil (satu profil gagal tidak menggugurkan semuanya)
      [P2] Backup menyimpan Locked / WasEnabledBy HVCI untuk troubleshooting
      [P2] Log rotation: labmode.log > 1 MB di-rename ke labmode_<stamp>.log
      [P3] Invoke-Native menangani executable yang hilang (WinPE dsb)
      [P3] Prompt tidak membuat infinite loop saat Read-Host mengembalikan $null (EOF)
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Check', 'Lab', 'Normal')]
    [string]$Action = 'Menu',
    [ValidateSet('Exact', 'Default')]
    [string]$RestoreMode = 'Exact',
    [switch]$NoRestart,
    [switch]$Yes,
    [switch]$ForceReBackup,
    [switch]$Relaunched
)

$ErrorActionPreference = 'Continue'
$VER    = '2.0.1'
$AUTHOR = 'Masrul Hadi | Youserroot'
$script:AssumeYes = [bool]$Yes

# =====================================================================
#  ELEVASI ADMINISTRATOR + RELAUNCH KE 64-BIT
# =====================================================================
function Get-64BitPowerShellPath {
    $sysnative = Join-Path $env:WINDIR 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $sysnative) { return $sysnative }
    $sys32 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $sys32) { return $sys32 }
    return (Get-Process -Id $PID).Path
}

$principal  = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin    = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$is32on64   = (-not [Environment]::Is64BitProcess) -and [Environment]::Is64BitOperatingSystem

if (-not $isAdmin -or $is32on64) {
    if (-not $isAdmin) { Write-Host 'Membutuhkan hak Administrator. Meminta izin (UAC)...' -ForegroundColor Yellow }
    if ($is32on64)     { Write-Host 'Relaunch ke PowerShell 64-bit...' -ForegroundColor Yellow }
    if (-not $PSCommandPath) {
        Write-Host 'Jalankan dari file .ps1 (bukan dari paste).' -ForegroundColor Red
        exit 1
    }
    $targetPs = if ($is32on64) { Get-64BitPowerShellPath } else { (Get-Process -Id $PID).Path }
    $argList  = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                  '-Action', $Action, '-RestoreMode', $RestoreMode, '-Relaunched')
    if ($NoRestart)     { $argList += '-NoRestart' }
    if ($Yes)           { $argList += '-Yes' }
    if ($ForceReBackup) { $argList += '-ForceReBackup' }

    $splat = @{ FilePath = $targetPs; ArgumentList = $argList; Wait = $true; ErrorAction = 'Stop' }
    if (-not $isAdmin) { $splat.Verb = 'RunAs' }
    try {
        Start-Process @splat
    } catch {
        Write-Host 'Gagal relaunch (UAC dibatalkan, akun bukan admin, atau path tidak valid).' -ForegroundColor Red
        Write-Host 'Buka PowerShell 64-bit sebagai Administrator, lalu jalankan skrip ini lagi.' -ForegroundColor Red
        exit 1
    }
    exit 0
}

$Host.UI.RawUI.WindowTitle = "VMware Lab Toolkit v$VER - $AUTHOR"

# =====================================================================
#  KONFIGURASI
# =====================================================================
$BK         = "$env:SystemDrive\LabMode_Backup"
$StateFile  = "$BK\original_state.json"
$LegacyFile = "$BK\original_state.txt"      # format lama (modified-registry.bat)
$LogFile    = "$BK\labmode.log"
$LogMaxSize = 1MB

$SEC_GUID = '{0cb3b571-2f2e-4343-a879-d86a476d7215}'

$DG  = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
$LSA = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$POL = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'

# Nilai registry yang diubah Mode Lab (semua diset 0).
# PolicyOnly = $true artinya hanya disentuh jika key policy-nya sudah ada
# (biar kita tidak menambah policy baru yang tidak pernah dipakai mesin ini).
$RegTargets = @(
    @{ Path = $DG;  Name = 'EnableVirtualizationBasedSecurity';       PolicyOnly = $false }
    @{ Path = $DG;  Name = 'RequirePlatformSecurityFeatures';         PolicyOnly = $false }
    @{ Path = "$DG\Scenarios\HypervisorEnforcedCodeIntegrity"; Name = 'Enabled'; PolicyOnly = $false }
    @{ Path = "$DG\Scenarios\CredentialGuard";                 Name = 'Enabled'; PolicyOnly = $false }
    @{ Path = "$DG\Scenarios\SystemGuard";                     Name = 'Enabled'; PolicyOnly = $false }
    @{ Path = $LSA; Name = 'LsaCfgFlags';                             PolicyOnly = $false }
    @{ Path = $POL; Name = 'EnableVirtualizationBasedSecurity';       PolicyOnly = $true }
    @{ Path = $POL; Name = 'LsaCfgFlags';                             PolicyOnly = $true }
    @{ Path = "$POL\HypervisorEnforcedCodeIntegrity"; Name = 'Enabled'; PolicyOnly = $true }
)

$BcdKeys  = @('hypervisorlaunchtype', 'vsmlaunchtype')
$Features = @(
    'Microsoft-Hyper-V-All',
    'VirtualMachinePlatform',
    'HypervisorPlatform',
    'Microsoft-Windows-Subsystem-Linux',
    'Containers-DisposableClientVM',
    'Windows-Defender-ApplicationGuard'
)
$HyperVServices = @('HvHost', 'vmms', 'vmcompute', 'LxssManager')

$script:cOk = 0; $script:cSkip = 0; $script:cFail = 0
$script:rOk = 0; $script:rWarn = 0; $script:rErr = 0

# =====================================================================
#  BANNER
# =====================================================================
$BannerA = @'
         ______  ____    ____    __  __  __          __  __  ______  ____    ______
 /'\_/`\/\  _  \/\  _`\ /\  _`\ /\ \/\ \/\ \        /\ \/\ \/\  _  \/\  _`\ /\__  _\
/\      \ \ \L\ \ \,\L\_\ \ \L\ \ \ \ \ \ \ \       \ \ \_\ \ \ \L\ \ \ \/\ \/_/\ \/
\ \ \__\ \ \  __ \/_\__ \\ \ ,  /\ \ \ \ \ \ \  __   \ \  _  \ \  __ \ \ \ \ \ \ \ \
 \ \ \_/\ \ \ \/\ \/\ \L\ \ \ \\ \\ \ \_\ \ \ \L\ \   \ \ \ \ \ \ \/\ \ \ \_\ \ \_\ \__
  \ \_\\ \_\ \_\ \_\ `\____\ \_\ \_\ \_____\ \____/    \ \_\ \_\ \_\ \_\ \____/ /\_____\
   \/_/ \/_/\/_/\/_/\/_____/\/_/\/ /\/_____/\/___/      \/_/\/_/\/_/\/_/\/___/  \/_____/
'@

$BannerB = @'
 __    __  _____   __  __  ____    ____    ____    ____    _____   _____   ______
/\ \  /\ \/\  __`\/\ \/\ \/\  _`\ /\  _`\ /\  _`\ /\  _`\ /\  __`\/\  __`\/\__  _\
\ `\`\\/'/\ \ \/\ \ \ \ \ \ \,\L\_\ \ \L\_\ \ \L\ \ \ \L\ \ \ \/\ \ \ \/\ \/_/\ \/
 `\ `\ /'  \ \ \ \ \ \ \ \ \/_\__ \\ \  _\L\ \ ,  /\ \ ,  /\ \ \ \ \ \ \ \ \ \ \ \
   `\ \ \   \ \ \_\ \ \ \_\ \/\ \L\ \ \ \L\ \ \ \\ \\ \ \\ \\ \ \_\ \ \ \_\ \ \ \ \
     \ \_\   \ \_____\ \_____\ `\____\ \____/\ \_\ \_\ \_\ \_\ \_____\ \_____\ \ \_\
      \/_/    \/_____/\/_____/\/_____/\/___/  \/_/\/ /\/_/\/ /\/_____/\/_____/  \/_/
'@

function Show-Banner {
    Write-Host ''
    Write-Host $BannerA -ForegroundColor Cyan
    Write-Host ''
    Write-Host $BannerB -ForegroundColor Magenta
    Write-Host ''
    Write-Host "  $AUTHOR" -ForegroundColor Yellow
    Write-Host "  VMware Lab Toolkit v$VER (PowerShell)" -ForegroundColor DarkGray
    Write-Host ''
}

# =====================================================================
#  HELPER UMUM
# =====================================================================
function Say([string]$Text = '', [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Write-Log([string]$Text) {
    try {
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt $LogMaxSize)) {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            try { Move-Item -LiteralPath $LogFile -Destination "$BK\labmode_$stamp.log" -Force -ErrorAction Stop } catch {}
        }
        Add-Content -LiteralPath $LogFile -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text) -ErrorAction Stop
    } catch {}
}

function Section([string]$Title) { Say ''; Say "--- $Title ---" 'Cyan' }

function Ask-YN([string]$Prompt, [bool]$Default = $false) {
    if ($script:AssumeYes) {
        $hint = if ($Default) { 'Y' } else { 'N' }
        Say "$Prompt [$hint] (auto -Yes)" 'DarkGray'
        return $true
    }
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    while ($true) {
        $a = (Read-Host "$Prompt $hint").Trim()
        if ($null -eq $a) { return $Default }   # EOF
        if ($a -eq '')     { return $Default }
        if ($a -match '^[Yy]') { return $true }
        if ($a -match '^[Nn]') { return $false }
    }
}

function Pause-Enter([string]$Text = 'Tekan Enter untuk melanjutkan...') {
    if ($script:AssumeYes) { return }
    [void](Read-Host $Text)
}

function Act([string]$Type, [string]$Msg) {
    switch ($Type) {
        'OK'   { Write-Host "   [OK] $Msg" -ForegroundColor Green;     $script:cOk++ }
        'SKIP' { Write-Host "   [-]  $Msg" -ForegroundColor DarkGray;  $script:cSkip++ }
        'FAIL' { Write-Host "   [X]  $Msg" -ForegroundColor Red;       $script:cFail++ }
    }
    Write-Log "[$Type] $Msg"
}

function Res([string]$Type, [string]$Msg) {
    switch ($Type) {
        'OK'   { Write-Host "   [ OK ]  $Msg" -ForegroundColor Green;  $script:rOk++ }
        'WARN' { Write-Host "   [WARN]  $Msg" -ForegroundColor Yellow; $script:rWarn++ }
        'ERR'  { Write-Host "   [ERR ]  $Msg" -ForegroundColor Red;    $script:rErr++ }
        'INFO' { Write-Host "   [INFO]  $Msg" -ForegroundColor Cyan }
    }
}

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    try {
        $out  = & $Exe @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    } catch {
        Write-Log "Invoke-Native GAGAL menjalankan $Exe : $($_.Exception.Message)"
        return -1
    }
    if ($null -eq $code) { $code = -1 }
    Write-Log ("> $Exe " + ($Arguments -join ' ') + " -> exit $code")
    if ($out.Trim()) { Write-Log $out.Trim() }
    return [int]$code
}

function Reset-Counters { $script:cOk = 0; $script:cSkip = 0; $script:cFail = 0 }

# =====================================================================
#  REGISTRY
# =====================================================================
function Short-Key([string]$Path) {
    return ($Path -replace '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\', '' -replace '^HKLM:\\', '')
}

function Get-RegState([string]$Path, [string]$Name) {
    $o = [ordered]@{ path = $Path; name = $Name; exists = $false; value = $null; kind = $null }
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.GetValueNames() -contains $Name) {
            $o.exists = $true
            $o.value  = $item.GetValue($Name)
            $o.kind   = [string]$item.GetValueKind($Name)
        }
    } catch {}
    return [pscustomobject]$o
}

function Set-RegValue([string]$Path, [string]$Name, $Value, [string]$Kind = 'DWord') {
    $label = (Short-Key $Path) + '\' + $Name
    $cur   = Get-RegState $Path $Name
    if ($cur.exists -and $cur.kind -eq $Kind -and $cur.value -eq $Value) {
        Act 'SKIP' "$label = $Value (sudah sesuai)"
        return
    }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Kind -Force -ErrorAction Stop | Out-Null
        Act 'OK' "$label = $Value"
        Write-Log "REG set $Path\$Name = $Value"
    } catch {
        Act 'FAIL' "Gagal: $label ($($_.Exception.Message))"
    }
}

function Remove-RegValue([string]$Path, [string]$Name, [string]$Why) {
    $label = (Short-Key $Path) + '\' + $Name
    $cur   = Get-RegState $Path $Name
    if (-not $cur.exists) { Act 'SKIP' "${label}: sudah tidak ada"; return }
    try {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        Act 'OK' "${label}: dihapus ($Why)"
    } catch {
        Act 'FAIL' "Gagal menghapus ${label} ($($_.Exception.Message))"
    }
}

# =====================================================================
#  BCD (bcdedit)
# =====================================================================
function Get-BcdAnyValue([string]$Entry, [string]$Name) {
    try {
        $lines = & bcdedit.exe /enum $Entry 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
    } catch { return $null }
    $pattern = '^\s*' + [regex]::Escape($Name) + '\s+(.+?)\s*$'
    foreach ($l in $lines) {
        if ($l -match $pattern) { return $Matches[1] }
    }
    return $null
}

function Get-BcdValue([string]$Name) { return (Get-BcdAnyValue '{current}' $Name) }

function Set-Bcd([string]$Name, [string]$Value) {
    $cur = Get-BcdValue $Name
    if ($cur -and ($cur -ieq $Value)) { Act 'SKIP' "bcdedit $Name sudah = $Value"; return }
    $code = Invoke-Native 'bcdedit.exe' @('/set', $Name, $Value)
    if ($code -eq 0) { Act 'OK' "bcdedit $Name = $Value"; return }
    if ($null -eq $cur) { Act 'SKIP' "bcdedit ${Name}: tidak didukung build Windows ini, dilewati" }
    else                { Act 'FAIL' "Gagal bcdedit $Name" }
}

function Reset-Bcd([string]$Name) {
    if ($null -eq (Get-BcdValue $Name)) { Act 'SKIP' "bcdedit ${Name}: sudah default (tidak diset)"; return }
    if ((Invoke-Native 'bcdedit.exe' @('/deletevalue', $Name)) -eq 0) { Act 'OK' "bcdedit ${Name}: dihapus, kembali ke default" }
    else { Act 'FAIL' "Gagal menghapus bcdedit $Name" }
}

function Test-SecConfigPending {
    try { & bcdedit.exe /enum $SEC_GUID 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
    catch { return $false }
}

function Clear-SecConfigEntry {
    $seq = Get-BcdAnyValue '{bootmgr}' 'bootsequence'
    if ($seq -and ($seq -match [regex]::Escape($SEC_GUID))) {
        [void](Invoke-Native 'bcdedit.exe' @('/deletevalue', '{bootmgr}', 'bootsequence'))
        Act 'OK' 'bootsequence {bootmgr} dibersihkan'
    }
    if (Test-SecConfigPending) {
        if ((Invoke-Native 'bcdedit.exe' @('/delete', $SEC_GUID, '/f')) -eq 0) {
            Act 'OK' "Entry BCD SecConfig ($SEC_GUID) dihapus"
        } else {
            Act 'FAIL' "Gagal menghapus entry BCD SecConfig"
        }
    } else {
        Act 'SKIP' 'Entry BCD SecConfig tidak ada'
    }
}

# =====================================================================
#  FITUR WINDOWS OPSIONAL
# =====================================================================
function Get-FeatureMap {
    $map = @{}
    try {
        Get-WindowsOptionalFeature -Online -ErrorAction Stop | ForEach-Object { $map[$_.FeatureName] = [string]$_.State }
    } catch {
        Say "   [!] Gagal membaca daftar fitur Windows: $($_.Exception.Message)" 'Yellow'
    }
    return $map
}

function Disable-Feat([string]$Name, $Map) {
    $s = $Map[$Name]
    if (-not $s) { Act 'SKIP' "${Name}: tidak tersedia di edisi Windows ini, dilewati"; return }
    if ($s -in @('Disabled', 'DisabledWithPayloadRemoved', 'DisablePending')) { Act 'SKIP' "${Name}: sudah nonaktif"; return }
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Act 'OK' "${Name}: dinonaktifkan"
    } catch {
        Act 'FAIL' "${Name}: gagal ($($_.Exception.Message))"
    }
}

function Enable-Feat([string]$Name, $Map) {
    $s = $Map[$Name]
    if (-not $s) { Act 'SKIP' "${Name}: tidak tersedia di edisi Windows ini, dilewati"; return }
    if ($s -in @('Enabled', 'EnablePending')) { Act 'SKIP' "${Name}: sudah aktif"; return }
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Act 'OK' "${Name}: diaktifkan"
    } catch {
        Act 'FAIL' "${Name}: gagal ($($_.Exception.Message))"
    }
}

# =====================================================================
#  DETEKSI KONDISI SISTEM
# =====================================================================
function Get-BitLockerState {
    $drive = $env:SystemDrive
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $v = Get-BitLockerVolume -MountPoint $drive -ErrorAction Stop
            if ([string]$v.ProtectionStatus -in @('On', '1')) { return 'On' } else { return 'Off' }
        }
    } catch {}
    try {
        $v = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume `
             -Filter "DriveLetter='$drive'" -ErrorAction Stop
        if ($v) { if ($v.ProtectionStatus -eq 1) { return 'On' } else { return 'Off' } }
    } catch {}
    return 'Unknown'
}

function Test-VMwareRunning {
    return [bool](Get-Process -Name 'vmware', 'vmware-vmx' -ErrorAction SilentlyContinue)
}

function Test-VMwareInstalled {
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation',
                     'HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation')) {
        if (Test-Path -LiteralPath $k) { return $true }
    }
    return $false
}

function Test-SecureBoot {
    try {
        $cmd = Get-Command Confirm-SecureBootUEFI -ErrorAction Stop
        return [bool](& $cmd -ErrorAction Stop)
    } catch {
        return $null
    }
}

# =====================================================================
#  BACKUP / RESTORE KONDISI ASLI
# =====================================================================
function Initialize-Backup {
    if (-not (Test-Path -LiteralPath $BK)) { New-Item -ItemType Directory -Path $BK -Force | Out-Null }
}

function Save-State([hashtable]$FeatureMap = $null) {
    if (((Test-Path -LiteralPath $StateFile) -or (Test-Path -LiteralPath $LegacyFile)) -and -not $ForceReBackup) {
        Act 'SKIP' 'Backup kondisi asli sudah ada, dipertahankan'
        return $true
    }
    if ($ForceReBackup -and ((Test-Path -LiteralPath $StateFile) -or (Test-Path -LiteralPath $LegacyFile))) {
        Act 'OK' 'ForceReBackup: backup lama di-archive'
        Archive-State
    }
    if ($null -eq $FeatureMap) { $FeatureMap = Get-FeatureMap }

    $state = [ordered]@{
        version  = 2
        created  = (Get-Date -Format 's')
        computer = $env:COMPUTERNAME
        reg      = @($RegTargets | ForEach-Object { Get-RegState $_.Path $_.Name })
        bcd      = @($BcdKeys    | ForEach-Object { [pscustomobject]@{ name = $_; value = (Get-BcdValue $_) } })
        feat     = @($Features   | ForEach-Object {
            [pscustomobject]@{ name = $_; state = $(if ($FeatureMap[$_]) { $FeatureMap[$_] } else { 'NotFound' }) } })
        firewall = @()
        hvci_meta = [ordered]@{}
    }

    # firewall per-profil (satu profil gagal tidak menggugurkan semua)
    foreach ($name in 'Domain', 'Private', 'Public') {
        try {
            $p = Get-NetFirewallProfile -Name $name -ErrorAction Stop
            $state.firewall += [pscustomobject]@{ profile = $name; enabled = [string]$p.Enabled }
        } catch {
            Write-Log "Gagal baca firewall profile ${name}: $($_.Exception.Message)"
        }
    }

    # metadata HVCI (untuk troubleshooting UEFI lock)
    foreach ($n in 'Locked', 'WasEnabledBy') {
        $s = Get-RegState "$DG\Scenarios\HypervisorEnforcedCodeIntegrity" $n
        if ($s.exists) { $state.hvci_meta[$n] = $s.value }
    }

    try {
        ($state | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $StateFile -Encoding UTF8 -ErrorAction Stop
    } catch {
        Act 'FAIL' "Gagal menulis $StateFile : $($_.Exception.Message)"
        return $false
    }

    # verifikasi round-trip
    try {
        $verify = Get-Content -LiteralPath $StateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if (-not $verify.reg -or -not $verify.bcd) { throw 'Struktur backup tidak lengkap (reg/bcd kosong)' }
    } catch {
        Act 'FAIL' "Verifikasi backup gagal: $($_.Exception.Message)"
        return $false
    }

    Act 'OK' "Kondisi asli disimpan dan diverifikasi di $BK"

    # best-effort export
    if ((Invoke-Native 'reg.exe' @('export',
            'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard',
            "$BK\DeviceGuard_original.reg", '/y')) -ne 0) {
        Act 'SKIP' 'reg export DeviceGuard gagal, dilewati (JSON tetap tersedia)'
    }
    $bcdPath = "$BK\bcd_original"
    Remove-Item -LiteralPath $bcdPath -Force -ErrorAction SilentlyContinue
    if ((Invoke-Native 'bcdedit.exe' @('/export', $bcdPath)) -ne 0) {
        Act 'SKIP' 'bcdedit /export gagal, dilewati (JSON tetap tersedia)'
    }
    return $true
}

function Import-LegacyState([string]$File) {
    $reg = @(); $bcd = @(); $feat = @()
    foreach ($line in (Get-Content -LiteralPath $File)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { continue }
        $p = $line.Split('|')
        switch ($p[0].Trim().ToUpper()) {
            'REG' {
                $path = $p[1] -replace '^HKLM\\', 'HKLM:\'
                if ($p[3] -eq 'ABSENT') {
                    $reg += [pscustomobject]@{ path = $path; name = $p[2]; exists = $false; value = $null; kind = $null }
                } elseif ($p[3] -eq 'REG_DWORD') {
                    $v = if ($p[4] -match '^0x') { [Convert]::ToInt32($p[4], 16) } else { [int]$p[4] }
                    $reg += [pscustomobject]@{ path = $path; name = $p[2]; exists = $true; value = $v; kind = 'DWord' }
                }
            }
            'BCD'  { $bcd  += [pscustomobject]@{ name = $p[1]; value = $(if ($p[2] -eq 'ABSENT') { $null } else { $p[2] }) } }
            'FEAT' { $feat += [pscustomobject]@{ name = $p[1]; state = $p[2] } }
        }
    }
    return [pscustomobject]@{ version = 1; reg = $reg; bcd = $bcd; feat = $feat; firewall = @(); hvci_meta = @{} }
}

function Get-SavedState {
    if (Test-Path -LiteralPath $StateFile) {
        try { return (Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json) }
        catch { Write-Log "JSON backup rusak: $($_.Exception.Message)" }
    }
    if (Test-Path -LiteralPath $LegacyFile) { return (Import-LegacyState $LegacyFile) }
    return $null
}

function Archive-State {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    foreach ($f in @($StateFile, $LegacyFile)) {
        if (Test-Path -LiteralPath $f) {
            $ext = [IO.Path]::GetExtension($f)
            Move-Item -LiteralPath $f -Destination "$BK\restored_$stamp$ext" -Force -ErrorAction SilentlyContinue
        }
    }
}

# =====================================================================
#  AKHIR PROSES
# =====================================================================
function Finish([string]$Reason) {
    Say ''
    Say '===================================================' 'Cyan'
    Say '  HASIL' 'Cyan'
    Say '===================================================' 'Cyan'
    Say "  Berhasil / sudah sesuai : $script:cOk"
    Say "  Dilewati                : $script:cSkip"
    Say "  Gagal                   : $script:cFail" $(if ($script:cFail -gt 0) { 'Red' } else { 'Gray' })
    Say "  Log                     : $LogFile"
    Say "  Dibuat oleh             : $AUTHOR"
    Say '===================================================' 'Cyan'
    if ($script:cFail -gt 0) { Say '  Ada langkah yang gagal, periksa log.' 'Yellow' }
    Say ''
    Say '  Perubahan baru aktif setelah restart. Setelah itu jalankan'
    Say '  menu [1] untuk memverifikasi hasilnya.'
    Say ''
    if ($NoRestart) { Say 'Restart dilewati (-NoRestart). Restart manual nanti.' 'Yellow'; return }
    if (Ask-YN 'Restart sekarang?' $false) {
        [void](Invoke-Native 'shutdown.exe' @('/r', '/t', '30', '/c', $Reason))
        Say 'Restart dalam 30 detik. Batalkan dengan perintah: shutdown /a' 'Yellow'
    } else {
        Say 'Restart ditunda. Silakan restart manual nanti.' 'Yellow'
    }
}

# =====================================================================
#  [1] CEK KESIAPAN
# =====================================================================
function Invoke-Check {
    Clear-Host
    Say '===================================================' 'Cyan'
    Say '  CEK KESIAPAN SISTEM UNTUK VMWARE / KVM' 'Cyan'
    Say '===================================================' 'Cyan'
    Say ''
    Say 'Mengumpulkan data, mohon tunggu...'
    Say ''
    $script:rOk = 0; $script:rWarn = 0; $script:rErr = 0

    # --- OS / build ---
    $osv = [Environment]::OSVersion.Version
    Res 'INFO' "Windows build: $($osv.Build) (v$($osv.Major).$($osv.Minor))"
    if ($osv.Build -lt 19041) {
        Res 'WARN' 'Windows build < 19041; SecConfig.efi / HypervisorPlatform mungkin tidak tersedia'
    }

    # --- CPU / OS arch ---
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($arch -eq 'AMD64') { Res 'OK' 'OS 64-bit AMD64 terdeteksi' }
    else { Res 'ERR' "Dibutuhkan OS 64-bit AMD64, terdeteksi: $arch" }

    # --- Secure Boot ---
    switch (Test-SecureBoot) {
        $true   { Res 'INFO' 'Secure Boot aktif (UEFI)' }
        $false  { Res 'INFO' 'Secure Boot nonaktif (UEFI)' }
        default { Res 'INFO' 'Secure Boot tidak terdeteksi (mungkin Legacy BIOS atau tidak didukung)' }
    }

    $cs  = $null; $cpu = $null; $dg = $null
    try { $cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch {}
    try { $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)[0] } catch {}
    try { $dg  = Get-CimInstance -ClassName Win32_DeviceGuard `
            -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop } catch {}

    if ($cpu) { Res 'INFO' "Prosesor: $($cpu.Name.Trim())" } else { Res 'WARN' 'Data prosesor tidak dapat dibaca (CIM gagal)' }

    # --- Virtualisasi di BIOS / hypervisor ---
    $hvPresent = if ($null -ne $cs)  { [bool]$cs.HypervisorPresent } else { $null }
    $fwEnabled = if ($null -ne $cpu) { [bool]$cpu.VirtualizationFirmwareEnabled } else { $null }

    if ($fwEnabled -eq $true) {
        Res 'OK' 'Virtualisasi aktif di BIOS UEFI'
    } elseif ($hvPresent -eq $true) {
        Res 'WARN' 'Status BIOS tidak terbaca karena hypervisor Windows aktif. Cek ulang setelah Mode Lab'
    } elseif ($fwEnabled -eq $false) {
        Res 'ERR' 'Intel VT-x atau AMD-V nonaktif di BIOS UEFI'
    } else {
        Res 'WARN' 'Status virtualisasi BIOS tidak dapat dibaca'
    }

    if ($hvPresent -eq $true)  { Res 'WARN' 'Hypervisor Windows sedang berjalan' }
    elseif ($hvPresent -eq $false) { Res 'OK' 'Tidak ada hypervisor Windows yang berjalan' }
    else                            { Res 'WARN' 'Status hypervisor Windows tidak dapat dibaca (CIM gagal)' }

    # --- VBS / HVCI / CG (jangan lapor OK palsu jika $dg $null) ---
    if ($null -eq $dg) {
        Res 'WARN' 'Status VBS/HVCI/Credential Guard tidak dapat dibaca (CIM DeviceGuard tidak tersedia)'
    } else {
        switch ([int]$dg.VirtualizationBasedSecurityStatus) {
            2       { Res 'WARN' 'VBS sedang berjalan' }
            1       { Res 'WARN' 'VBS diaktifkan tetapi belum berjalan' }
            default { Res 'OK'   'VBS nonaktif' }
        }
        $svc = if ($dg.SecurityServicesRunning) { @($dg.SecurityServicesRunning) } else { @() }
        if ($svc -contains 2) { Res 'WARN' 'Memory Integrity HVCI berjalan' } else { Res 'OK' 'Memory Integrity HVCI nonaktif' }
        if ($svc -contains 1) { Res 'WARN' 'Credential Guard berjalan' }      else { Res 'OK' 'Credential Guard nonaktif' }
    }

    # --- Fitur Windows ---
    $map = Get-FeatureMap
    foreach ($f in $Features) {
        switch ($map[$f]) {
            'Enabled'       { Res 'WARN' "Fitur aktif: $f" }
            'EnablePending' { Res 'WARN' "Fitur akan aktif setelah restart: $f" }
            { $_ -in @('Disabled', 'DisabledWithPayloadRemoved', 'DisablePending') } { Res 'OK' "Fitur nonaktif: $f" }
            default         { Res 'INFO' "Fitur tidak tersedia di edisi ini: $f" }
        }
    }

    # --- Info tambahan ---
    Say ''
    Say 'Info tambahan:'
    foreach ($k in $BcdKeys) {
        $v = Get-BcdValue $k
        Res 'INFO' ("bcdedit {0,-21} = {1}" -f $k, $(if ($null -ne $v) { $v } else { '(tidak diset)' }))
    }
    if (Test-VMwareInstalled) { Res 'INFO' 'VMware Workstation terdeteksi' }
    else { Res 'INFO' 'VMware Workstation tidak terdeteksi di registry' }

    switch (Get-BitLockerState) {
        'On'      { Res 'WARN' "BitLocker aktif di $env:SystemDrive - backup recovery key sebelum Mode Lab" }
        'Unknown' { Res 'WARN' "Status BitLocker / Device Encryption di $env:SystemDrive tidak bisa dipastikan - anggap aktif dan simpan recovery key" }
        default   { Res 'OK'   "BitLocker tidak aktif di $env:SystemDrive" }
    }

    if (Test-SecConfigPending) {
        Res 'WARN' "Entry BCD SecConfig ($SEC_GUID) masih ada dari UEFI unlock sebelumnya. Jalankan Mode Lab untuk membersihkan"
    }

    Say ''
    Say '===================================================' 'Cyan'
    Say "  OK: $script:rOk    Peringatan: $script:rWarn    Error: $script:rErr" 'Cyan'
    Say '===================================================' 'Cyan'
    if ($script:rErr -gt 0)       { Say '  STATUS: BELUM SIAP. Perbaiki error di atas lebih dulu.' 'Red' }
    elseif ($script:rWarn -gt 0)  { Say '  STATUS: BELUM OPTIMAL. Jalankan Mode Lab lalu restart.' 'Yellow' }
    else                          { Say '  STATUS: SIAP. Nested virtualization bisa dipakai di VMware.' 'Green' }
    Say ''
    Say '  Langkah terakhir di VMware: Settings VM -> Processors ->' 'DarkGray'
    Say '  centang "Virtualize Intel VT-x/EPT or AMD-V/RVI".' 'DarkGray'
    Say ''
}

# =====================================================================
#  [2] MODE LAB
# =====================================================================
function Invoke-UefiUnlock {
    $sec = Join-Path $env:WINDIR 'System32\SecConfig.efi'
    if (-not (Test-Path -LiteralPath $sec)) {
        Act 'FAIL' "SecConfig.efi tidak ditemukan di $env:WINDIR\System32 (build Windows terlalu lama atau edisi khusus). UEFI unlock dilewati"
        return
    }
    if ((Test-SecureBoot) -eq $true -and -not $script:AssumeYes) {
        Say ''
        Say 'Secure Boot aktif. SecConfig.efi umumnya tetap bisa boot, tetapi:' 'Yellow'
        Say ' - Beberapa firmware ketat bisa menolak.' 'Yellow'
        Say ' - Siapkan USB installer Windows sebagai recovery.' 'Yellow'
        if (-not (Ask-YN 'Yakin lanjut UEFI unlock dengan Secure Boot aktif?' $false)) { return }
    }

    $used   = [IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() }
    $letter = @('Z', 'Y', 'X', 'W', 'V') | Where-Object { $used -notcontains $_ } | Select-Object -First 1
    if (-not $letter) { Act 'FAIL' 'Tidak ada huruf drive kosong untuk EFI partition'; return }

    $drv     = "${letter}:"
    $mounted = $false
    try {
        if ((Invoke-Native 'mountvol.exe' @($drv, '/s')) -ne 0) {
            Act 'FAIL' 'Gagal me-mount EFI partition, sistem mungkin bukan UEFI'
            return
        }
        $mounted = $true
        try {
            Copy-Item -LiteralPath $sec -Destination "$drv\EFI\Microsoft\Boot\SecConfig.efi" -Force -ErrorAction Stop
        } catch {
            Act 'FAIL' "Gagal menyalin SecConfig.efi ke EFI partition ($($_.Exception.Message))"
            return
        }

        # bersihkan sisa entry sebelumnya
        [void](Invoke-Native 'bcdedit.exe' @('/delete', $SEC_GUID, '/f'))
        if ((Invoke-Native 'bcdedit.exe' @('/create', $SEC_GUID, '/d', 'DebugTool', '/application', 'osloader')) -ne 0) {
            Act 'FAIL' 'Gagal membuat entry BCD DebugTool'
            return
        }

        # setiap /set diperiksa; kalau ada yang gagal, rollback
        $setsOk = $true
        foreach ($pair in @(
            @('path',        '\EFI\Microsoft\Boot\SecConfig.efi'),
            @('device',      "partition=$drv"),
            @('loadoptions', 'DISABLE-LSA-ISO,DISABLE-VBS')
        )) {
            if ((Invoke-Native 'bcdedit.exe' @('/set', $SEC_GUID, $pair[0], $pair[1])) -ne 0) {
                Act 'FAIL' "bcdedit /set $($pair[0]) gagal, rollback"; $setsOk = $false; break
            }
        }
        if ($setsOk) {
            if ((Invoke-Native 'bcdedit.exe' @('/set', '{bootmgr}', 'bootsequence', $SEC_GUID)) -ne 0) {
                Act 'FAIL' 'bcdedit /set {bootmgr} bootsequence gagal, rollback'; $setsOk = $false
            }
        }
        if (-not $setsOk) {
            [void](Invoke-Native 'bcdedit.exe' @('/delete', $SEC_GUID, '/f'))
            [void](Invoke-Native 'bcdedit.exe' @('/deletevalue', '{bootmgr}', 'bootsequence'))
            return
        }
        Act 'OK' 'Pembukaan kunci UEFI dijadwalkan untuk boot berikutnya'
        Say '       Saat boot berikutnya akan muncul layar yang meminta konfirmasi.' 'Yellow'
        Say '       Ikuti petunjuk di layar tersebut.' 'Yellow'
    } finally {
        if ($mounted) { [void](Invoke-Native 'mountvol.exe' @($drv, '/d')) }
    }
}

function Invoke-Lab {
    Clear-Host
    Say '===================================================' 'Cyan'
    Say '  MODE LAB: NONAKTIFKAN HYPER-V DAN VBS' 'Cyan'
    Say '===================================================' 'Cyan'
    Say ''
    Say 'Yang akan dinonaktifkan:'
    Say ' - Hyper-V, Virtual Machine Platform, Hypervisor Platform'
    Say ' - WSL, Windows Sandbox, Application Guard'
    Say ' - Hypervisor launch dan VSM (bcdedit)'
    Say ' - VBS, Memory Integrity (HVCI), Credential Guard, System Guard'
    Say ''
    Say 'Catatan:'
    Say ' - WSL2, Docker Desktop dan emulator berbasis Hyper-V tidak'
    Say '   akan berfungsi selama Mode Lab.'
    Say " - Kondisi asli disimpan di $BK agar Mode Normal bisa"
    Say '   mengembalikan persis seperti semula.'
    Say ' - Windows Update atau Windows Security bisa mengaktifkan'
    Say '   Memory Integrity lagi. Cek ulang dengan menu [1].'
    Say ' - Pastikan Intel VT-x atau AMD-V aktif di BIOS UEFI.'
    Say ''

    $bl = Get-BitLockerState
    if ($bl -ne 'Off') {
        Say '===================================================' 'Red'
        if ($bl -eq 'On') { Say "  PERINGATAN: BITLOCKER AKTIF DI DRIVE $env:SystemDrive" 'Red' }
        else              { Say "  PERINGATAN: STATUS BITLOCKER / DEVICE ENCRYPTION TIDAK DAPAT DIPASTIKAN" 'Red' }
        Say '===================================================' 'Red'
        Say ''
        Say 'Perubahan boot di Mode Lab bisa memicu BitLocker recovery'
        Say 'prompt saat boot. Jika recovery key tidak tersimpan, laptop'
        Say 'TIDAK BISA DIAKSES.'
        Say ''
        Say 'Sebelum lanjut:'
        Say '  1. Backup recovery key ke akun Microsoft'
        Say "  2. Atau catat/cetak: manage-bde -protectors -get $env:SystemDrive"
        Say ''
        if (-not (Ask-YN 'Recovery key sudah tersimpan? (Y = lanjut, N = batal)' $false)) { return }
        Say ''
    }

    if (Test-VMwareRunning) {
        Say '===================================================' 'Yellow'
        Say '  PERINGATAN: VMWARE WORKSTATION SEDANG BERJALAN' 'Yellow'
        Say '===================================================' 'Yellow'
        Say ''
        Say 'Tutup VMware Workstation dulu (semua VM mati) agar'
        Say 'perubahan bisa diterapkan dengan bersih.'
        Say ''
        if (-not (Ask-YN 'Lanjutkan tanpa menutup VMware?' $false)) { return }
        Say ''
    }

    if (-not (Ask-YN 'Lanjutkan Mode Lab?' $false)) { return }

    Reset-Counters
    Write-Log '===== MODE LAB ====='

    # --- Backup (WAJIB berhasil) ---
    Section 'Menyimpan kondisi asli'
    $map = Get-FeatureMap
    if (-not (Save-State -FeatureMap $map)) {
        Say ''
        Say 'Mode Lab DIBATALKAN: backup kondisi asli gagal dibuat/diverifikasi.' 'Red'
        Say 'Tidak ada perubahan yang dibuat ke sistem.' 'Red'
        return
    }

    # --- Bersihkan sisa SecConfig dari UEFI unlock sebelumnya ---
    if (Test-SecConfigPending) {
        Section 'Bersihkan entry BCD SecConfig dari boot sebelumnya'
        Clear-SecConfigEntry
    }

    # --- Fitur Windows ---
    Section 'Fitur Windows (DISM)'
    foreach ($f in $Features) { Disable-Feat $f $map }

    # --- BCD ---
    Section 'Boot configuration'
    foreach ($k in $BcdKeys) { Set-Bcd $k 'off' }

    # --- Registry ---
    Section 'Registry'
    foreach ($t in $RegTargets) {
        if ($t.PolicyOnly -and -not (Test-Path -LiteralPath $t.Path)) {
            Act 'SKIP' "$(Short-Key $t.Path)\$($t.Name): policy key tidak ada, dilewati"
            continue
        }
        Set-RegValue $t.Path $t.Name 0
    }

    # --- Layanan Hyper-V ---
    Section 'Layanan Hyper-V'
    foreach ($svcName in $HyperVServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc)                    { Act 'SKIP' "${svcName}: service tidak ada"; continue }
        if ($svc.Status -ne 'Running')    { Act 'SKIP' "${svcName}: sudah ${($svc.Status)}"; continue }
        try {
            Stop-Service -Name $svcName -Force -ErrorAction Stop
            Act 'OK' "${svcName}: di-stop (otomatis aktif lagi sesuai konfigurasi)"
        } catch {
            Act 'FAIL' "${svcName}: gagal di-stop ($($_.Exception.Message))"
        }
    }

    Say ''
    Say 'Jika setelah restart VBS atau Credential Guard masih berjalan,'
    Say 'kemungkinan dikunci oleh UEFI lock. Opsi berikut menjadwalkan'
    Say 'pembukaan kunci pada boot berikutnya.'
    Say ''
    if (Ask-YN 'Jadwalkan pembukaan kunci UEFI? (umumnya N)' $false) { Invoke-UefiUnlock }

    # --- PENTING (dipindah ke SEBELUM Finish agar tidak terlewat saat user pilih restart) ---
    Say ''
    Say '===================================================' 'Yellow'
    Say '  PENTING' 'Yellow'
    Say '===================================================' 'Yellow'
    Say '  Mode Lab menurunkan keamanan Windows.'
    Say '  Setelah tugas selesai, jalankan menu [3] Mode Normal'
    Say '  untuk mengembalikan VBS, HVCI, dan Credential Guard.'
    Say ''

    Finish 'Mode Lab: restart untuk menonaktifkan Hyper-V dan VBS'
}

# =====================================================================
#  [3] MODE NORMAL
# =====================================================================
function Restore-Exact($state) {
    Reset-Counters
    Write-Log '===== RESTORE ASLI ====='
    $map = Get-FeatureMap

    Section 'Registry'
    foreach ($r in @($state.reg | Where-Object { $null -ne $_ })) {
        if (-not $r.exists) {
            Remove-RegValue $r.path $r.name 'awalnya tidak ada'
        } else {
            $kind = if ($r.kind) { [string]$r.kind } else { 'DWord' }
            Set-RegValue $r.path $r.name $r.value $kind
        }
    }

    Section 'Boot configuration'
    foreach ($b in @($state.bcd | Where-Object { $null -ne $_ })) {
        if ($null -eq $b.value -or $b.value -eq '') {
            Reset-Bcd $b.name
        } elseif ((Invoke-Native 'bcdedit.exe' @('/set', $b.name, [string]$b.value)) -eq 0) {
            Act 'OK' "bcdedit $($b.name) = $($b.value)"
        } else {
            Act 'FAIL' "Gagal bcdedit $($b.name)"
        }
    }

    Section 'Fitur Windows (DISM)'
    foreach ($f in @($state.feat | Where-Object { $null -ne $_ })) {
        if ($f.state -in @('Enabled', 'EnablePending')) { Enable-Feat $f.name $map }
    }

    $fw = @($state.firewall | Where-Object { $null -ne $_ })
    if ($fw.Count -gt 0) {
        Section 'Windows Firewall (sesuai kondisi asli)'
        foreach ($p in $fw) {
            if ($p.enabled -in @('True', 'False')) {
                try {
                    Set-NetFirewallProfile -Name $p.profile -Enabled $p.enabled -ErrorAction Stop
                    Act 'OK' "Firewall profil $($p.profile) = $($p.enabled)"
                } catch {
                    Act 'FAIL' "Firewall profil $($p.profile): $($_.Exception.Message)"
                }
            }
        }
    } else {
        Say ''
        Say '(Backup tidak memuat status firewall, firewall tidak diubah.)' 'DarkGray'
    }

    Archive-State
    Finish 'Mode Normal: restart untuk menerapkan keamanan Windows'
    Say '  Verifikasi: jalankan menu [1] setelah restart.'
    Say ''
}

function Restore-Default {
    Reset-Counters
    Write-Log '===== RESTORE DEFAULT ====='

    Section 'Boot configuration'
    foreach ($k in $BcdKeys) { Reset-Bcd $k }

    Section 'Registry (hapus override, Windows yang menentukan)'
    foreach ($t in $RegTargets) { Remove-RegValue $t.Path $t.Name 'kembali ke default Windows' }

    Say ''
    if (Ask-YN 'Aktifkan lagi fitur Hyper-V / VM Platform / Hypervisor Platform / WSL (jika tersedia)?' $false) {
        Section 'Fitur Windows (DISM)'
        $map = Get-FeatureMap
        foreach ($f in @('Microsoft-Hyper-V-All', 'VirtualMachinePlatform', 'HypervisorPlatform', 'Microsoft-Windows-Subsystem-Linux')) {
            Enable-Feat $f $map
        }
    }

    Say ''
    if (Ask-YN 'Pastikan Windows Firewall aktif di semua profil?' $true) {
        Section 'Windows Firewall'
        try { Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -ErrorAction Stop; Act 'OK' 'Windows Firewall aktif di semua profil' }
        catch { Act 'FAIL' "Gagal mengaktifkan Windows Firewall ($($_.Exception.Message))" }
    }

    Archive-State
    Finish 'Mode Normal: restart untuk mengaktifkan fitur keamanan Windows'
    Say '  Verifikasi: jalankan menu [1] setelah restart.'
    Say ''
}

function Invoke-NormalInteractive {
    Clear-Host
    Say '===================================================' 'Cyan'
    Say '  MODE NORMAL: KEMBALIKAN KEAMANAN WINDOWS' 'Cyan'
    Say '===================================================' 'Cyan'
    Say ''
    $state = Get-SavedState
    if ($state) {
        $src = if (Test-Path -LiteralPath $StateFile) { $StateFile } else { "$LegacyFile (format lama)" }
        Say 'Backup kondisi asli ditemukan:'
        Say "  $src"
        Say ''
        Say '  [1] Kembalikan PERSIS ke kondisi sebelum Mode Lab (disarankan)'
    } else {
        Say 'Backup kondisi asli tidak ditemukan.'
        Say ''
        Say '  [1] (tidak tersedia)'
    }
    Say '  [2] Reset ke default Windows (hapus override, abaikan backup)'
    Say '  [3] Batal'
    Say ''
    while ($true) {
        $c = (Read-Host 'Pilih [1-3]').Trim()
        if ($null -eq $c -or $c -eq '') { return }
        if ($c -eq '3') { return }
        if ($c -eq '2') { Restore-Default; return }
        if ($c -eq '1') {
            if (-not $state) { Say 'Backup tidak ada, pilih opsi [2] atau batal.' 'Yellow'; continue }
            Restore-Exact $state
            return
        }
    }
}

function Invoke-NormalAction {
    # dipakai untuk -Action Normal (non-interaktif, mode dipilih via -RestoreMode)
    Clear-Host
    Say '===================================================' 'Cyan'
    Say "  MODE NORMAL (non-interaktif, RestoreMode=$RestoreMode)" 'Cyan'
    Say '===================================================' 'Cyan'
    Say ''
    if ($RestoreMode -eq 'Default') { Restore-Default; return }
    $state = Get-SavedState
    if (-not $state) {
        Say 'Backup kondisi asli tidak ditemukan.' 'Red'
        Say 'Gunakan -RestoreMode Default untuk reset ke default Windows.' 'Yellow'
        return
    }
    Restore-Exact $state
}

# =====================================================================
#  MENU UTAMA
# =====================================================================
function Show-Menu {
    while ($true) {
        Clear-Host
        Say '===================================================' 'Cyan'
        Say "          VMWARE LAB TOOLKIT  v$VER" 'Cyan'
        Say '     Nested Virtualization / KVM di VMware' 'Cyan'
        Say '===================================================' 'Cyan'
        Say "          Author : $AUTHOR" 'Yellow'
        Say '===================================================' 'Cyan'
        Say ''
        Say '  [1] Cek kesiapan sistem'
        Say '  [2] MODE LAB    : matikan Hyper-V dan VBS'
        Say '  [3] MODE NORMAL : kembalikan keamanan Windows'
        Say '  [4] Keluar'
        Say ''
        $sel = (Read-Host 'Pilih [1-4]').Trim()
        if ($null -eq $sel) { return }    # EOF
        switch ($sel) {
            '1' { Invoke-Check;  Pause-Enter 'Tekan Enter untuk kembali ke menu...' }
            '2' { Invoke-Lab;    Pause-Enter 'Tekan Enter untuk kembali ke menu...' }
            '3' { Invoke-NormalInteractive; Pause-Enter 'Tekan Enter untuk kembali ke menu...' }
            '4' { return }
        }
    }
}

function Show-Goodbye {
    Clear-Host
    Say ''
    Say '===================================================' 'Cyan'
    Say "  Terima kasih sudah memakai VMware Lab Toolkit v$VER" 'Cyan'
    Say "  Dibuat oleh $AUTHOR" 'Yellow'
    Say '===================================================' 'Cyan'
    Say ''
    Say '  Setelah selesai tugas, jangan lupa jalankan Mode Normal'
    Say '  untuk mengembalikan keamanan Windows Anda.'
    Say ''
    Start-Sleep -Seconds 2
}

# =====================================================================
#  MAIN
# =====================================================================
Initialize-Backup
Write-Log "=== Sesi dimulai (v$VER, Action=$Action, RestoreMode=$RestoreMode, Yes=$Yes, ForceReBackup=$ForceReBackup) ==="
Show-Banner

switch ($Action) {
    'Menu'   { Pause-Enter 'Tekan Enter untuk masuk menu...'; Show-Menu; Show-Goodbye }
    'Check'  { Invoke-Check }
    'Lab'    { Invoke-Lab }
    'Normal' { Invoke-NormalAction }
}

if ($Relaunched -and $Action -ne 'Menu' -and -not $Yes) { Pause-Enter 'Tekan Enter untuk menutup jendela ini...' }
