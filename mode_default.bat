@echo off
setlocal enabledelayedexpansion
title Mengaktifkan Kembali Mode Keamanan Windows
color 0a

:: Cek hak administrator
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo ===================================================
    echo   MEMBUTUHKAN HAK ADMINISTRATOR
    echo ===================================================
    echo.
    echo Script ini memerlukan hak administrator.
    echo Meminta izin administrator...
    echo.
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ===================================================
echo     MENGEMBALIKAN SISTEM KE MODE KEAMANAN WINDOWS
echo ===================================================
echo.
echo Script ini akan mengaktifkan kembali:
echo  - Hyper-V dan komponennya
echo  - Windows Subsystem for Linux ^(WSL^)
echo  - Virtualization-Based Security ^(VBS^)
echo  - Memory Integrity ^(Core Isolation^)
echo  - Credential Guard
echo  - Application Guard
echo  - Windows Defender protections
echo  - Windows Firewall ^(semua profil^)
echo.
echo CATATAN: Fitur keamanan ini melindungi sistem Anda dari
echo malware dan serangan. Aktifkan kembali setelah selesai
echo menggunakan GNS3 VM atau software virtualisasi lab.
echo.
echo PERINGATAN: Setelah proses selesai, komputer akan restart
echo otomatis. Simpan semua pekerjaan Anda sekarang!
echo.
echo ===================================================
echo.

choice /c YN /n /m "Lanjutkan? [Y=Ya, N=Tidak]: "
if errorlevel 2 (
    echo.
    echo Operasi dibatalkan oleh pengguna.
    timeout /t 3 >nul
    exit /b
)

echo.
echo ===================================================
echo   PROSES DIMULAI...
echo ===================================================
echo.

set /a SUCCESS_COUNT=0
set /a FAILED_COUNT=0
set /a TOTAL_STEPS=17

:: ------------------- BCDEDIT OPERATION -------------------
echo [1/%TOTAL_STEPS%] Mengaktifkan Hypervisor Launch Type...
bcdedit /set hypervisorlaunchtype auto >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hypervisor launch type diatur ke AUTO
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengubah hypervisor launch type
    set /a FAILED_COUNT+=1
)

:: ------------------- DISM OPERATIONS -------------------
echo.
echo [2/%TOTAL_STEPS%] Mengaktifkan Hyper-V...
dism.exe /Online /Enable-Feature:Microsoft-Hyper-V-All /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hyper-V diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Hyper-V sudah aktif atau gagal diaktifkan
    set /a FAILED_COUNT+=1
)

echo.
echo [3/%TOTAL_STEPS%] Mengaktifkan Virtual Machine Platform...
dism.exe /Online /Enable-Feature:VirtualMachinePlatform /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Virtual Machine Platform diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Virtual Machine Platform sudah aktif atau gagal
    set /a FAILED_COUNT+=1
)

echo.
echo [4/%TOTAL_STEPS%] Mengaktifkan Windows Subsystem for Linux...
dism.exe /Online /Enable-Feature:Microsoft-Windows-Subsystem-Linux /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] WSL diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] WSL sudah aktif atau gagal diaktifkan
    set /a FAILED_COUNT+=1
)

echo.
echo [5/%TOTAL_STEPS%] Mengaktifkan Windows Defender Application Guard...
dism.exe /Online /Enable-Feature:Windows-Defender-ApplicationGuard /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Application Guard diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Application Guard sudah aktif atau tidak tersedia
    set /a FAILED_COUNT+=1
)

echo.
echo [6/%TOTAL_STEPS%] Mengaktifkan Windows Hypervisor Platform...
dism.exe /Online /Enable-Feature:Windows-Hypervisor-Platform /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hypervisor Platform diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Hypervisor Platform sudah aktif atau gagal
    set /a FAILED_COUNT+=1
)

echo.
echo [7/%TOTAL_STEPS%] Mengaktifkan Windows Sandbox...
dism.exe /Online /Enable-Feature:Containers-DisposableClientVM /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Windows Sandbox diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Windows Sandbox sudah aktif atau tidak tersedia
    set /a FAILED_COUNT+=1
)

