@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ========================================================================
::  IRAN-ONLY FIREWALL FOR PSIPHON CONDUIT v2.0.0
::  
::  Standalone batch file - NO Python required!
::  Maximizes bandwidth for Iranian users during internet shutdowns.
::  
::  USAGE: 
::    1. Run Psiphon Conduit FIRST
::    2. Right-click this file → Run as Administrator
::  
::  This script ONLY affects conduit-tunnel-core.exe
::  Your PC, browsing, and other apps work normally.
::
::  Credits: Based on https://github.com/SamNet-dev/iran-conduit-firewall
:: ========================================================================

set "VERSION=2.0.0"
set "RULE_PREFIX=IranConduit"
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%conduit_config.txt"
set "LOG_FILE=%SCRIPT_DIR%firewall.log"
set "TEMP_IPV4=%TEMP%\iran_ipv4.txt"
set "TEMP_IPV6=%TEMP%\iran_ipv6.txt"
set "CONDUIT_URL=https://conduit.psiphon.ca/"

:: ========================================================================
:: AUTO-ELEVATE TO ADMINISTRATOR
:: ========================================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%SCRIPT_DIR%"
echo [%date% %time%] === Iran Firewall v%VERSION% started === >> "%LOG_FILE%"

goto :MAIN_MENU

:: ========================================================================
:: MAIN MENU
:: ========================================================================
:MAIN_MENU
cls
echo.
echo ========================================================================
echo        IRAN-ONLY FIREWALL FOR PSIPHON CONDUIT v%VERSION%
echo ========================================================================
echo   Maximize bandwidth for Iranian users during internet shutdowns
echo   [STANDALONE - No Python Required]
echo ========================================================================
echo.
echo   1. [ENABLE]  Iran-only mode (Normal)
echo   2. [ENABLE]  Iran-only mode (Strict)
echo   3. [DISABLE] Iran-only mode
echo   4. [STATUS]  Check current status
echo   5. [CONDUIT] Conduit management
echo   6. [HELP]    Help
echo   0. [EXIT]    Exit
echo.
echo ------------------------------------------------------------------------
echo   Normal: TCP global, UDP Iran-only (recommended)
echo   Strict: TCP+UDP Iran-only (may affect broker visibility)
echo ------------------------------------------------------------------------
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

:: ========================================================================
:: ENABLE IRAN-ONLY MODE
:: ========================================================================
:ENABLE_NORMAL
set "STRICT_MODE=0"
goto :ENABLE_COMMON

:ENABLE_STRICT
echo.
echo   WARNING: Strict mode restricts TCP to Iran only.
echo   This may prevent Psiphon brokers from seeing your node.
echo.
set /p "CONFIRM=  Continue? (y/n): "
if /i not "%CONFIRM%"=="y" goto :MAIN_MENU
set "STRICT_MODE=1"
goto :ENABLE_COMMON

:ENABLE_COMMON
cls
echo.
echo ========================================================================
if "%STRICT_MODE%"=="1" (
    echo   ENABLING IRAN-ONLY MODE [STRICT]
) else (
    echo   ENABLING IRAN-ONLY MODE [NORMAL]
)
echo ========================================================================
echo.

:: Step 1: Verify Firewall
echo [1/7] Verifying Windows Firewall...
call :VERIFY_FIREWALL
if %errorlevel% neq 0 (
    echo   ERROR: Cannot proceed without Windows Firewall enabled
    pause
    goto :MAIN_MENU
)

:: Step 2: Check Conduit Running
echo.
echo [2/7] Checking Conduit status...
call :IS_CONDUIT_RUNNING
if %errorlevel% equ 0 (
    echo   OK: Conduit is running
) else (
    echo   INFO: Conduit is NOT running
    echo.
    echo   IMPORTANT: Please start Psiphon Conduit first!
    echo   The script needs to detect Conduit from the running process.
    echo.
    set /p "WAIT_CONDUIT=  Start Conduit now, then press Enter (or 0 to go back): "
    if "!WAIT_CONDUIT!"=="0" goto :MAIN_MENU
)

:: Step 3: Find Conduit
echo.
echo [3/7] Locating Conduit executable...
call :FIND_CONDUIT
if not defined CONDUIT_PATH (
    pause
    goto :MAIN_MENU
)
echo   Path: %CONDUIT_PATH%

