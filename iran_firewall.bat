@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════
::  IRAN-ONLY FIREWALL FOR PSIPHON CONDUIT v2.0.0
::  
::  Standalone batch file - NO Python required!
::  Maximizes bandwidth for Iranian users during internet shutdowns.
::  
::  USAGE: Right-click → Run as Administrator
::  
::  This script ONLY affects conduit-tunnel-core.exe
::  Your PC, browsing, and other apps work normally.
:: ═══════════════════════════════════════════════════════════════════════════

set "VERSION=2.0.0"
set "RULE_PREFIX=IranConduit"
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%conduit_config.txt"
set "LOG_FILE=%SCRIPT_DIR%firewall.log"
set "TEMP_IPV4=%TEMP%\iran_ipv4.txt"
set "TEMP_IPV6=%TEMP%\iran_ipv6.txt"
set "CONDUIT_URL=https://conduit.psiphon.ca/"

:: Colors
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "MAGENTA=[95m"
set "CYAN=[96m"
set "WHITE=[97m"
set "RESET=[0m"

:: ═══════════════════════════════════════════════════════════════════════════
:: AUTO-ELEVATE TO ADMINISTRATOR
:: ═══════════════════════════════════════════════════════════════════════════
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Change to script directory
cd /d "%SCRIPT_DIR%"

:: Initialize log
echo [%date% %time%] === Iran Firewall v%VERSION% started === >> "%LOG_FILE%"

goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: MAIN MENU
:: ═══════════════════════════════════════════════════════════════════════════
:MAIN_MENU
cls
echo.
echo %CYAN%╔═══════════════════════════════════════════════════════════════════╗%RESET%
echo %CYAN%║%WHITE%       IRAN-ONLY FIREWALL FOR PSIPHON CONDUIT v%VERSION%        %CYAN%║%RESET%
echo %CYAN%╠═══════════════════════════════════════════════════════════════════╣%RESET%
echo %CYAN%║%RESET%  Maximize bandwidth for Iranian users during internet shutdowns  %CYAN%║%RESET%
echo %CYAN%║%RESET%  %GREEN%[STANDALONE - No Python Required]%RESET%                              %CYAN%║%RESET%
echo %CYAN%╚═══════════════════════════════════════════════════════════════════╝%RESET%
echo.
echo %WHITE%─────────────────────────────────────────────────────────────────────%RESET%
echo   %GREEN%1.%RESET% Enable Iran-only mode %CYAN%(Normal)%RESET%
echo   %YELLOW%2.%RESET% Enable Iran-only mode %MAGENTA%(Strict)%RESET%
echo   %RED%3.%RESET% Disable Iran-only mode
echo   %BLUE%4.%RESET% Check status
echo   %CYAN%5.%RESET% Conduit management
echo   %WHITE%6.%RESET% Help
echo   %RED%0.%RESET% Exit
echo %WHITE%─────────────────────────────────────────────────────────────────────%RESET%
echo   %CYAN%Normal:%RESET% TCP global, UDP Iran-only
echo   %MAGENTA%Strict:%RESET% TCP+UDP Iran-only (may affect visibility)
echo %WHITE%─────────────────────────────────────────────────────────────────────%RESET%
echo.
set /p "CHOICE=  Enter choice (0-6): "

if "%CHOICE%"=="1" goto :ENABLE_NORMAL
if "%CHOICE%"=="2" goto :ENABLE_STRICT
if "%CHOICE%"=="3" goto :DISABLE
if "%CHOICE%"=="4" goto :STATUS
if "%CHOICE%"=="5" goto :CONDUIT_MENU
if "%CHOICE%"=="6" goto :HELP
if "%CHOICE%"=="0" goto :EXIT
goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: ENABLE IRAN-ONLY MODE (NORMAL)
:: ═══════════════════════════════════════════════════════════════════════════
:ENABLE_NORMAL
set "STRICT_MODE=0"
goto :ENABLE_COMMON

