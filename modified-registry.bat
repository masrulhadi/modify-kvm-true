@echo off
setlocal EnableExtensions EnableDelayedExpansion
title VMware Lab Toolkit v1.0.0 - by youserroot ^| simas
color 0B

:: =====================================================
::  VMware Lab Toolkit
::  Author  : youserroot | simas
::  Versi   : 1.0.0
::  Tujuan  : menyiapkan Windows agar VMware bisa menjalankan
::            nested virtualization / KVM
::
::  [1] Cek kesiapan sistem
::  [2] Mode Lab    : matikan Hyper-V, VBS, HVCI, dll
::  [3] Mode Normal : kembalikan ke kondisi semula
:: =====================================================

set "AUTHOR=youserroot | simas"
set "VER=1.0.0"
set "BK=%SystemDrive%\LabMode_Backup"
set "STATE=%BK%\original_state.txt"
set "LOG=%BK%\labmode.log"
set "DG=HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard"
set "LSA=HKLM\SYSTEM\CurrentControlSet\Control\Lsa"
set "POL=HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard"
set "FEATS=Microsoft-Hyper-V-All VirtualMachinePlatform HypervisorPlatform Microsoft-Windows-Subsystem-Linux Containers-DisposableClientVM Windows-Defender-ApplicationGuard"

