#Persistent
#MaxThreadsPerHotkey 2
; Gui, MainWin:New
Gui, +AlwaysOnTop +Resize -MaximizeBox +MinSize +MaxSize640x640
Gui, Add, Checkbox, vIsEnabled, Enabled?
Gui, Show, W300 H150
Gui, Submit, NoHide

; Adjustabled vars
MinMouseMove := 20 ; Minimum px of movement to consider the mouse to have moved. Setting the value higher means that it is easier to stop the drag operation with erratic mouse movement. Keep low to avoid accidental early ends of drag.
MouseCheckMs := 50 ; How often to check mouse movement when running loop
MinStableMouseToStopDragMs := 1200 ; How long the mouse has to be left in one spot for it to be interpreted as the user ending the drag operation

; Some global variables
IsHolding := 0
MsSinceLastMove := 0
MouseLastX := -1
MouseLastY := -1

; Init and stop timer
; SetTimer, checkMouseMove, Off
return

; Reusable methods
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

getIsEnabled() {
	global
	Gui, Submit, NoHide
	Return IsEnabled
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

checkMouseMove() {
	global
	OutputDebug, % "Checking mouse pos"
	MouseGetPos, MouseX, MouseY

	; First, check to see if checkbox changed. If so, we can just cancel early
	getIsEnabled()
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
	getIsEnabled()
	if (IsEnabled = 1) {
		if (IsHolding = 0) {
			OutputDebug, % "Intercepted right click - starting hold flow"
			; MsgBox, "BLOCKED RIGHT BUTTON"
			; Emit mouse down
			IsHolding := 1
			OutputDebug, % "Ln 93"
			; Click, Down
			Send {LButton Down}
			OutputDebug, % "Ln 95"
			; store initial mouse position
			OutputDebug, % "Getting initial mouse position"
			MouseGetPos, MouseLastX, MouseLastY
			; There is no "mouse move" hotkey, so we have to start a timer to listen
			OutputDebug, % "Initializing Timer"
			SetTimer, checkMouseMove, % MouseCheckMs
			OutputDebug, % "Started hold and timer"
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