:ENABLE_STRICT
echo.
echo %YELLOW%  WARNING: Strict mode restricts TCP to Iran only.%RESET%
echo %YELLOW%  This may prevent Psiphon brokers from seeing your node.%RESET%
echo.
set /p "CONFIRM=  Continue? (y/n): "
if /i not "%CONFIRM%"=="y" goto :MAIN_MENU
set "STRICT_MODE=1"
goto :ENABLE_COMMON

:ENABLE_COMMON
cls
echo.
echo %CYAN%══════════════════════════════════════════════════════════════%RESET%
if "%STRICT_MODE%"=="1" (
    echo %MAGENTA%  ENABLING IRAN-ONLY MODE [STRICT]%RESET%
) else (
    echo %GREEN%  ENABLING IRAN-ONLY MODE [NORMAL]%RESET%
)
echo %CYAN%══════════════════════════════════════════════════════════════%RESET%
echo.

:: Step 1: Verify Firewall
echo %YELLOW%[1/7] Verifying Windows Firewall...%RESET%
call :VERIFY_FIREWALL
if %errorlevel% neq 0 (
    echo %RED%  Cannot proceed without Windows Firewall enabled%RESET%
    pause
    goto :MAIN_MENU
)

:: Step 2: Check Conduit Running
echo.
echo %YELLOW%[2/7] Checking Conduit status...%RESET%
call :IS_CONDUIT_RUNNING
if %errorlevel% equ 0 (
    echo %GREEN%  Conduit is running%RESET%
) else (
    echo %WHITE%  Conduit is NOT running%RESET%
    set /p "START_CONDUIT=  Start Conduit first? (y/n/0=back): "
    if /i "!START_CONDUIT!"=="0" goto :MAIN_MENU
    if /i "!START_CONDUIT!"=="y" call :START_CONDUIT
)

:: Step 3: Find Conduit
echo.
echo %YELLOW%[3/7] Locating Conduit executable...%RESET%
call :FIND_CONDUIT
if not defined CONDUIT_PATH (
    echo %RED%  Could not find Conduit. Please ensure it's installed.%RESET%
    pause
    goto :MAIN_MENU
)
echo %GREEN%  Found: %CONDUIT_PATH%%RESET%

:: Step 4: Download IPs
echo.
echo %YELLOW%[4/7] Downloading Iran IP ranges...%RESET%
call :DOWNLOAD_IPS
if %errorlevel% neq 0 (
    echo %RED%  Failed to download IP ranges%RESET%
    pause
    goto :MAIN_MENU
)

:: Step 5: Remove old rules
echo.
echo %YELLOW%[5/7] Removing existing rules...%RESET%
call :REMOVE_ALL_RULES
echo %GREEN%  Old rules removed%RESET%

:: Step 6: Create new rules
echo.
echo %YELLOW%[6/7] Creating firewall rules...%RESET%
call :CREATE_RULES

:: Step 7: Verify
echo.
echo %YELLOW%[7/7] Verifying rules...%RESET%
call :VERIFY_RULES

:: Save config
echo %CONDUIT_PATH%> "%CONFIG_FILE%"
echo [%date% %time%] Iran-only mode enabled. Strict=%STRICT_MODE% >> "%LOG_FILE%"

echo.
echo %GREEN%══════════════════════════════════════════════════════════════%RESET%
echo %GREEN%  IRAN-ONLY MODE ENABLED!%RESET%
echo %GREEN%══════════════════════════════════════════════════════════════%RESET%
echo.
echo %WHITE%  Your PC is NOT affected - only Conduit!%RESET%
echo %CYAN%  Only Iranian users can now use your data tunnel!%RESET%
echo.
pause
goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: DISABLE IRAN-ONLY MODE
:: ═══════════════════════════════════════════════════════════════════════════
:DISABLE
cls
echo.
echo %RED%  Disabling Iran-only mode...%RESET%
echo.