:: ------------------- CEK ADMINISTRATOR -------------------
fltmc >nul 2>&1
if !errorlevel! neq 0 (
    echo ===================================================
    echo   MEMBUTUHKAN HAK ADMINISTRATOR
    echo ===================================================
    echo Meminta izin administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%BK%" mkdir "%BK%" >nul 2>&1

:: =====================================================
:menu
cls
echo ===================================================
echo           VMWARE LAB TOOLKIT  v!VER!
echo     Nested Virtualization / KVM di VMware
echo ===================================================
echo           Author : !AUTHOR!
echo ===================================================
echo.
echo   [1] Cek kesiapan sistem
echo   [2] MODE LAB    : matikan Hyper-V dan VBS
echo   [3] MODE NORMAL : kembalikan keamanan Windows
echo   [4] Keluar
echo.
choice /c 1234 /n /m "Pilih [1-4]: "
if errorlevel 4 goto :bye
if errorlevel 3 goto :restore
if errorlevel 2 goto :lab
goto :check

:: =====================================================
::  [1] CEK KESIAPAN
:: =====================================================
:check
cls
echo ===================================================
echo   CEK KESIAPAN SISTEM UNTUK VMWARE / KVM
echo ===================================================
echo.
echo Mengumpulkan data, mohon tunggu...
echo.
set /a OKC=0
set /a WARNC=0
set /a ERRC=0
set "ST_HV=" & set "ST_FW=" & set "ST_VBS=" & set "ST_CG=" & set "ST_HVCI="

for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command "$cs=Get-CimInstance Win32_ComputerSystem; $cp=@(Get-CimInstance Win32_Processor)[0]; 'HV=' + $cs.HypervisorPresent; 'FW=' + $cp.VirtualizationFirmwareEnabled; try{$dg=Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop; 'VBS=' + $dg.VirtualizationBasedSecurityStatus; 'CG=' + ($dg.SecurityServicesRunning -contains 1); 'HVCI=' + ($dg.SecurityServicesRunning -contains 2)}catch{'VBS=0'; 'CG=False'; 'HVCI=False'}"`) do set "ST_%%A=%%B"

set "ARCH=%PROCESSOR_ARCHITEW6432%"
if not defined ARCH set "ARCH=%PROCESSOR_ARCHITECTURE%"
if /i "!ARCH!"=="AMD64" (
    call :res OK "OS 64-bit AMD64 terdeteksi"
) else (
    call :res ERR "Dibutuhkan OS 64-bit AMD64, terdeteksi: !ARCH!"
)

if /i "!ST_FW!"=="True" (
    call :res OK "Virtualisasi aktif di BIOS UEFI"
) else if /i "!ST_HV!"=="True" (
    call :res WARN "Status BIOS tidak terbaca karena hypervisor Windows aktif. Cek ulang setelah Mode Lab"
) else (
    call :res ERR "Intel VT-x atau AMD-V nonaktif di BIOS UEFI"
)

if /i "!ST_HV!"=="True" (
    call :res WARN "Hypervisor Windows sedang berjalan"
) else (
    call :res OK "Tidak ada hypervisor Windows yang berjalan"
)

if "!ST_VBS!"=="2" (
    call :res WARN "VBS sedang berjalan"
) else if "!ST_VBS!"=="1" (
    call :res WARN "VBS diaktifkan tetapi belum berjalan"
) else (
    call :res OK "VBS nonaktif"
)

if /i "!ST_HVCI!"=="True" (
    call :res WARN "Memory Integrity HVCI berjalan"
) else (
    call :res OK "Memory Integrity HVCI nonaktif"
)

if /i "!ST_CG!"=="True" (
    call :res WARN "Credential Guard berjalan"
) else (
    call :res OK "Credential Guard nonaktif"
)

for %%F in (%FEATS%) do call :chkfeat %%F

echo.
echo Info tambahan:
bcdedit /enum {current} 2>nul | findstr /i "hypervisorlaunchtype vsmlaunchtype"
reg query "HKLM\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation" >nul 2>&1
if !errorlevel!==0 (
    call :res INFO "VMware Workstation terdeteksi"
) else (
    call :res INFO "VMware Workstation tidak terdeteksi di registry"
)

echo.
echo ===================================================
echo   OK: !OKC!    Peringatan: !WARNC!    Error: !ERRC!
echo ===================================================
if !ERRC! gtr 0 (
    echo   STATUS: BELUM SIAP. Perbaiki error di atas lebih dulu.
) else if !WARNC! gtr 0 (
    echo   STATUS: BELUM OPTIMAL. Jalankan Mode Lab lalu restart.
) else (
    echo   STATUS: SIAP. Nested virtualization bisa dipakai di VMware.
)
echo.
pause
goto :menu

:: =====================================================
::  [2] MODE LAB
:: =====================================================
:lab
cls
echo ===================================================
echo   MODE LAB: NONAKTIFKAN HYPER-V DAN VBS
echo ===================================================
echo.
echo Yang akan dinonaktifkan:
echo  - Hyper-V, Virtual Machine Platform, Hypervisor Platform
echo  - WSL, Windows Sandbox, Application Guard
echo  - Hypervisor launch dan VSM ^(bcdedit^)
echo  - VBS, Memory Integrity ^(HVCI^), Credential Guard, System Guard
echo.
echo Catatan:
echo  - WSL2, Docker Desktop dan emulator berbasis Hyper-V tidak
echo    akan berfungsi selama Mode Lab.
echo  - Kondisi asli disimpan di %BK% agar Mode Normal bisa
echo    mengembalikan persis seperti semula.
echo  - Windows Update atau Windows Security bisa mengaktifkan
echo    Memory Integrity lagi. Cek ulang dengan menu [1].
echo  - Pastikan Intel VT-x atau AMD-V aktif di BIOS UEFI.
echo.
choice /c YN /n /m "Lanjutkan? [Y=Ya, N=Tidak]: "
if errorlevel 2 goto :menu

set /a OKC=0
set /a SKIPC=0
set /a FAILC=0
echo ===== MODE LAB %date% %time% ===== >> "%LOG%"

echo.
echo --- Menyimpan kondisi asli ---
call :savestate

echo.
echo --- Fitur Windows ^(DISM^) ---
for %%F in (%FEATS%) do call :feature %%F

echo.
echo --- Boot configuration ---
call :bcdset hypervisorlaunchtype off
call :bcdset vsmlaunchtype off

echo.
echo --- Registry ---
call :regdword "%DG%" EnableVirtualizationBasedSecurity 0
call :regdword "%DG%" RequirePlatformSecurityFeatures 0
call :regdword "%DG%\Scenarios\HypervisorEnforcedCodeIntegrity" Enabled 0
call :regdword "%DG%\Scenarios\CredentialGuard" Enabled 0
call :regdword "%DG%\Scenarios\SystemGuard" Enabled 0
call :regdword "%LSA%" LsaCfgFlags 0

:: Group Policy menimpa nilai registry biasa, matikan juga jika ada
reg query "%POL%" >nul 2>&1
if !errorlevel!==0 call :regdword "%POL%" EnableVirtualizationBasedSecurity 0

echo.
echo Jika setelah restart VBS atau Credential Guard masih berjalan,
echo kemungkinan dikunci oleh UEFI lock. Opsi berikut menjadwalkan
echo pembukaan kunci pada boot berikutnya.
echo.
choice /c YN /n /m "Jadwalkan pembukaan kunci UEFI? [Y/N, umumnya N]: "
if errorlevel 2 goto :lab_done
call :uefi_unlock

:lab_done
call :finish "Mode Lab: restart untuk menonaktifkan Hyper-V dan VBS"
goto :menu

:: =====================================================
::  [3] MODE NORMAL
:: =====================================================
:restore
cls
echo ===================================================
echo   MODE NORMAL: KEMBALIKAN KEAMANAN WINDOWS
echo ===================================================
echo.
if exist "%STATE%" (
    echo Backup kondisi asli ditemukan:
    echo   %STATE%
    echo.
    echo   [1] Kembalikan PERSIS ke kondisi sebelum Mode Lab ^(disarankan^)
) else (
    echo Backup kondisi asli tidak ditemukan.
    echo.
    echo   [1] ^(tidak tersedia^)
)
echo   [2] Aktifkan fitur default Windows ^(abaikan backup^)
echo   [3] Batal
echo.
choice /c 123 /n /m "Pilih [1-3]: "
if errorlevel 3 goto :menu
if errorlevel 2 goto :restore_default
if not exist "%STATE%" (
    echo.
    echo Backup tidak ada, pilih opsi [2] atau batal.
    pause
    goto :restore
)

:restore_exact
set /a OKC=0
set /a SKIPC=0
set /a FAILC=0
echo ===== RESTORE ASLI %date% %time% ===== >> "%LOG%"
echo.
echo --- Mengembalikan kondisi asli ---
for /f "usebackq tokens=1-5 delims=| eol=#" %%A in ("%STATE%") do (
    if /i "%%A"=="REG"  call :rest_reg "%%B" "%%C" "%%D" "%%E"
    if /i "%%A"=="BCD"  call :rest_bcd "%%B" "%%C"
    if /i "%%A"=="FEAT" call :rest_feat "%%B" "%%C"
)
echo.
echo --- Windows Firewall ---
call :firewall

for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%T"
move /y "%STATE%" "%BK%\restored_%STAMP%.txt" >nul 2>&1
call :finish "Mode Normal: restart untuk menerapkan keamanan Windows"
goto :menu

:restore_default
set /a OKC=0
set /a SKIPC=0
set /a FAILC=0
echo ===== RESTORE DEFAULT %date% %time% ===== >> "%LOG%"
echo.
echo --- Boot configuration ---
call :bcdset hypervisorlaunchtype auto
call :bcdset vsmlaunchtype auto
echo.
echo --- Fitur Windows ^(DISM^) ---
for %%F in (Microsoft-Hyper-V-All VirtualMachinePlatform HypervisorPlatform Microsoft-Windows-Subsystem-Linux) do call :featen %%F
echo.
echo --- Registry ---
call :regdword "%DG%" EnableVirtualizationBasedSecurity 1
call :regdword "%DG%" RequirePlatformSecurityFeatures 1
call :regdword "%DG%\Scenarios\HypervisorEnforcedCodeIntegrity" Enabled 1
echo.
echo --- Windows Firewall ---
call :firewall
call :finish "Mode Normal: restart untuk mengaktifkan fitur keamanan Windows"
goto :menu

:: =====================================================
::  SUBROUTINE
:: =====================================================

:: :res <OK|WARN|ERR|INFO> "<teks tanpa tanda kurung atau simbol khusus>"
:res
if /i "%~1"=="OK"   echo    [ OK ]  %~2
if /i "%~1"=="OK"   set /a OKC+=1
if /i "%~1"=="WARN" echo    [WARN]  %~2
if /i "%~1"=="WARN" set /a WARNC+=1
if /i "%~1"=="ERR"  echo    [ERR ]  %~2
if /i "%~1"=="ERR"  set /a ERRC+=1
if /i "%~1"=="INFO" echo    [INFO]  %~2
exit /b 0

:: :getfeat <NamaFitur>  -> F_STATE (tidak bergantung bahasa Windows)
:getfeat
set "F_STATE=NotFound"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "try{(Get-WindowsOptionalFeature -Online -FeatureName '%~1' -ErrorAction Stop).State}catch{'NotFound'}"`) do set "F_STATE=%%S"
exit /b 0