:: Step 4: Download IPs
echo.
echo [4/7] Downloading Iran IP ranges...
call :DOWNLOAD_IPS
if %errorlevel% neq 0 (
    echo   ERROR: Failed to download IP ranges
    pause
    goto :MAIN_MENU
)

:: Step 5: Remove old rules
echo.
echo [5/7] Removing existing rules...
call :REMOVE_ALL_RULES
echo   OK: Old rules removed

:: Step 6: Create new rules
echo.
echo [6/7] Creating firewall rules...
call :CREATE_RULES

:: Step 7: Verify
echo.
echo [7/7] Verifying rules...
call :VERIFY_RULES

:: Save config
echo %CONDUIT_PATH%> "%CONFIG_FILE%"
echo [%date% %time%] Iran-only mode enabled. Strict=%STRICT_MODE% >> "%LOG_FILE%"

echo.
echo ========================================================================
echo   SUCCESS! IRAN-ONLY MODE ENABLED
echo ========================================================================
echo.
echo   * Your PC is NOT affected - only Conduit
echo   * Only Iranian users can now use your data tunnel
echo.
pause
goto :MAIN_MENU

:: ========================================================================
:: DISABLE IRAN-ONLY MODE
:: ========================================================================
:DISABLE
cls
echo.
echo   Disabling Iran-only mode...
echo.

call :REMOVE_ALL_RULES

if exist "%CONFIG_FILE%" (
    set /p CONDUIT_PATH=<"%CONFIG_FILE%"
    if defined CONDUIT_PATH (
        echo   Restoring default allow rule...
        powershell -NoProfile -Command "New-NetFirewallRule -DisplayName 'Psiphon Conduit (Restored)' -Description 'Restored by IranFirewall' -Direction Inbound -Action Allow -Enabled True -Program '!CONDUIT_PATH!' -ErrorAction SilentlyContinue" >nul 2>&1
    )
)

echo [%date% %time%] Iran-only mode disabled >> "%LOG_FILE%"
echo.
echo   SUCCESS: Iran-only mode DISABLED
echo   Conduit now accepts connections from all countries.
echo.
pause
goto :MAIN_MENU

:: ========================================================================
:: STATUS
:: ========================================================================
:STATUS
cls
echo.
echo ========================================================================
echo   CURRENT STATUS
echo ========================================================================
echo.

echo   [Windows Firewall]
powershell -NoProfile -Command "$p = Get-NetFirewallProfile -All; $e = ($p | Where-Object {$_.Enabled}).Count; if($e -eq 3){'   Status: ENABLED (all profiles)'}else{'   Status: WARNING - Some profiles disabled'}"

echo.
echo   [Iran Firewall Rules]
powershell -NoProfile -Command "$r = Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -EA SilentlyContinue; if($r){'   Status: IRAN-ONLY MODE ENABLED'; '   Total rules: '+$r.Count; '   Allow: '+(($r|?{$_.Action-eq'Allow'}).Count); '   Block: '+(($r|?{$_.Action-eq'Block'}).Count)}else{'   Status: DISABLED (no rules)'}"

echo.
echo   [Psiphon Conduit]
call :IS_CONDUIT_RUNNING
if %errorlevel% equ 0 (
    echo    Status: Running
) else (
    echo    Status: Not running
)

echo.
echo   [Saved Path]
if exist "%CONFIG_FILE%" (
    type "%CONFIG_FILE%"
) else (
    echo    Not configured
)

echo.
pause
goto :MAIN_MENU

