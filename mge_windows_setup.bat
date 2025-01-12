@echo off

if %answer% == "Y" || %answer% == "y" || %answer% == "Yes" (
    echo Installing python and pip...
    winget install python
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py

    echo Install all requirements? Y/N
    set /p answer2=
) else (
    echo Python installation skipped.
    echo Press Enter to continue
    pause
    exit
) 