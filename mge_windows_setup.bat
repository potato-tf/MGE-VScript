@echo off
setlocal enabledelayedexpansion

echo Install python? This is required for various features (auto-updates, database, etc.) Y/N
set /p answer=

if /I "%answer%"=="Y" (
    echo Installing python and pip...
    winget install python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py

) else if /I "%answer%"=="y" (
    echo Installing python and pip...
    winget install python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
) else (
    exit
)

echo Are you using a database? Y/N
set /p answer2=

if /I "%answer2%"=="Y" (
    echo Installing database dependencies...
    pip install aiomysql python-dotenv
) else if /I "%answer2%"=="y" (
    echo Installing database dependencies...
    pip install aiomysql python-dotenv
)
echo Are you using auto-updates? Y/N
set /p answer3=
if /I "%answer3%"=="Y" (
    echo Installing auto-update dependencies...
    pip install gitpython
) else if /I "%answer3%"=="y" (
    echo Installing auto-update dependencies...
    pip install gitpython
)

if /I "%answer2%"=="Y" (
    echo Enter your database credentials:
    echo Host:
    set /p dbhost=
    echo Database name:
    set /p dbname=
    echo Username:
    set /p dbuser=
    echo Password:
    set /p dbpass=
    echo Database credentials saved!
    (
    echo VPI_HOST="!dbhost!"
    echo VPI_NAME="!dbname!"
    echo VPI_USER="!dbuser!"
    echo VPI_PASS="!dbpass!"
    echo VPI_PORT=3306
    echo VPI_SCRIPTDATA_DIR="../../../../scriptdata"
    ) > mge\.env
    pause
) else if /I "%answer2%"=="y" (
    echo Enter your database credentials:
    echo Host:
    set /p dbhost=
    echo Database name:
    set /p dbname=
    echo Username:
    set /p dbuser=
    echo Password:
    set /p dbpass=
    echo Database credentials saved!
    (
    echo VPI_HOST="!dbhost!"
    echo VPI_NAME="!dbname!"
    echo VPI_USER="!dbuser!"
    echo VPI_PASS="!dbpass!"
    echo VPI_PORT=3306
    echo VPI_SCRIPTDATA_DIR="../../../../scriptdata"
    ) > mge\.env
    pause
)

echo Run python? Y/N
set /p answer4=
if /I "%answer4%"=="Y" (
    echo Connecting to database...
    python vpi/vpi.py
) else if /I "%answer4%"=="y" (
    echo Connecting to database...
    python vpi/vpi.py
)

echo Press Enter to close
pause
exit