:: ========================================================================
:: CONDUIT MENU
:: ========================================================================
:CONDUIT_MENU
cls
echo.
echo ========================================================================
echo   CONDUIT MANAGEMENT
echo ========================================================================
echo.
echo   1. Start Conduit
echo   2. Stop Conduit
echo   3. Check if running
echo   4. Open Conduit website
echo   5. Show saved path
echo   0. Back to main menu
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
    echo   Done
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="3" (
    call :IS_CONDUIT_RUNNING
    if !errorlevel! equ 0 (
        echo   Conduit is RUNNING
    ) else (
        echo   Conduit is NOT running
    )
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="4" (
    start "" "%CONDUIT_URL%"
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="5" (
    if exist "%CONFIG_FILE%" (
        echo   Saved path:
        type "%CONFIG_FILE%"
    ) else (
        echo   Not configured
    )
    pause
    goto :CONDUIT_MENU
)
if "%CONDUIT_CHOICE%"=="0" goto :MAIN_MENU
goto :CONDUIT_MENU

:: ========================================================================
:: HELP
:: ========================================================================
:HELP
cls
echo.
echo ========================================================================
echo   HELP - Iran-Only Firewall v%VERSION%
echo ========================================================================
echo.
echo   WHAT THIS DOES:
echo   Creates firewall rules so only Iranian IPs can use your Psiphon
echo   Conduit bandwidth. Uses explicit BLOCK rules for security.
echo.
echo   HOW TO USE:
echo   1. Start Psiphon Conduit FIRST (must be running)
echo   2. Run this script as Administrator
echo   3. Choose option 1 (Normal) or 2 (Strict)
echo.
echo   MODES:
echo   Normal: TCP global, UDP Iran-only (recommended)
echo   Strict: TCP+UDP Iran-only (maximum restriction)
echo.
echo   REQUIREMENTS:
echo   - Windows 10/11
echo   - Psiphon Conduit running
echo   - Run as Administrator
echo.
echo   CREDITS:
echo   Based on https://github.com/SamNet-dev/iran-conduit-firewall
echo.
pause
goto :MAIN_MENU

:: ========================================================================
:: EXIT
:: ========================================================================
:EXIT
cls
echo.
echo   Thank you for helping Iran!
echo   Share this tool to help more people.
echo.
echo [%date% %time%] === Iran Firewall exited === >> "%LOG_FILE%"
timeout /t 2 >nul
exit /b 0

:: ========================================================================
:: HELPER FUNCTIONS
:: ========================================================================

:VERIFY_FIREWALL
powershell -NoProfile -Command "$p = Get-NetFirewallProfile -All; if(($p|?{$_.Enabled}).Count -eq 3){exit 0}else{exit 1}"
if %errorlevel% equ 0 (
    echo   OK: Windows Firewall is ENABLED
    exit /b 0
) else (
    echo   WARNING: Windows Firewall may be disabled
    set /p "ENABLE_FW=  Enable it now? (y/n): "
    if /i "!ENABLE_FW!"=="y" (
        powershell -NoProfile -Command "Set-NetFirewallProfile -All -Enabled True"
        echo   OK: Firewall enabled
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
    set /p CPATH=<"%CONFIG_FILE%"
    if exist "!CPATH!" (
        start "" "!CPATH!"
        timeout /t 2 >nul
        echo   Started
        exit /b 0
    )
)
echo   Path not saved. Please start Conduit manually.
exit /b 1

:FIND_CONDUIT
set "CONDUIT_PATH="

:: Check saved config
if exist "%CONFIG_FILE%" (
    set /p SAVED_PATH=<"%CONFIG_FILE%"
    if exist "!SAVED_PATH!" (
        set "CONDUIT_PATH=!SAVED_PATH!"
        echo   OK: Using saved path
        exit /b 0
    )
)

:: WMIC method - get path from running process
echo   Detecting from running process...
for /f "usebackq skip=1 tokens=*" %%a in (`wmic process where "name='conduit-tunnel-core.exe'" get ExecutablePath 2^>nul`) do (
    set "LINE=%%a"
    if defined LINE (
        set "LINE=!LINE: =!"
        if not "!LINE!"=="" (
            for /f "tokens=*" %%b in ("%%a") do (
                if exist "%%b" (
                    set "CONDUIT_PATH=%%b"
                    echo   OK: Found from running process
                    exit /b 0
                )
            )
        )
    )
)

:: PowerShell backup
echo   Trying PowerShell detection...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-Process conduit-tunnel-core -EA SilentlyContinue).Path" 2^>nul') do (
    if exist "%%a" (
        set "CONDUIT_PATH=%%a"
        echo   OK: Found via PowerShell
        exit /b 0
    )
)

:: AppxPackage for Windows Store
echo   Checking Windows Store...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "$p=Get-AppxPackage *Psiphon* -EA SilentlyContinue|Select -First 1;if($p){$p.InstallLocation+'\conduit-tunnel-core.exe'}" 2^>nul') do (
    if exist "%%a" (
        set "CONDUIT_PATH=%%a"
        echo   OK: Found Windows Store app
        exit /b 0
    )
)