:chkfeat
call :getfeat %~1
if /i "!F_STATE!"=="Enabled"       call :res WARN "Fitur aktif: %~1"
if /i "!F_STATE!"=="EnablePending" call :res WARN "Fitur akan aktif setelah restart: %~1"
if /i "!F_STATE!"=="Disabled"      call :res OK "Fitur nonaktif: %~1"
if /i "!F_STATE!"=="DisabledWithPayloadRemoved" call :res OK "Fitur nonaktif: %~1"
exit /b 0

:: Nonaktifkan fitur hanya jika perlu. DISM 3010 = sukses, butuh restart.
:feature
call :getfeat %~1
if /i "!F_STATE!"=="NotFound" (
    echo    [-] %~1: tidak tersedia di edisi Windows ini, dilewati
    set /a SKIPC+=1
    exit /b 0
)
if /i "!F_STATE!"=="Disabled" (
    echo    [OK] %~1: sudah nonaktif
    set /a OKC+=1
    exit /b 0
)
if /i "!F_STATE!"=="DisabledWithPayloadRemoved" (
    echo    [OK] %~1: sudah nonaktif
    set /a OKC+=1
    exit /b 0
)
dism.exe /Online /Disable-Feature /FeatureName:%~1 /NoRestart >> "%LOG%" 2>&1
set "RC=!errorlevel!"
set "RESULT=FAIL"
if "!RC!"=="0" set "RESULT=OK"
if "!RC!"=="3010" set "RESULT=OK"
if "!RESULT!"=="OK" (
    echo    [OK] %~1: dinonaktifkan
    set /a OKC+=1
) else (
    echo    [X] %~1: gagal, kode !RC!
    set /a FAILC+=1
)
exit /b 0