call :REMOVE_ALL_RULES

:: Restore default allow rule for Conduit
if exist "%CONFIG_FILE%" (
    set /p CONDUIT_PATH=<"%CONFIG_FILE%"
    if defined CONDUIT_PATH (
        echo   Restoring default allow rule...
        powershell -NoProfile -Command ^
            "New-NetFirewallRule -DisplayName 'Psiphon Conduit (Restored)' -Description 'Restored by IranFirewall' -Direction Inbound -Action Allow -Enabled True -Program '!CONDUIT_PATH!' -ErrorAction SilentlyContinue" >nul 2>&1
    )
)

echo [%date% %time%] Iran-only mode disabled >> "%LOG_FILE%"
echo.
echo %GREEN%  Iran-only mode DISABLED%RESET%
echo %WHITE%  Conduit now accepts connections from all countries.%RESET%
echo.
pause
goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: STATUS
:: ═══════════════════════════════════════════════════════════════════════════
:STATUS
cls
echo.
echo %CYAN%══════════════════════════════════════════════════════════════%RESET%
echo %CYAN%  CURRENT STATUS%RESET%
echo %CYAN%══════════════════════════════════════════════════════════════%RESET%
echo.

:: Check firewall
echo %WHITE%  Windows Firewall:%RESET%
powershell -NoProfile -Command ^
    "$profiles = Get-NetFirewallProfile -All; $allEnabled = $true; foreach ($p in $profiles) { if (-not $p.Enabled) { $allEnabled = $false } }; if ($allEnabled) { Write-Host '    ENABLED' -ForegroundColor Green } else { Write-Host '    WARNING: May be disabled' -ForegroundColor Yellow }"

:: Check our rules
echo.
echo %WHITE%  Iran Firewall Rules:%RESET%
powershell -NoProfile -Command ^
    "$rules = Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -ErrorAction SilentlyContinue; if ($rules) { $allow = ($rules | Where-Object { $_.Action -eq 'Allow' }).Count; $block = ($rules | Where-Object { $_.Action -eq 'Block' }).Count; Write-Host ('    IRAN-ONLY MODE ENABLED') -ForegroundColor Green; Write-Host ('    Total rules: ' + $rules.Count); Write-Host ('    Allow rules: ' + $allow); Write-Host ('    Block rules: ' + $block) } else { Write-Host '    IRAN-ONLY MODE DISABLED' -ForegroundColor Red }"

:: Check Conduit
echo.
echo %WHITE%  Psiphon Conduit:%RESET%
call :IS_CONDUIT_RUNNING
if %errorlevel% equ 0 (
    echo %GREEN%    Running%RESET%
) else (
    echo %WHITE%    Not running%RESET%
)

:: Show saved path
echo.
echo %WHITE%  Saved Conduit Path:%RESET%
if exist "%CONFIG_FILE%" (
    type "%CONFIG_FILE%"
) else (
    echo     Not configured
)

echo.
pause
goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: CONDUIT MENU
:: ═══════════════════════════════════════════════════════════════════════════
:CONDUIT_MENU
cls
echo.
echo %CYAN%─────────────────────────────────────────────────────────────────────%RESET%
echo %CYAN%  CONDUIT MANAGEMENT%RESET%
echo %CYAN%─────────────────────────────────────────────────────────────────────%RESET%
echo   %GREEN%1.%RESET% Start Conduit
echo   %RED%2.%RESET% Stop Conduit
echo   %BLUE%3.%RESET% Check if running
echo   %CYAN%4.%RESET% Open Conduit website
echo   %WHITE%5.%RESET% Show Conduit path
echo   %RED%0.%RESET% Back to main menu
echo %CYAN%─────────────────────────────────────────────────────────────────────%RESET%
echo.
set /p "CONDUIT_CHOICE=  Enter choice: "