:: ------------------- REGISTRY OPERATIONS -------------------
echo.
echo [8/%TOTAL_STEPS%] Mengaktifkan Virtualization-Based Security ^(VBS^)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] VBS diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan VBS
    set /a FAILED_COUNT+=1
)

echo.
echo [9/%TOTAL_STEPS%] Mengaktifkan Platform Security Features...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 3 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Platform Security Features diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan Platform Security Features
    set /a FAILED_COUNT+=1
)

echo.
echo [10/%TOTAL_STEPS%] Mengaktifkan Hypervisor-Enforced Code Integrity ^(HVCI^)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] HVCI ^(Memory Integrity^) diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan HVCI
    set /a FAILED_COUNT+=1
)

echo.
echo [11/%TOTAL_STEPS%] Mengaktifkan Credential Guard...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Credential Guard diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan Credential Guard
    set /a FAILED_COUNT+=1
)

echo.
echo [12/%TOTAL_STEPS%] Mengaktifkan LSA Protection...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 1 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] LSA Protection diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan LSA Protection
    set /a FAILED_COUNT+=1
)

echo.
echo [13/%TOTAL_STEPS%] Mengaktifkan Secure Boot State...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v Locked /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Secure Boot State dikonfigurasi
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Gagal mengkonfigurasi Secure Boot State
    set /a FAILED_COUNT+=1
)

:: ------------------- WINDOWS FIREWALL OPERATIONS -------------------
echo.
echo [14/%TOTAL_STEPS%] Mengaktifkan Windows Firewall - Domain Profile...
netsh advfirewall set domainprofile state on >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Firewall Domain Profile diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan Firewall Domain Profile
    set /a FAILED_COUNT+=1
)

echo.
echo [15/%TOTAL_STEPS%] Mengaktifkan Windows Firewall - Private Profile...
netsh advfirewall set privateprofile state on >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Firewall Private Profile diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan Firewall Private Profile
    set /a FAILED_COUNT+=1
)

echo.
echo [16/%TOTAL_STEPS%] Mengaktifkan Windows Firewall - Public Profile...
netsh advfirewall set publicprofile state on >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Firewall Public Profile diaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengaktifkan Firewall Public Profile
    set /a FAILED_COUNT+=1
)

echo.
echo [17/%TOTAL_STEPS%] Mengembalikan konfigurasi Firewall ke default...
netsh advfirewall reset >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Firewall dikembalikan ke pengaturan default
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Gagal mengembalikan konfigurasi Firewall
    set /a FAILED_COUNT+=1
)

:: ------------------- HASIL AKHIR -------------------
echo.
echo ===================================================
echo                 HASIL PROSES
echo ===================================================
echo   Berhasil  : !SUCCESS_COUNT!/%TOTAL_STEPS%
echo   Gagal     : !FAILED_COUNT!/%TOTAL_STEPS%
echo ===================================================
echo.