:: Direct WindowsApps search
echo   Searching WindowsApps folder...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-ChildItem 'C:\Program Files\WindowsApps\ConduitPsiphon*\conduit-tunnel-core.exe' -EA SilentlyContinue|Select -First 1 -Exp FullName" 2^>nul') do (
    if exist "%%a" (
        set "CONDUIT_PATH=%%a"
        echo   OK: Found in WindowsApps
        exit /b 0
    )
)

:: Not found
echo.
echo   ============================================================
echo   ERROR: COULD NOT FIND PSIPHON CONDUIT
echo   ============================================================
echo.
echo   Is Psiphon Conduit currently RUNNING?
echo.
echo   Please:
echo     1. Open Psiphon Conduit app
echo     2. Wait until status shows "Active"
echo     3. Run this script again
echo.
exit /b 1

:DOWNLOAD_IPS
del "%TEMP_IPV4%" 2>nul
del "%TEMP_IPV6%" 2>nul

echo.
echo   Downloading IPv4 ranges...
echo   - ipdeny.com...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try{(iwr 'https://www.ipdeny.com/ipblocks/data/countries/ir.zone' -UseBasicParsing -TimeoutSec 30).Content|Out-File '%TEMP_IPV4%' -Encoding ASCII;'     OK'}catch{'     Failed'}"

echo   - herrbischoff GitHub...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try{(iwr 'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/ir.cidr' -UseBasicParsing -TimeoutSec 30).Content|Add-Content '%TEMP_IPV4%' -Encoding ASCII;'     OK'}catch{'     Failed'}"

if not exist "%TEMP_IPV4%" (
    echo   ERROR: All downloads failed
    exit /b 1
)

for /f %%a in ('type "%TEMP_IPV4%" ^| find /c "/"') do set "IPV4_COUNT=%%a"
if "%IPV4_COUNT%"=="0" (
    echo   ERROR: No IP ranges downloaded
    exit /b 1
)
echo   IPv4: %IPV4_COUNT% ranges

echo.
echo   Downloading IPv6 ranges...
echo   - ipdeny.com...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try{(iwr 'https://www.ipdeny.com/ipv6/ipaddresses/blocks/ir.zone' -UseBasicParsing -TimeoutSec 30).Content|Out-File '%TEMP_IPV6%' -Encoding ASCII;'     OK'}catch{'     Failed'}"

echo   - herrbischoff GitHub...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try{(iwr 'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv6/ir.cidr' -UseBasicParsing -TimeoutSec 30).Content|Add-Content '%TEMP_IPV6%' -Encoding ASCII;'     OK'}catch{'     Failed'}"

set "IPV6_COUNT=0"
if exist "%TEMP_IPV6%" (
    for /f %%a in ('type "%TEMP_IPV6%" ^| find /c ":"') do set "IPV6_COUNT=%%a"
)
echo   IPv6: %IPV6_COUNT% ranges

echo.
echo   Total: %IPV4_COUNT% IPv4 + %IPV6_COUNT% IPv6
exit /b 0

:REMOVE_ALL_RULES
powershell -NoProfile -Command "Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -EA SilentlyContinue|Remove-NetFirewallRule -EA SilentlyContinue"
timeout /t 1 >nul
exit /b 0

:CREATE_RULES
:: DNS Rules
echo.
echo   Creating DNS rules...
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-UDP' -Description 'DNS UDP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -RemoteAddress '8.8.8.8,8.8.4.4,1.1.1.1,1.0.0.1,9.9.9.9,149.112.112.112,208.67.222.222,208.67.220.220,178.22.122.100,185.51.200.2' -EA SilentlyContinue" >nul 2>&1
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-TCP' -Description 'DNS TCP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -RemoteAddress '8.8.8.8,8.8.4.4,1.1.1.1,1.0.0.1,9.9.9.9,149.112.112.112,208.67.222.222,208.67.220.220,178.22.122.100,185.51.200.2' -EA SilentlyContinue" >nul 2>&1
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-UDP-v6' -Description 'DNS UDP v6' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -RemoteAddress '2001:4860:4860::8888,2001:4860:4860::8844,2606:4700:4700::1111,2606:4700:4700::1001' -EA SilentlyContinue" >nul 2>&1
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-DNS-TCP-v6' -Description 'DNS TCP v6' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -RemoteAddress '2001:4860:4860::8888,2001:4860:4860::8844,2606:4700:4700::1111,2606:4700:4700::1001' -EA SilentlyContinue" >nul 2>&1
echo   OK: DNS rules

