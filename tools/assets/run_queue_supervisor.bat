@echo off
REM Persistent 150k asset queue supervisor (CLAUDE.md detached pattern).
REM Relaunches queue.py if it exits (crash, VRAM hiccup, ComfyUI restart) until the target is met.
REM Start detached:  powershell -Command "Start-Process -WindowStyle Hidden tools\assets\run_queue_supervisor.bat"
REM Stop: close the window / kill the python child.
set PY=C:\Users\vstef\ComfyUI\venv\Scripts\python.exe
set Q=%~dp0queue.py
:loop
echo [supervisor] launching queue at %date% %time%
"%PY%" "%Q%" --target 150000
echo [supervisor] queue exited (code %errorlevel%). Restarting in 15s... (Ctrl-C to stop)
timeout /t 15 /nobreak >nul
goto loop
