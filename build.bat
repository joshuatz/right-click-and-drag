SET SCRIPT_NAME_NO_EXT=right-click-and-drag

REM Stop and clean out any existing exes
taskkill /FI "IMAGENAME eq %OUT_EXE_NAME%" /F
DEL %OUT_EXE_NAME%

REM Compile
SET AHK_COMPILER="%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe"
%AHK_COMPILER% /in "%cd%\%SCRIPT_NAME_NO_EXT%.ahk" /out "%cd%\%SCRIPT_NAME_NO_EXT%.exe" /icon "icon.ico"