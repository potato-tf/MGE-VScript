@echo off
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )
setlocal enabledelayedexpansion

echo ------------------------------
echo MGE Database Setup for windows
echo ------------------------------
echo THIS SCRIPT MUST BE RUN FROM /scripts/vscripts/mge/vpi/
timeout 3 /nobreak
echo Install python and required packages?
echo This is required for the database, auto-updates, etc.
choice /C YN

if not errorlevel 2 (
    echo Installing python and pip...
    winget install python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
    echo Installing packages from requirements.txt...
    pip install -r requirements.txt
) else (
    echo Skipping python install...
    echo See requirements.txt for required modules
    echo mysql requires aiomysql, sqlite requires aiosqlite
    timeout 3 /nobreak
)
choice /C YN /M "Configure database?"
if not errorlevel 2 (
    echo -------------------------------------------------------------------
    echo THIS ASSUMES YOU ALREADY HAVE MYSQL/MARIADB OR SQLITE INSTALLED
    echo If you are new to this, install XAMPP and DBeaver before continuing
    echo XAMPP: https://www.apachefriends.org/download.html
    echo DBeaver: https://dbeaver.io/download/
    echo XAMPP will install mysql/mariadb
    echo DBeaver will allow you to manage/view your database
    echo -------------------------------------------------------------------
    timeout 5 /nobreak
    echo Enter mysql or sqlite.  Default is mysql:
    set /p dbtype=
    if "%dbtype%"=="" ( set dbtype="mysql" )
    echo %dbtype%
    if /I "%dbtype%"=="mysql" (
        pip install aiomysql
        echo Enter your database credentials:
        echo Skipping this step will create a database with the default values in vpi_config.py
        echo Host:
        set /p dbhost=
        echo Username:
        set /p dbuser=
        echo Port. Default is 3306:
        set /p dbport=
        echo Database name:
        set /p dbname=
        echo Password:
        set /p dbpass=

        if "%dbport%"=="" ( set dbport="3306" )

        echo Writing database credentials to .env...
        (
            echo DB_HOST       ="!dbhost!"
            echo DB_USER       ="!dbuser!"
            echo DB_PORT       ="!dbport!"
            echo DB_DATABASE   ="!dbname!"
            echo DB_PASSWORD   ="!dbpass!"
            echo SCRIPTDATA_DIR="../../../../scriptdata"
        ) > mge\.env
    ) else if /I "%dbtype%"=="sqlite" (
        pip install aiosqlite
        echo Select your database file:
        for /f "delims=" %%a in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog; $fileBrowser.Title = 'Select a SQLite database file'; $fileBrowser.Filter = 'SQLite Database (*.db;*.sqlite;*.db3)|*.db;*.sqlite;*.db3|All files (*.*)|*.*'; $fileBrowser.ShowDialog() | Out-Null; $fileBrowser.FileName"') do set "dbFilePath=%%a"
        echo Writing database path to .env...
        (
            echo DB_LITE="!dbFilePath!"
        ) > mge\.env
    )
    pause
) else (
    rem continue
)

choice /C YN /M "Auto-start MGE service on startup or crash?"

if not errorlevel 2 (
    echo Configuring auto-start service...
    sc create vpi_mge_service binPath= "python vpi.py" DisplayName= "MGE Python Service" start= auto
    sc failure vpi_mge_service reset= 0 actions= restart/1000
    echo Service created!
) else (
    rem continue
)
echo Starting VPI...
python mge/vpi/vpi.py

echo VPI SETUP COMPLETE!
pause

echo --------------------------------------------------------------------------------------
echo CONFIGURING YOUR SERVER:
echo 1. Open /scripts/vscripts/mge/cfg/config.nut
echo 2. Set ELO_TRACKING_MODE to 2
echo 3. Set 'const ENABLE_LEADERBOARD = true' to enable the leaderboard
echo 4. Reload the map
echo.
echo GAMEMODE AUTO-UPDATES:
echo 1. Uncomment the commented out GAMEMODE_AUTOUPDATE_REPO line
echo 2. Comment out or delete the 'const GAMEMODE_AUTOUPDATE_REPO = false' line
echo 3. Set GAMEMODE_AUTOUPDATE_TARGET_DIR to your full tf/scripts/vscripts directory path
echo 4. Do not change GAMEMODE_AUTOUPDATE_BRANCH unless you know what you are doing
echo.
echo --------------------------------------------------------------------------------------
pause
exit