@echo off
:loop
C:\Users\karna\AppData\Local\Android\Sdk\platform-tools\adb.exe reverse tcp:8000 tcp:8000 > nul 2>&1
timeout /t 2 > nul
goto loop
