#Persistent
#MaxThreadsPerHotkey, 2 ; Allow two threads for same hotkey so right click can be used as both start and (early) stop

/**
* Adjustable Vars - Defaults
*/
MinMouseMove := 2 ; Minimum px of movement to consider the mouse to have moved. Setting the value higher means that it is easier to stop the drag operation with erratic mouse movement. Keep low to avoid accidental early ends of drag.
MouseCheckMs := 200 ; How often to check mouse movement when running loop. Balanced with MinMouseMove. Don't make too large, or it could miss circular movement, where mouse actually traveled a bunch, but returned to same spot at each check.
MinStableMouseToStopDragMs := 2000 ; How long the mouse has to be left in one spot for it to be interpreted as the user ending the drag operation
RemoteControlLagMs := 1200 ; Lag time before starting check for mouse movement, to give time for lag between host and remote, for user to notice drag is now on

/**
* Build GUI
*/
CoordMode, mouse, Screen ; Coordinates are relative to the desktop (entire screen)
Gui, MainWin:New, +AlwaysOnTop +Resize -MaximizeBox +MinSize +MaxSize640x640
; Main on/off checkbox
Gui, MainWin:Add, Checkbox, vIsEnabled, Enabled?
; --- Config ui elements --
; MinMouseMove
Gui, MainWin:Add, Text,, % "Min Mouse Movement to Keep Drag On (PX)"
Gui, MainWin:Add, Edit
Gui, MainWin:Add, UpDown, vMinMouseMove gGetConfigFromUi Range1-20, % MinMouseMove
; RemoteControlLagMs
Gui, MainWin:Add, Text, vRCLMDisplay, % "Remote Lag Compensation (MS): " . RemoteControlLagMs
Slider_Max := RemoteControlLagMs + 5000
Gui, MainWin:Add, Slider, vRemoteControlLagMs gGetConfigFromUi +Range0-%Slider_Max%, % RemoteControlLagMs
; MinStableMouseToStopDragMs
Gui, MainWin:Add, Text, vMSMTSDDisplay, % "Stable Mouse to Stop Drag (MS): " . MinStableMouseToStopDragMs
Slider_Max := MinStableMouseToStopDragMs + 2000
Gui, MainWin:Add, Slider, vMinStableMouseToStopDragMs gGetConfigFromUi +Range0-%Slider_Max%, % MinStableMouseToStopDragMs
; Gui, MainWin:Add, 
Gui, MainWin:Show, W250 H250
Gui, MainWin:Submit, NoHide

/**
* Non-configurable global vars
*/
ConfigFilePath := "./rcad-config.ini"
IsHolding := 0
MsSinceLastMove := 0
MouseLastX := -1
MouseLastY := -1
HasConfigFile := 0
return

/**
* Reusable Methods
*/

UpdateGui() {
	global
	GuiControl, MainWin:Text, RCLMDisplay, % "Remote Lag Compensation (MS): " . RemoteControlLagMs
	GuiControl, MainWin:Text, MSMTSDDisplay, % "Stable Mouse to Stop Drag (MS): " . MinStableMouseToStopDragMs
}

resetVars() {
	global
	IsHolding := 0
	MsSinceLastMove := 0
	MouseLastX := -1
	MouseLastY := -1
}

cancelTimer() {
	SetTimer, checkMouseMove, Off
}

GetConfigFromUi() {
	Gui, MainWin:Submit, NoHide
	UpdateGui()
}

getConfigFromFile() {
	if (HasConfigFile or FileExist(%ConfigFilePath%)) {
		; @TODO
	}
}

endHold() {
	global IsHolding
	if (IsHolding) {
		; Release left mouse
		Click, Up
	}

	cancelTimer()
	resetVars()
}

/**
* Based on
* - https://www.autohotkey.com/boards/viewtopic.php?t=29802
* - https://autohotkey.com/board/topic/73582-draw-a-cirle-around-last-mouse-click-location/
*/
highlightMouse(Radius:=50, Temp:=1, DurationMs:=100) {
	Diameter := 2 * Radius
	Gui, MouseHighlightLayer:New, +AlwaysOnTop -Caption +LastFound +Owner
	Gui, MouseHighlightLayer:Color, Red
	; Makes highlight layer take up entire screen, but hidden
	Gui, MouseHighlightLayer:Show, Hide x0 y0 w%A_ScreenWidth% h%A_ScreenHeight%
	WinSet, Transparent, 64
	MouseGetPos, x, y
	x -= Radius, y -= Radius
	WinSet, Region, E %x%-%y% w%Diameter% h%Diameter%
	Gui, MouseHighlightLayer:Show
	if (Temp) {
		Sleep, % DurationMs
		Gui, MouseHighlightLayer:Hide
	}
}

checkMouseMove() {
	global
	MouseGetPos, MouseX, MouseY, , ,1
	; OutputDebug, % "Mouse at " . MouseX . ", " . MouseY . " || Old = " . MouseLastX . ", " . MouseLastY

	; First, check to see if checkbox changed. If so, we can just cancel early
	GetConfigFromUi()
	if (IsEnabled = 0) {
		OutputDebug, % "Stopping hold early - checkbox status changed"
		Return endHold()
	}

	if (Abs(MouseLastX - MouseX) > MinMouseMove or Abs(MouseLastY - MouseY) > MinMouseMove) {
		MsSinceLastMove := 0
	} else {
		MsSinceLastMove := MsSinceLastMove + MouseCheckMs
	}

	MouseLastX := MouseX
	MouseLastY := MouseY

	; check if min has elapsed
	if (MsSinceLastMove > MinStableMouseToStopDragMs) {
		OutputDebug, % "Mouse left in same spot for " . MsSinceLastMove . ". Ending hold! :)"
		endHold()
	} else {
		OutputDebug, % "Mouse checked. In same pos for " . MsSinceLastMove
	}
	Return
}

; Intercept right click - this will automatically block unless re-emitted with `Send`
RButton::
	GetConfigFromUi()
	if (IsEnabled = 1) {
		if (IsHolding = 0) {
			OutputDebug, % "Intercepted right click - starting hold flow"
			; Start hold
			IsHolding := 1
			OutputDebug, % "Getting initial mouse position"
			MouseGetPos, MouseLastX, MouseLastY
			; There is no "mouse move" hotkey, so we have to start a timer to listen
			OutputDebug, % "Initializing Timer"
			; Show visual cue to user that drag is now enabled - make very large and long to account for lag
			highlightMouse(300, 1, RemoteControlLagMs * 2)
			; Add delay, to account for remote control lag
			Sleep, % RemoteControlLagMs
			SetTimer, checkMouseMove, % MouseCheckMs
			OutputDebug, % "Started hold and timer"
			; This lines HAS to come last, or else it hangs thread without starting timer!!!
			Click, Down
			Return
		} else {
			; Treat as "panic" and cancel
			endHold()
			OutputDebug, % "PANIC! Right click pressed while holding. Cancelling."
			Return
		}
	} else {
		Send {RButton}
		Return
	}

; Intercept left click, DONT BLOCK
~$LButton::
	if (IsHolding) {
		endHold()
		OutputDebug, % "Ended hold early due to left click"
	}
	Return

; Panic option - cancel timers / stop interception
$^!p::
	; Cancel operations, reset
	endHold()
	; Pass through
	Send ^!p
	; alert
	OutputDebug, "PANIC combo pressed! Stopped override."
	Return

; Testing
^![::
	OutputDebug, % "Running highlightMouse() on demand."
	highlightMouse()