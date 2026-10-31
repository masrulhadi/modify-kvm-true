@echo off
setlocal enabledelayedexpansion
title Nonaktifkan Hyper-V ^& VBS ^(Mode Lab^)
color 0c

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
echo   MENONAKTIFKAN HYPER-V ^& VBS ^(MODE LAB^)
echo ===================================================
echo.
echo Script ini akan menonaktifkan:
echo  - Hyper-V dan semua komponennya
echo  - Windows Subsystem for Linux ^(WSL^)
echo  - Virtualization-Based Security ^(VBS^)
echo  - Memory Integrity ^(Core Isolation^)
echo  - Credential Guard
echo  - Application Guard
echo.
echo PERINGATAN: Setelah proses selesai, komputer akan restart
echo dalam 30 detik. Simpan semua pekerjaan Anda sekarang!
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
set /a TOTAL_STEPS=13

:: ------------------- DISM OPERATIONS -------------------
echo [1/%TOTAL_STEPS%] Menonaktifkan Hyper-V...
dism.exe /Online /Disable-Feature:Microsoft-Hyper-V-All /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hyper-V dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Hyper-V sudah nonaktif atau gagal dinonaktifkan
    set /a FAILED_COUNT+=1
)

echo.
echo [2/%TOTAL_STEPS%] Menonaktifkan Virtual Machine Platform...
dism.exe /Online /Disable-Feature:VirtualMachinePlatform /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Virtual Machine Platform dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Virtual Machine Platform sudah nonaktif atau gagal
    set /a FAILED_COUNT+=1
)

echo.
echo [3/%TOTAL_STEPS%] Menonaktifkan Windows Subsystem for Linux...
dism.exe /Online /Disable-Feature:Microsoft-Windows-Subsystem-Linux /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] WSL dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] WSL sudah nonaktif atau gagal dinonaktifkan
    set /a FAILED_COUNT+=1
)

echo.
echo [4/%TOTAL_STEPS%] Menonaktifkan Windows Defender Application Guard...
dism.exe /Online /Disable-Feature:Windows-Defender-ApplicationGuard /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Application Guard dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Application Guard sudah nonaktif atau gagal
    set /a FAILED_COUNT+=1
)

echo.
echo [5/%TOTAL_STEPS%] Menonaktifkan Windows Hypervisor Platform...
dism.exe /Online /Disable-Feature:Windows-Hypervisor-Platform /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hypervisor Platform dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Hypervisor Platform sudah nonaktif atau gagal
    set /a FAILED_COUNT+=1
)

:: ------------------- BCDEDIT OPERATION -------------------
echo.
echo [6/%TOTAL_STEPS%] Menonaktifkan Hypervisor Launch Type...
bcdedit /set hypervisorlaunchtype off >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Hypervisor launch type diatur ke OFF
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal mengubah hypervisor launch type
    set /a FAILED_COUNT+=1
)

:: ------------------- REGISTRY OPERATIONS -------------------
echo.
echo [7/%TOTAL_STEPS%] Menonaktifkan Virtualization-Based Security ^(VBS^)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] VBS dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan VBS
    set /a FAILED_COUNT+=1
)

echo.
echo [8/%TOTAL_STEPS%] Menonaktifkan Platform Security Features...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Platform Security Features dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan Platform Security Features
    set /a FAILED_COUNT+=1
)

echo.
echo [9/%TOTAL_STEPS%] Menonaktifkan Hypervisor-Enforced Code Integrity ^(HVCI^)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] HVCI dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan HVCI
    set /a FAILED_COUNT+=1
)

echo.
echo [10/%TOTAL_STEPS%] Menonaktifkan Credential Guard...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Credential Guard dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan Credential Guard
    set /a FAILED_COUNT+=1
)

echo.
echo [11/%TOTAL_STEPS%] Menonaktifkan LSA Configuration Flags...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v LsaCfgFlags /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] LSA Configuration dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan LSA Configuration
    set /a FAILED_COUNT+=1
)

echo.
echo [12/%TOTAL_STEPS%] Menonaktifkan Isolated User Mode...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Isolated User Mode dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [X] Gagal menonaktifkan Isolated User Mode
    set /a FAILED_COUNT+=1
)

echo.
echo [13/%TOTAL_STEPS%] Menonaktifkan Windows Sandbox ^(jika ada^)...
dism.exe /Online /Disable-Feature:Containers-DisposableClientVM /NoRestart >nul 2>&1
if !errorlevel!==0 (
    echo    [OK] Windows Sandbox dinonaktifkan
    set /a SUCCESS_COUNT+=1
) else (
    echo    [!] Windows Sandbox sudah nonaktif atau tidak terinstal
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

if !SUCCESS_COUNT! GEQ 8 (
    echo  STATUS: PROSES BERHASIL
    echo.
    echo  Perubahan yang telah dilakukan:
    echo   ^> Hyper-V dan komponennya dinonaktifkan
    echo   ^> Virtualization-Based Security dinonaktifkan
    echo   ^> Memory Integrity dinonaktifkan
    echo   ^> Credential Guard dinonaktifkan
    echo.
    echo  Komputer akan restart dalam 30 detik untuk menerapkan
    echo  perubahan. Tekan Ctrl+C untuk membatalkan restart.
    echo.
    echo ===================================================
    
    :: Countdown restart
    for /l %%i in (30,-1,1) do (
        <nul set /p "=  Restart dalam %%i detik...  "
        timeout /t 1 >nul
        echo.
    )
    
    echo.
    echo Memulai restart...
    shutdown /r /t 5 /c "Mode Lab: Restart untuk menonaktifkan Hyper-V dan VBS"
) else (
    echo  STATUS: PROSES GAGAL ATAU SEBAGIAN BERHASIL
    echo.
    echo  Beberapa operasi gagal dilakukan.
    echo  Kemungkinan penyebab:
    echo   - Fitur sudah dalam keadaan nonaktif
    echo   - Sistem operasi tidak mendukung fitur tertentu
    echo   - Versi Windows tidak kompatibel
    echo.
    echo  Anda tetap bisa mencoba restart untuk melihat
    echo  apakah perubahan yang berhasil sudah diterapkan.
    echo.
    echo ===================================================
    echo.
    
    choice /c YN /n /m "Restart sekarang? [Y=Ya, N=Tidak]: "
    if errorlevel 2 (
        echo.
        echo Restart dibatalkan. Silakan restart manual nanti.
        echo.
        pause
        exit /b
    ) else (
        echo.
        echo Memulai restart...
        shutdown /r /t 5 /c "Mode Lab: Restart untuk menerapkan perubahan"
    )
)

exit /b