:: Aktifkan fitur hanya jika perlu.
:featen
call :getfeat %~1
if /i "!F_STATE!"=="NotFound" (
    echo    [-] %~1: tidak tersedia di edisi Windows ini, dilewati
    set /a SKIPC+=1
    exit /b 0
)
if /i "!F_STATE!"=="Enabled" (
    echo    [OK] %~1: sudah aktif
    set /a OKC+=1
    exit /b 0
)
dism.exe /Online /Enable-Feature /FeatureName:%~1 /All /NoRestart >> "%LOG%" 2>&1
set "RC=!errorlevel!"
set "RESULT=FAIL"
if "!RC!"=="0" set "RESULT=OK"
if "!RC!"=="3010" set "RESULT=OK"
if "!RESULT!"=="OK" (
    echo    [OK] %~1: diaktifkan
    set /a OKC+=1
) else (
    echo    [X] %~1: gagal, kode !RC!
    set /a FAILC+=1
)
exit /b 0

:: :bcdset <nama> <nilai>
:bcdset
bcdedit /set %~1 %~2 >> "%LOG%" 2>&1
if !errorlevel!==0 (
    echo    [OK] bcdedit %~1 = %~2
    set /a OKC+=1
) else (
    echo    [X] Gagal bcdedit %~1
    set /a FAILC+=1
)
exit /b 0

