@echo off
cls
title VPI Watchdog
:vpi
echo (%time%) VPI started.
start /wait python vpi.py
echo (%time%) WARNING: VPI closed or crashed, restarting.
goto vpi