if !SUCCESS_COUNT! GEQ 10 (
    echo  STATUS: PROSES BERHASIL
    echo.
    echo  Fitur keamanan yang telah diaktifkan:
    echo   ^> Hyper-V dan komponennya
    echo   ^> Virtualization-Based Security ^(VBS^)
    echo   ^> Memory Integrity ^(Core Isolation^)
    echo   ^> Credential Guard
    echo   ^> LSA Protection
    echo   ^> Windows Defender protections
    echo   ^> Windows Firewall ^(semua profil^)
    echo.
    echo  PENTING:
    echo  - Sistem Anda sekarang kembali ke mode keamanan penuh
    echo  - VirtualBox/VMware mungkin tidak bisa berjalan bersamaan
    echo    dengan Hyper-V. Gunakan WSL2 atau Hyper-V untuk virtualisasi
    echo  - Untuk GNS3, gunakan script "Mode Lab" lagi jika diperlukan
    echo.
    echo ===================================================
    echo.
    echo  Komputer akan RESTART OTOMATIS!
    echo  Tekan Ctrl+C SEKARANG untuk membatalkan...
    echo.
    echo ===================================================
    
    :: Countdown restart 30 detik dengan animasi
    for /l %%i in (30,-1,1) do (
        cls
        echo ===================================================
        echo                 HASIL PROSES
        echo ===================================================
        echo   Berhasil  : !SUCCESS_COUNT!/%TOTAL_STEPS%
        echo   Gagal     : !FAILED_COUNT!/%TOTAL_STEPS%
        echo ===================================================
        echo.
        echo  STATUS: PROSES BERHASIL
        echo.
        echo  Fitur keamanan yang telah diaktifkan:
        echo   ^> Hyper-V dan komponennya
        echo   ^> Virtualization-Based Security ^(VBS^)
        echo   ^> Memory Integrity ^(Core Isolation^)
        echo   ^> Credential Guard
        echo   ^> LSA Protection
        echo   ^> Windows Defender protections
        echo   ^> Windows Firewall ^(semua profil^)
        echo.
        echo ===================================================
        echo.
        echo            RESTART DALAM %%i DETIK...
        echo.
        echo         Tekan Ctrl+C untuk membatalkan
        echo.
        echo ===================================================
        timeout /t 1 >nul
    )
    
    :: Countdown final 5 detik dengan efek visual
    cls
    echo.
    echo.
    echo ===================================================
    echo.
    echo           MEMULAI RESTART SISTEM...
    echo.
    echo ===================================================
    echo.
    
    for /l %%i in (5,-1,1) do (
        echo              [%%i] Restart dalam %%i detik...
        timeout /t 1 >nul
    )
    
    echo.
    echo              [0] Restarting now...
    echo.
    echo ===================================================
    
    shutdown /r /t 2 /c "Mode Normal: Restart untuk mengaktifkan fitur keamanan Windows"
) else (
    echo  STATUS: PROSES GAGAL ATAU SEBAGIAN BERHASIL
    echo.
    echo  Beberapa operasi gagal dilakukan.
    echo  Kemungkinan penyebab:
    echo   - Fitur sudah dalam keadaan aktif
    echo   - Hardware tidak mendukung fitur tertentu ^(TPM, Secure Boot^)
    echo   - Versi Windows tidak mendukung semua fitur
    echo   - Edisi Windows ^(Home^) memiliki keterbatasan fitur
    echo.
    echo  CATATAN:
    echo  - Fitur seperti Credential Guard memerlukan TPM 2.0
    echo  - Memory Integrity memerlukan UEFI dan Secure Boot
    echo  - Windows Home tidak mendukung beberapa fitur enterprise
    echo.
    echo  Anda tetap bisa restart untuk menerapkan perubahan
    echo  yang berhasil dilakukan.
    echo.
    echo ===================================================
    echo.
    
    choice /c YN /n /m "Restart sekarang? [Y=Ya, N=Tidak]: "
    if errorlevel 2 (
        echo.
        echo Restart dibatalkan. Silakan restart manual nanti.
        echo.
        echo TIP: Anda juga bisa mengaktifkan Memory Integrity secara
        echo manual melalui: Settings ^> Privacy ^& Security ^> Windows
        echo Security ^> Device Security ^> Core Isolation Details
        echo.
        echo Untuk mengaktifkan Firewall manual:
        echo Control Panel ^> System and Security ^> Windows Defender
        echo Firewall ^> Turn Windows Defender Firewall on or off
        echo.
        pause
        exit /b
    ) else (
        echo.
        echo ===================================================
        echo.
        echo           MEMULAI RESTART SISTEM...
        echo.
        echo ===================================================
        echo.
        
        for /l %%i in (5,-1,1) do (
            echo              [%%i] Restart dalam %%i detik...
            timeout /t 1 >nul
        )
        
        echo.
        echo              [0] Restarting now...
        echo.
        echo ===================================================
        
        shutdown /r /t 2 /c "Mode Normal: Restart untuk menerapkan perubahan keamanan"
    )
)

exit /b