:: TCP Rules
echo.
echo   Creating TCP rules...
if "%STRICT_MODE%"=="0" (
    powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-TCP-Global' -Description 'Global TCP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -EA SilentlyContinue" >nul 2>&1
    echo   OK: TCP Global
) else (
    echo   INFO: TCP will be Iran-only (strict)
)

:: Iran IPv4 UDP
echo.
echo   Creating Iran IPv4 rules (please wait)...
powershell -NoProfile -Command "$ips=Get-Content '%TEMP_IPV4%'|?{$_-match'/'  -and $_-notmatch':' -and $_-notmatch'#'}|Select -Unique;$bs=200;$t=$ips.Count;$n=0;for($i=0;$i-lt$t;$i+=$bs){$b=$ips[$i..([Math]::Min($i+$bs-1,$t-1))];$l=$b-join',';$pct=[Math]::Min(100,[int](($i+$bs)/$t*100));Write-Host \"`r   Progress: $pct%%\" -NoNewline;New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-UDP-v4-$n' -Description 'Iran IPv4 UDP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $l -Protocol UDP -EA SilentlyContinue|Out-Null;if('%STRICT_MODE%'-eq'1'){New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-TCP-v4-$n' -Description 'Iran IPv4 TCP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $l -Protocol TCP -EA SilentlyContinue|Out-Null};$n++};Write-Host '';Write-Host '   OK: IPv4 rules created'"

:: Iran IPv6 UDP
if exist "%TEMP_IPV6%" (
    echo.
    echo   Creating Iran IPv6 rules...
    powershell -NoProfile -Command "$ips=Get-Content '%TEMP_IPV6%'|?{$_-match':'  -and $_-match'/' -and $_-notmatch'#'}|Select -Unique;if($ips.Count-gt 0){$bs=200;$t=$ips.Count;$n=0;for($i=0;$i-lt$t;$i+=$bs){$b=$ips[$i..([Math]::Min($i+$bs-1,$t-1))];$l=$b-join',';New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-UDP-v6-$n' -Description 'Iran IPv6 UDP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $l -Protocol UDP -EA SilentlyContinue|Out-Null;if('%STRICT_MODE%'-eq'1'){New-NetFirewallRule -DisplayName '%RULE_PREFIX%-Iran-TCP-v6-$n' -Description 'Iran IPv6 TCP' -Direction Inbound -Action Allow -Enabled True -Program '%CONDUIT_PATH%' -RemoteAddress $l -Protocol TCP -EA SilentlyContinue|Out-Null};$n++};Write-Host '   OK: IPv6 rules created'}else{Write-Host '   No IPv6 ranges'}"
)

:: BLOCK Rules
echo.
echo   Creating BLOCK rules...
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-UDP-All' -Description 'Block non-Iran UDP' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -EA SilentlyContinue" >nul 2>&1
echo   OK: UDP block
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-UDP-v6-All' -Description 'Block non-Iran IPv6 UDP' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol UDP -EA SilentlyContinue" >nul 2>&1
echo   OK: IPv6 UDP block

if "%STRICT_MODE%"=="1" (
    powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-TCP-All' -Description 'Block non-Iran TCP' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -EA SilentlyContinue" >nul 2>&1
    echo   OK: TCP block (strict)
    powershell -NoProfile -Command "New-NetFirewallRule -DisplayName '%RULE_PREFIX%-BLOCK-TCP-v6-All' -Description 'Block non-Iran IPv6 TCP' -Direction Inbound -Action Block -Enabled True -Program '%CONDUIT_PATH%' -Protocol TCP -EA SilentlyContinue" >nul 2>&1
    echo   OK: IPv6 TCP block (strict)
)

exit /b 0

:VERIFY_RULES
powershell -NoProfile -Command "$r=Get-NetFirewallRule -DisplayName '%RULE_PREFIX%*' -EA SilentlyContinue;$t=$r.Count;$a=($r|?{$_.Action-eq'Allow'}).Count;$b=($r|?{$_.Action-eq'Block'}).Count;'   Total: '+$t;'   Allow: '+$a;'   Block: '+$b;if($b-gt 0){'   OK: Block rules in place'}else{'   WARNING: No block rules'}"
exit /b 0