if "%CONDUIT_CHOICE%"=="1" (
    call :START_CONDUIT
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="2" (
    echo   Stopping Conduit...
    taskkill /IM "conduit-tunnel-core.exe" /F >nul 2>&1
    timeout /t 1 >nul
    echo %GREEN%  Conduit stopped%RESET%
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="3" (
    call :IS_CONDUIT_RUNNING
    if %errorlevel% equ 0 (
        echo %GREEN%  Conduit is RUNNING%RESET%
    ) else (
        echo %WHITE%  Conduit is NOT running%RESET%
    )
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="4" (
    echo   Opening %CONDUIT_URL%
    start "" "%CONDUIT_URL%"
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="5" (
    echo.
    if exist "%CONFIG_FILE%" (
        echo   Saved path:
        type "%CONFIG_FILE%"
    ) else (
        echo   Not configured yet
    )
    echo.
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="0" goto :MAIN_MENU
goto :CONDUIT_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: HELP
:: ═══════════════════════════════════════════════════════════════════════════
:HELP
cls
echo.
echo %CYAN%╔═══════════════════════════════════════════════════════════════════╗%RESET%
echo %CYAN%║                    HELP - Iran-Only Firewall v%VERSION%              ║%RESET%
echo %CYAN%╚═══════════════════════════════════════════════════════════════════╝%RESET%
echo.
echo %WHITE%  WHAT THIS DOES:%RESET%
echo   - Creates firewall rules that ONLY allow Iranian IPs to use your
echo     Psiphon Conduit bandwidth for data transfer (UDP).
echo   - Allows TCP globally so Psiphon brokers can see your node is active.
echo   - Uses EXPLICIT block rules - doesn't rely on Windows defaults.
echo.
echo %WHITE%  HOW IT WORKS (Rule Priority):%RESET%
echo   1. ALLOW DNS servers (required for operation)
echo   2. ALLOW TCP globally (for Psiphon broker checks)
echo   3. ALLOW UDP from Iran IP ranges (IPv4 + IPv6)
echo   4. BLOCK all other UDP (explicit rule)
echo.
echo %WHITE%  MODES:%RESET%
echo   %GREEN%Normal Mode:%RESET% TCP global, UDP Iran-only
echo     Best for: Most users (ensures broker visibility)
echo.
echo   %MAGENTA%Strict Mode:%RESET% TCP Iran-only, UDP Iran-only
echo     Best for: Maximum restriction (may affect broker visibility)
echo.
echo %WHITE%  REQUIREMENTS:%RESET%
echo   - Windows 10/11
echo   - Run as Administrator
echo   - Windows Firewall enabled
echo.
echo %WHITE%  TROUBLESHOOTING:%RESET%
echo   - "Access denied" - Right-click, Run as Administrator
echo   - "Conduit not found" - Make sure Conduit is running first
echo   - Check %LOG_FILE% for logs
echo.
pause
goto :MAIN_MENU

:: ═══════════════════════════════════════════════════════════════════════════
:: EXIT
:: ═══════════════════════════════════════════════════════════════════════════
:EXIT
cls
echo.
echo %GREEN%  Thank you for helping Iran!%RESET%
echo %WHITE%  Share this tool to help more people.%RESET%
echo.
echo [%date% %time%] === Iran Firewall exited === >> "%LOG_FILE%"
timeout /t 2 >nul
exit /b 0

:: ═══════════════════════════════════════════════════════════════════════════
:: HELPER FUNCTIONS
:: ═══════════════════════════════════════════════════════════════════════════

:VERIFY_FIREWALL
powershell -NoProfile -Command ^
    "$profiles = Get-NetFirewallProfile -All; $allEnabled = $true; foreach ($p in $profiles) { if (-not $p.Enabled) { $allEnabled = $false } }; if ($allEnabled) { exit 0 } else { exit 1 }"
if %errorlevel% equ 0 (
    echo %GREEN%  Windows Firewall is ENABLED%RESET%
    exit /b 0
) else (
    echo %YELLOW%  WARNING: Windows Firewall may be disabled!%RESET%
    set /p "ENABLE_FW=  Enable Windows Firewall now? (y/n): "
    if /i "!ENABLE_FW!"=="y" (
        powershell -NoProfile -Command "Set-NetFirewallProfile -All -Enabled True"
        echo %GREEN%  Firewall enabled%RESET%
        exit /b 0
    )
    exit /b 1
)

:IS_CONDUIT_RUNNING
tasklist /FI "IMAGENAME eq conduit-tunnel-core.exe" 2>nul | find /i "conduit-tunnel-core.exe" >nul
exit /b %errorlevel%

:START_CONDUIT
echo   Starting Conduit...
if exist "%CONFIG_FILE%" (
    set /p CONDUIT_PATH=<"%CONFIG_FILE%"
    if exist "!CONDUIT_PATH!" (
        start "" "!CONDUIT_PATH!"
        timeout /t 2 >nul
        call :IS_CONDUIT_RUNNING
        if %errorlevel% equ 0 (
            echo %GREEN%  Conduit started successfully!%RESET%
        ) else (
            echo %YELLOW%  Conduit may not have started. Check manually.%RESET%
        )
        exit /b 0
    )
)
echo %RED%  Conduit path not found. Run Enable first to locate it.%RESET%
exit /b 1

:FIND_CONDUIT
set "CONDUIT_PATH="

:: Check saved config
if exist "%CONFIG_FILE%" (
    set /p SAVED_PATH=<"%CONFIG_FILE%"
    if exist "!SAVED_PATH!" (
        set "CONDUIT_PATH=!SAVED_PATH!"
        exit /b 0
    )
)

:: Method 1: Check running process
echo   Checking running processes...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-Process -Name 'conduit-tunnel-core' -ErrorAction SilentlyContinue).Path"') do (
    if exist "%%a" (
        set "CONDUIT_PATH=%%a"
        echo %GREEN%  Found from running process%RESET%
        exit /b 0
    )
)

:: Method 2: Check UWP apps
echo   Checking Windows Store apps...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-AppxPackage -Name '*Conduit*' -ErrorAction SilentlyContinue).InstallLocation"') do (
    if exist "%%a\conduit-tunnel-core.exe" (
        set "CONDUIT_PATH=%%a\conduit-tunnel-core.exe"
        echo %GREEN%  Found UWP app%RESET%
        exit /b 0
    )
)

:: Method 3: Common locations
echo   Checking common locations...
for %%D in ("%LOCALAPPDATA%" "%APPDATA%" "%USERPROFILE%\Downloads" "%PROGRAMFILES%") do (
    if exist "%%~D" (
        for /f "tokens=*" %%F in ('dir /s /b "%%~D\conduit-tunnel-core.exe" 2^>nul') do (
            set "CONDUIT_PATH=%%F"
            echo %GREEN%  Found in %%~D%RESET%
            exit /b 0
        )
    )
)

:: Manual entry
echo.
echo %YELLOW%  Could not find Conduit automatically.%RESET%
echo   TIP: Make sure Conduit is running, then try again.
echo.
echo   0. Back to main menu
set /p "MANUAL_PATH=  Enter full path to conduit-tunnel-core.exe (or 0): "
if "%MANUAL_PATH%"=="0" exit /b 1
if exist "%MANUAL_PATH%" (
    set "CONDUIT_PATH=%MANUAL_PATH%"
    exit /b 0
)
exit /b 1

:DOWNLOAD_IPS
:: Clear temp files
del "%TEMP_IPV4%" 2>nul
del "%TEMP_IPV6%" 2>nul

:: Download IPv4
echo.
echo   %WHITE%Downloading IPv4 ranges...%RESET%

:: Source 1: ipdeny.com
echo   Fetching ipdeny.com...
powershell -NoProfile -Command ^
    "try { $ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri 'https://www.ipdeny.com/ipblocks/data/countries/ir.zone' -TimeoutSec 30 -UseBasicParsing).Content | Out-File -Encoding ASCII '%TEMP_IPV4%' -Append; Write-Host '    OK' -ForegroundColor Green } catch { Write-Host '    Failed' -ForegroundColor Yellow }"

:: Source 2: herrbischoff GitHub
echo   Fetching herrbischoff/country-ip-blocks...
powershell -NoProfile -Command ^
    "try { $ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/ir.cidr' -TimeoutSec 30 -UseBasicParsing).Content | Out-File -Encoding ASCII '%TEMP_IPV4%' -Append; Write-Host '    OK' -ForegroundColor Green } catch { Write-Host '    Failed' -ForegroundColor Yellow }"

:: Check if we got IPv4
if not exist "%TEMP_IPV4%" (
    echo %RED%  All IPv4 downloads failed!%RESET%
    exit /b 1
)

:: Count IPv4
for /f %%a in ('type "%TEMP_IPV4%" ^| find /c "/"') do set "IPV4_COUNT=%%a"
if "%IPV4_COUNT%"=="0" (
    echo %RED%  No IPv4 ranges downloaded!%RESET%
    exit /b 1
)
echo %GREEN%  IPv4: %IPV4_COUNT% ranges%RESET%

:: Download IPv6
echo.
echo   %WHITE%Downloading IPv6 ranges...%RESET%

:: Source 1: ipdeny.com IPv6
echo   Fetching ipdeny.com IPv6...
powershell -NoProfile -Command ^
    "try { $ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri 'https://www.ipdeny.com/ipv6/ipaddresses/blocks/ir.zone' -TimeoutSec 30 -UseBasicParsing).Content | Out-File -Encoding ASCII '%TEMP_IPV6%' -Append; Write-Host '    OK' -ForegroundColor Green } catch { Write-Host '    Failed' -ForegroundColor Yellow }"

:: Source 2: herrbischoff IPv6
echo   Fetching herrbischoff IPv6...
powershell -NoProfile -Command ^
    "try { $ProgressPreference='SilentlyContinue'; (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv6/ir.cidr' -TimeoutSec 30 -UseBasicParsing).Content | Out-File -Encoding ASCII '%TEMP_IPV6%' -Append; Write-Host '    OK' -ForegroundColor Green } catch { Write-Host '    Failed' -ForegroundColor Yellow }"

:: Count IPv6
set "IPV6_COUNT=0"
if exist "%TEMP_IPV6%" (
    for /f %%a in ('type "%TEMP_IPV6%" ^| find /c ":"') do set "IPV6_COUNT=%%a"
)
echo %GREEN%  IPv6: %IPV6_COUNT% ranges%RESET%

echo.
echo %GREEN%  Total: %IPV4_COUNT% IPv4 + %IPV6_COUNT% IPv6 ranges downloaded%RESET%
exit /b 0

:REMOVE_ALL_RULES
powershell -NoProfile -Command ^
    "Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue"
timeout /t 1 >nul
exit /b 0

:CREATE_RULES
set "FAILED_RULES=0"

:: ─────────────────────────────────────────────────────────────────
:: DNS RULES
:: ─────────────────────────────────────────────────────────────────
echo.
echo   %CYAN%Creating DNS rules...%RESET%

:: DNS IPv4
powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-UDP' -Description 'Allow DNS UDP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -RemoteAddress '8.8.8.8,8.8.4.4,1.1.1.1,1.0.0.1,9.9.9.9,149.112.112.112,208.67.222.222,208.67.220.220,4.2.2.1,4.2.2.2,178.22.122.100,185.51.200.2,10.202.10.202,10.202.10.102' -ErrorAction SilentlyContinue" >nul 2>&1

powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-TCP' -Description 'Allow DNS TCP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -RemoteAddress '8.8.8.8,8.8.4.4,1.1.1.1,1.0.0.1,9.9.9.9,149.112.112.112,208.67.222.222,208.67.220.220,4.2.2.1,4.2.2.2,178.22.122.100,185.51.200.2,10.202.10.202,10.202.10.102' -ErrorAction SilentlyContinue" >nul 2>&1

:: DNS IPv6
powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-UDP-v6' -Description 'Allow DNS UDP IPv6 - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -RemoteAddress '2001:4860:4860::8888,2001:4860:4860::8844,2606:4700:4700::1111,2606:4700:4700::1001,2620:fe::fe,2620:fe::9' -ErrorAction SilentlyContinue" >nul 2>&1

powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-TCP-v6' -Description 'Allow DNS TCP IPv6 - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -RemoteAddress '2001:4860:4860::8888,2001:4860:4860::8844,2606:4700:4700::1111,2606:4700:4700::1001,2620:fe::fe,2620:fe::9' -ErrorAction SilentlyContinue" >nul 2>&1

echo %GREEN%    DNS rules created%RESET%

:: ─────────────────────────────────────────────────────────────────
:: TCP RULES
:: ─────────────────────────────────────────────────────────────────
echo.
echo   %CYAN%Creating TCP rules...%RESET%

if "%STRICT_MODE%"=="0" (
    :: Normal mode: TCP global
    powershell -NoProfile -Command ^
        "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-TCP-Global' -Description 'Allow Global TCP for Broker - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -ErrorAction SilentlyContinue" >nul 2>&1
    echo %GREEN%    TCP: Global (for broker visibility)%RESET%
) else (
    echo %MAGENTA%    TCP: Will be restricted to Iran only (strict mode)%RESET%
)

:: ─────────────────────────────────────────────────────────────────
:: IRAN IPv4 UDP RULES
:: ─────────────────────────────────────────────────────────────────
echo.
echo   %CYAN%Creating Iran IPv4 rules...%RESET%

:: Process IPv4 in batches using PowerShell
powershell -NoProfile -Command ^
    "$ips = Get-Content '%TEMP_IPV4%' | Where-Object { $_ -match '/' -and $_ -notmatch ':' -and $_ -notmatch '#' } | Select-Object -Unique; ^
    $batchSize = 200; ^
    $total = $ips.Count; ^
    $batchNum = 0; ^
    for ($i = 0; $i -lt $total; $i += $batchSize) { ^
        $batch = $ips[$i..([Math]::Min($i + $batchSize - 1, $total - 1))]; ^
        $ipList = $batch -join ','; ^
        $pct = [Math]::Min(100, [int](($i + $batchSize) / $total * 100)); ^
        Write-Host \"`r    Progress: $pct%% ($([Math]::Min($i + $batchSize, $total))/$total)\" -NoNewline; ^
        New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-UDP-v4-$batchNum' -Description 'Allow Iran IPv4 UDP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $ipList -Protocol UDP -ErrorAction SilentlyContinue | Out-Null; ^
        if ('%STRICT_MODE%' -eq '1') { ^
            New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-TCP-v4-$batchNum' -Description 'Allow Iran IPv4 TCP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $ipList -Protocol TCP -ErrorAction SilentlyContinue | Out-Null; ^
        } ^
        $batchNum++; ^
    }; ^
    Write-Host ''; ^
    Write-Host '    IPv4 rules created' -ForegroundColor Green"

:: ─────────────────────────────────────────────────────────────────
:: IRAN IPv6 UDP RULES
:: ─────────────────────────────────────────────────────────────────
if exist "%TEMP_IPV6%" (
    echo.
    echo   %CYAN%Creating Iran IPv6 rules...%RESET%
    
    powershell -NoProfile -Command ^
        "$ips = Get-Content '%TEMP_IPV6%' | Where-Object { $_ -match ':' -and $_ -match '/' -and $_ -notmatch '#' } | Select-Object -Unique; ^
        if ($ips.Count -gt 0) { ^
            $batchSize = 200; ^
            $total = $ips.Count; ^
            $batchNum = 0; ^
            for ($i = 0; $i -lt $total; $i += $batchSize) { ^
                $batch = $ips[$i..([Math]::Min($i + $batchSize - 1, $total - 1))]; ^
                $ipList = $batch -join ','; ^
                $pct = [Math]::Min(100, [int](($i + $batchSize) / $total * 100)); ^
                Write-Host \"`r    Progress: $pct%% ($([Math]::Min($i + $batchSize, $total))/$total)\" -NoNewline; ^
                New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-UDP-v6-$batchNum' -Description 'Allow Iran IPv6 UDP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $ipList -Protocol UDP -ErrorAction SilentlyContinue | Out-Null; ^
                if ('%STRICT_MODE%' -eq '1') { ^
                    New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-TCP-v6-$batchNum' -Description 'Allow Iran IPv6 TCP - IranFirewall v%VERSION%' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $ipList -Protocol TCP -ErrorAction SilentlyContinue | Out-Null; ^
                } ^
                $batchNum++; ^
            }; ^
            Write-Host ''; ^
            Write-Host '    IPv6 rules created' -ForegroundColor Green ^
        } else { ^
            Write-Host '    No IPv6 ranges to process' -ForegroundColor Yellow ^
        }"
) else (
    echo   %YELLOW%No IPv6 ranges available, skipping...%RESET%
)

:: ─────────────────────────────────────────────────────────────────
:: EXPLICIT BLOCK RULES (CRITICAL!)
:: ─────────────────────────────────────────────────────────────────
echo.
echo   %RED%Creating BLOCK rules (security)...%RESET%

:: Block all UDP not matched by allow rules
powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-UDP-All' -Description 'Block all non-Iran UDP - IranFirewall v%VERSION%' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -ErrorAction SilentlyContinue" >nul 2>&1
echo %GREEN%    UDP block rule created%RESET%

:: Block IPv6 UDP
powershell -NoProfile -Command ^
    "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-UDP-v6-All' -Description 'Block all non-Iran IPv6 UDP - IranFirewall v%VERSION%' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -ErrorAction SilentlyContinue" >nul 2>&1
echo %GREEN%    IPv6 UDP block rule created%RESET%

:: In strict mode, also block TCP
if "%STRICT_MODE%"=="1" (
    powershell -NoProfile -Command ^
        "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-TCP-All' -Description 'Block all non-Iran TCP - IranFirewall v%VERSION%' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -ErrorAction SilentlyContinue" >nul 2>&1
    echo %GREEN%    TCP block rule created (strict mode)%RESET%
    
    powershell -NoProfile -Command ^
        "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-TCP-v6-All' -Description 'Block all non-Iran IPv6 TCP - IranFirewall v%VERSION%' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -ErrorAction SilentlyContinue" >nul 2>&1
    echo %GREEN%    IPv6 TCP block rule created (strict mode)%RESET%
)

exit /b 0

:VERIFY_RULES
powershell -NoProfile -Command ^
    "$rules = Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -ErrorAction SilentlyContinue; ^
    $total = $rules.Count; ^
    $allow = ($rules | Where-Object { $_.Action -eq 'Allow' }).Count; ^
    $block = ($rules | Where-Object { $_.Action -eq 'Block' }).Count; ^
    Write-Host ('  Total rules created: ' + $total) -ForegroundColor Green; ^
    Write-Host ('  Allow rules: ' + $allow); ^
    Write-Host ('  Block rules: ' + $block); ^
    if ($block -gt 0) { Write-Host '  Explicit block rules in place' -ForegroundColor Green } else { Write-Host '  WARNING: No block rules!' -ForegroundColor Red }"
exit /b 0