:: :regdword "<key>" <nama> <nilai>
:regdword
set "K=%~1"
set "K=!K:HKLM\SYSTEM\CurrentControlSet\Control\=!"
reg add "%~1" /v %~2 /t REG_DWORD /d %~3 /f >> "%LOG%" 2>&1
if !errorlevel!==0 (
    echo    [OK] !K!\%~2 = %~3
    set /a OKC+=1
) else (
    echo    [X] Gagal: !K!\%~2
    set /a FAILC+=1
)
exit /b 0

:firewall
netsh advfirewall set allprofiles state on >> "%LOG%" 2>&1
if !errorlevel!==0 (
    echo    [OK] Windows Firewall aktif di semua profil
    set /a OKC+=1
) else (
    echo    [X] Gagal mengaktifkan Windows Firewall
    set /a FAILC+=1
)
exit /b 0

:: ------------------- BACKUP KONDISI ASLI -------------------
:: Hanya dibuat sekali, supaya menjalankan Mode Lab dua kali tidak
:: menimpa kondisi asli dengan kondisi yang sudah dimatikan.
:savestate
if exist "%STATE%" (
    echo    Backup kondisi asli sudah ada, dipertahankan.
    exit /b 0
)
> "%STATE%" echo # Kondisi asli sebelum Mode Lab - %date% %time%
call :savereg "%DG%" EnableVirtualizationBasedSecurity
call :savereg "%DG%" RequirePlatformSecurityFeatures
call :savereg "%DG%\Scenarios\HypervisorEnforcedCodeIntegrity" Enabled
call :savereg "%DG%\Scenarios\CredentialGuard" Enabled
call :savereg "%DG%\Scenarios\SystemGuard" Enabled
call :savereg "%LSA%" LsaCfgFlags
call :savereg "%POL%" EnableVirtualizationBasedSecurity
call :savebcd hypervisorlaunchtype
call :savebcd vsmlaunchtype
for %%F in (%FEATS%) do call :savefeat %%F
reg export "%DG%" "%BK%\DeviceGuard_original.reg" /y >nul 2>&1
bcdedit /export "%BK%\bcd_original" >nul 2>&1
echo    [OK] Kondisi asli disimpan di %BK%
exit /b 0

:savereg
set "S_TYPE="
set "S_DATA="
for /f "tokens=1,2,*" %%A in ('reg query "%~1" /v %~2 2^>nul') do (
    if /i "%%A"=="%~2" (
        set "S_TYPE=%%B"
        set "S_DATA=%%C"
    )
)
if defined S_TYPE (
    >> "%STATE%" echo REG^|%~1^|%~2^|!S_TYPE!^|!S_DATA!
) else (
    >> "%STATE%" echo REG^|%~1^|%~2^|ABSENT^|0
)
exit /b 0

:savebcd
set "B_VAL="
for /f "tokens=1,2" %%A in ('bcdedit /enum {current} 2^>nul') do (
    if /i "%%A"=="%~1" set "B_VAL=%%B"
)
if defined B_VAL (
    >> "%STATE%" echo BCD^|%~1^|!B_VAL!
) else (
    >> "%STATE%" echo BCD^|%~1^|ABSENT
)
exit /b 0

:savefeat
call :getfeat %~1
>> "%STATE%" echo FEAT^|%~1^|!F_STATE!
exit /b 0

:: ------------------- RESTORE DARI BACKUP -------------------
:: :rest_reg "<key>" "<nama>" "<tipe>" "<data>"
:rest_reg
set "K=%~1"
set "K=!K:HKLM\SYSTEM\CurrentControlSet\Control\=!"
if /i "%~3"=="ABSENT" (
    reg delete "%~1" /v %~2 /f >> "%LOG%" 2>&1
    echo    [OK] !K!\%~2: dihapus, awalnya tidak ada
    set /a OKC+=1
) else (
    reg add "%~1" /v %~2 /t %~3 /d %~4 /f >> "%LOG%" 2>&1
    if !errorlevel!==0 (
        echo    [OK] !K!\%~2 = %~4
        set /a OKC+=1
    ) else (
        echo    [X] Gagal mengembalikan !K!\%~2
        set /a FAILC+=1
    )
)
exit /b 0

