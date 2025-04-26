@echo off
setlocal enabledelayedexpansion
rem Escape character for color codes
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

rem disable ear-piercing beep for invalid choice commands
rem I don't even know why this is needed, you already get a windows alert sound
powershell -Command "[Console]::Beep(0,0)" >nul 2>&1

echo !ESC![93m
echo --------------------------------------------------------
echo MGE database setup for Windows
echo THIS SCRIPT MUST BE RUN FROM /scripts/vscripts/mge/vpi/
echo --------------------------------------------------------
echo !ESC![92m
choice /C YN /M "Install python and required packages"
cls

if not errorlevel 2 (
    echo Installing python and pip...
    winget install python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
    echo Installing packages from requirements.txt...
    python -m pip install -r requirements.txt
) else (
    echo !ESC![96m
    echo Skipping python install...
    echo See requirements.txt for required modules
    echo if you configure a database, aiomysql or aiosqlite will be installed anyway
)
echo !ESC![92m
choice /C YN /M "Configure database"
cls
if not errorlevel 2 (
    echo !ESC![93m
    echo -------------------------------------------------------------------
    echo THIS ASSUMES YOU ALREADY HAVE MYSQL/MARIADB OR SQLITE INSTALLED
    echo If you are new to this, install XAMPP and DBeaver before continuing
    echo XAMPP: https://www.apachefriends.org/download.html
    echo DBeaver: https://dbeaver.io/download/
    echo XAMPP will install mysql/mariadb
    echo DBeaver will allow you to manage/view your database
    echo -------------------------------------------------------------------
    echo !ESC![92m
    echo Enter mysql or sqlite.  Default is mysql:
    echo !ESC![93m
    set /p dbtype=
    if /I "!dbtype!"=="sqlite" (
        pip install aiosqlite
        echo Select your database file:
        for /f "delims=" %%a in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog; $fileBrowser.Title = 'Select a SQLite database file'; $fileBrowser.Filter = 'SQLite Database (*.db;*.sqlite;*.db3)|*.db;*.sqlite;*.db3|All files (*.*)|*.*'; $fileBrowser.ShowDialog() | Out-Null; $fileBrowser.FileName"') do set "dbFilePath=%%a"
        echo Writing database path to env...
        (
            echo DB_TYPE=!dbtype!
            echo DB_LITE=!dbFilePath!
            echo SCRIPTDATA_DIR="..\..\..\..\..\..\..\scriptdata"
        ) > env
    ) else (
        set dbtype=mysql
        pip install aiomysql
        echo !ESC![96m
        echo Enter your database credentials:
        echo Skipping this step will create a database with the default values in vpi_config.py
        echo !ESC![92m
        echo Host.  Default is 'localhost':
        echo !ESC![93m
        set /p dbhost=
        echo !ESC![92m
        echo Username.  Default is 'root':
        echo !ESC![93m
        set /p dbuser=
        echo !ESC![92m
        echo Port.  Default is '3306':
        echo !ESC![93m
        set /p dbport=
        echo !ESC![92m
        echo Database name.  Default is 'mge':
        echo !ESC![93m
        set /p dbname=
        echo !ESC![92m
        echo Password:
        echo !ESC![93m
        set /p dbpass=

        if "!dbport!"=="" ( set dbport=3306 )
        if "!dbhost!"=="" ( set dbhost=localhost )
        if "!dbname!"=="" ( set dbname=mge )
        if "!dbuser!"=="" ( set dbuser=root )

        echo !ESC![96m
        echo Writing database credentials to env...
        (
            echo DB_TYPE=!dbtype!
            echo DB_HOST=!dbhost!
            echo DB_USER=!dbuser!
            echo DB_PORT=!dbport!
            echo DB_INTERFACE=!dbname!
            echo DB_PASSWORD=!dbpass!
            echo SCRIPTDATA_DIR="..\..\..\..\..\..\..\scriptdata"
        ) > env
    )
    echo STEAM_API_KEY=00000 >> env
    echo WEB_API_KEY=00000 >> env
    pause
) else (
    if not exist env (
        echo SCRIPTDATA_DIR="..\..\..\..\..\..\..\scriptdata" > env
    ) else (
        findstr /i "SCRIPTDATA_DIR" env >nul 2>&1
        if errorlevel 1 (
            echo SCRIPTDATA_DIR="..\..\..\..\..\..\..\scriptdata" >> env
        )
    )
)

cls
echo !ESC![96m
echo SET A SECRET TOKEN IN THESE TWO FILES:
echo !ESC![93m
echo    vpi_config.py
echo        !ESC![92mchange !ESC![96mSECRET = r""!ESC![92m to !ESC![96mSECRET = r"your_secret_token"!ESC![93m
echo    vpi.nut
echo        !ESC![92mchange the return value of the !ESC![96mGetSecret!ESC![92m function from !ESC![96m@""!ESC![92m to !ESC![96m@"your_secret_token"!ESC![93m
echo !ESC![91m
echo SKIPPING THIS STEP WILL FAIL TO START THE SERVICE
echo !ESC![96m
echo secret tokens are a random string of characters you create, treat this as a password
timeout /t 3 /nobreak >nul
echo !ESC![93m
pause

cls
echo !ESC![92m
@REM choice /C YN /M "Auto-start MGE service on startup or crash?"
@REM if not errorlevel 2 (
@REM     echo Configuring auto-start service...
@REM     echo !ESC![93m
@REM     sc stop vpi_mge_service
@REM     sc delete vpi_mge_service
@REM     for /f "tokens=*" %%i in ('where python') do set PYTHON_PATH=%%i
@REM     echo !PYTHON_PATH!
@REM     echo %~dp0vpi.py
@REM     sc create vpi_mge_service binPath= "!PYTHON_PATH! %~dp0vpi.py" DisplayName= "MGE VPI Service" start= auto
@REM     sc failure vpi_mge_service reset= 0 actions= restart/1000
@REM     sc start vpi_mge_service
@REM     echo !ESC![96m
@REM     echo Service started, see vpi.log in /scripts/vscripts/mge/vpi/ to view output
@REM     echo You can start/stop this service in tank manager in the 'Services' tab. Look for 'vpi_mge_service' or 'MGE VPI Service'
@REM ) else (
    echo !ESC![96m
    echo Starting VPI...
    start vpi_watch.bat
@REM )

echo !ESC![92m
echo VPI SETUP COMPLETE!
echo !ESC![93m
pause

cls
echo !ESC![96m
echo CONFIGURING YOUR SERVER:
echo !ESC![93m
echo 1. Open !ESC![96m/scripts/vscripts/mge/cfg/config.nut!ESC![93m
echo 2. Set !ESC![96mELO_TRACKING_MODE!ESC![93m to !ESC![96m2!ESC![93m
echo 3. Set !ESC![96mENABLE_LEADERBOARD!ESC![93m to !ESC![96mtrue!ESC![93m to enable the leaderboard
echo 4. Reload the map
echo !ESC![96m
echo GAMEMODE AUTO-UPDATES:
echo !ESC![93m
echo 1. Uncomment the commented out !ESC![96mGAMEMODE_AUTOUPDATE_REPO!ESC![93m line
echo 2. Comment out or delete the !ESC![96mconst GAMEMODE_AUTOUPDATE_REPO = false!ESC![93m line
echo 3. Set !ESC![96mGAMEMODE_AUTOUPDATE_TARGET_DIR!ESC![93m to your full !ESC![96m/scripts/vscripts!ESC![93m directory path
echo 4. Do not change !ESC![96mGAMEMODE_AUTOUPDATE_BRANCH!ESC![93m unless you know what you are doing
echo !ESC![93m
pause
exit