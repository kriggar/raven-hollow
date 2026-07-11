@echo off
REM 30k asset queue supervisor (owner target 2026-07-11; CLAUDE.md detached pattern).
REM Start detached:  powershell -Command "Start-Process -WindowStyle Hidden tools\assets\run_queue_30k.bat"
set PY=C:\Users\vstef\ComfyUI\venv\Scripts\python.exe
set Q=%~dp0queue.py
:loop
echo [supervisor] launching queue at %date% %time%
"%PY%" "%Q%" --target 30000
echo [supervisor] queue exited (code %errorlevel%). Restarting in 15s... (Ctrl-C to stop)
timeout /t 15 /nobreak >nul
goto loop