:rest_bcd
if /i "%~2"=="ABSENT" (
    bcdedit /deletevalue %~1 >> "%LOG%" 2>&1
    echo    [OK] bcdedit %~1: dihapus, kembali ke default
    set /a OKC+=1
) else (
    bcdedit /set %~1 %~2 >> "%LOG%" 2>&1
    if !errorlevel!==0 (
        echo    [OK] bcdedit %~1 = %~2
        set /a OKC+=1
    ) else (
        echo    [X] Gagal bcdedit %~1
        set /a FAILC+=1
    )
)
exit /b 0

:rest_feat
if /i "%~2"=="Enabled"       call :featen %~1
if /i "%~2"=="EnablePending" call :featen %~1
exit /b 0

:: ------------------- PEMBUKAAN KUNCI UEFI -------------------
:: Prosedur resmi Microsoft untuk VBS atau Credential Guard yang
:: dikunci UEFI. Saat boot berikutnya akan muncul prompt di layar,
:: ikuti instruksinya untuk mengonfirmasi.
:uefi_unlock
set "DRV="
for %%L in (Z Y X W V) do if not defined DRV if not exist %%L:\ set "DRV=%%L:"
if not defined DRV (
    echo    [X] Tidak ada huruf drive kosong untuk EFI partition
    set /a FAILC+=1
    exit /b 1
)
set "GUID={0cb3b571-2f2e-4343-a879-d86a476d7215}"
mountvol %DRV% /s >> "%LOG%" 2>&1
if !errorlevel! neq 0 (
    echo    [X] Gagal me-mount EFI partition, sistem mungkin bukan UEFI
    set /a FAILC+=1
    exit /b 1
)
copy "%WINDIR%\System32\SecConfig.efi" "%DRV%\EFI\Microsoft\Boot\SecConfig.efi" /Y >> "%LOG%" 2>&1
bcdedit /create %GUID% /d "DebugTool" /application osloader >> "%LOG%" 2>&1
bcdedit /set %GUID% path "\EFI\Microsoft\Boot\SecConfig.efi" >> "%LOG%" 2>&1
bcdedit /set {bootmgr} bootsequence %GUID% >> "%LOG%" 2>&1
bcdedit /set %GUID% loadoptions DISABLE-LSA-ISO,DISABLE-VBS >> "%LOG%" 2>&1
bcdedit /set %GUID% device partition=%DRV% >> "%LOG%" 2>&1
mountvol %DRV% /d >> "%LOG%" 2>&1
echo    [OK] Pembukaan kunci UEFI dijadwalkan untuk boot berikutnya
exit /b 0

:: ------------------- RINGKASAN DAN RESTART -------------------
:finish
echo.
echo ===================================================
echo   HASIL
echo ===================================================
echo   Berhasil / sudah sesuai : !OKC!
echo   Dilewati                : !SKIPC!
echo   Gagal                   : !FAILC!
echo   Log                     : %LOG%
echo   Dibuat oleh             : !AUTHOR!
echo ===================================================
if !FAILC! gtr 0 echo   Ada langkah yang gagal, periksa log.
echo.
echo   Perubahan baru aktif setelah restart. Setelah itu jalankan
echo   menu [1] untuk memverifikasi hasilnya.
echo.
choice /c YN /n /m "Restart sekarang? [Y=Ya, N=Tidak]: "
if errorlevel 2 (
    echo.
    echo Restart ditunda. Silakan restart manual nanti.
    pause
    exit /b 0
)
echo.
echo Restart dalam 30 detik. Batalkan dengan perintah: shutdown /a
shutdown /r /t 30 /c "%~1"
pause
exit /b 0

:: ------------------- KELUAR -------------------
:bye
cls
echo.
echo ===================================================
echo   Terima kasih sudah memakai VMware Lab Toolkit v!VER!
echo   Dibuat oleh !AUTHOR!
echo ===================================================
echo.
timeout /t 3 >nul
exit /b
