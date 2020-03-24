SET OUT_EXE_NAME=zoom-click-and-drag.exe

REM Stop and clean out any existing exes
taskkill /FI "IMAGENAME eq %OUT_EXE_NAME%" /F
DEL %OUT_EXE_NAME%

REM Compile
SET AHK_COMPILER="%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe"
%AHK_COMPILER% /in "%cd%\zoom-click-and-drag.ahk" /out "%cd%\%OUT_EXE_NAME%" /icon "icon.ico"