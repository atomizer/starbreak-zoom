; Zoom for StarBreak (injected script)
; by atomizer

#NoEnv
#Persistent
#Warn
#InstallKeybdHook
#MaxThreads, 1

SetBatchLines -1
ListLines Off

if (!A_IsDll) {
  ExitApp
}

OnExit, Cleanup

Menu, tray, NoStandard
Menu, tray, Icon, mvmmoclient.exe, -1
Menu, tray, Tip, zoom

; --------------------------------------------------------------------------
; constants

ini := "zoom.ini"

; size of the offscreen framebuffer
BUFFERWIDTH := 4096
BUFFERHEIGHT := 4096

SysGet, MonitorPrimary, MonitorPrimary
IniRead, MonitorID, %ini%, window, monitor, %MonitorPrimary%
IniWrite, %MonitorID%, %ini%, window, monitor
SysGet, bounds, MonitorWorkArea, %MonitorID%

; window size
wLeft := boundsLeft
wTop := boundsTop
IniRead, wWidth, %ini%, window, width
IniRead, wHeight, %ini%, window, height
if (wWidth = "ERROR" || wHeight = "ERROR") {
  wWidth := boundsRight - boundsLeft
  wHeight := boundsBottom - boundsTop
}
IniWrite, %wWidth%, %ini%, window, width
IniWrite, %wHeight%, %ini%, window, height

; keys
IniRead, keyZoomIn, %ini%, keys, zoomin, NumpadAdd
IniRead, keyZoomOut, %ini%, keys, zoomout, NumpadSub
IniRead, keyNative, %ini%, keys, native, Numpad0
IniWrite, %keyZoomIn%, %ini%, keys, zoomin
IniWrite, %keyZoomOut%, %ini%, keys, zoomout
IniWrite, %keyNative%, %ini%, keys, native

; horisontal resolution difference per step
zstep := 640

; bounds for zoom, in zsteps
minZoom := 2
maxZoom := 6

; key delay
keyDelay := 300

; --------------------------------------------------------------------------
; globals

; first run flag
needsetup := true

; represents current screen width in zsteps
zoom := wWidth / zstep

aspectRatio := wHeight / wWidth

; current game resolution
cWidth := wWidth
cHeight := wHeight

framebuffer := 0
renderbuffer := 0
lastKeyTime := 0

; --------------------------------------------------------------------------
; GL constants

GL_FRAMEBUFFER := 0x8D40
GL_RENDERBUFFER := 0x8D41
GL_READ_FRAMEBUFFER := 0x8CA8
GL_DRAW_FRAMEBUFFER := 0x8CA9
GL_COLOR_ATTACHMENT0 := 0x8CE0
GL_FRAMEBUFFER_COMPLETE := 0x8CD5
GL_BACK := 0x0405

GL_TEXTURE_2D := 0x0DE1
GL_TEXTURE_WRAP_S := 0x2802
GL_TEXTURE_WRAP_T := 0x2803
GL_TEXTURE_MAG_FILTER := 0x2800
GL_TEXTURE_MIN_FILTER := 0x2801
GL_NEAREST := 0x2600
GL_LINEAR := 0x2601
GL_REPEAT := 0x2901
GL_CLAMP := 0x2900
GL_RGBA8 := 0x8058
GL_BGRA := 0x80E1
GL_UNSIGNED_BYTE := 0x1401
GL_COLOR_BUFFER_BIT := 0x4000

GL_TRIANGLES := 0x0004
GL_QUADS := 0x0007
GL_POLYGON := 0x0009

GL_MODELVIEW := 0x1700
GL_PROJECTION := 0x1701
GL_TEXTURE := 0x1702

GL_BLEND := 0x0BE2

; --------------------------------------------------------------------------
; init

PID := DllCall("GetCurrentProcessId")

WinWait, ahk_pid %PID%
sleep 3000

getGLProc := DynaCall("SDL2\SDL_GL_GetProcAddress", "i=a")
setWinPos := DynaCall("SetWindowPos", "t==ttiiiii")



; --------------------------------------------------------------------------
; hooks

hMinHook := DllCall("LoadLibrary", "Str", "MinHook.dll", "Ptr")
if (ErrorLevel) {
  MsgBox % "Failed to load MinHook.dll: " . ErrorLevel
  return
}

DllCall("MinHook\MH_Initialize", "Int")

origPtr := 0

; SDL_GL_SwapWindow
hookPtr := RegisterCallback("SwapWindowHook", "", 1)
DllCall("MinHook\MH_CreateHookApi", "Str", "SDL2", "AStr", "SDL_GL_SwapWindow", "Ptr", hookPtr, "PtrP", origPtr, "Int")
origSwapWindow := DynaCall(origPtr, "t")

; SDL_GetWindowSize
hookPtr := RegisterCallback("GetWindowSizeHook", "", 3)
DllCall("MinHook\MH_CreateHookApi", "Str", "SDL2", "AStr", "SDL_GetWindowSize", "Ptr", hookPtr, "PtrP", origPtr, "Int")
origGetWindowSize := DynaCall(origPtr, "ttt")

; SDL_GL_GetDrawableSize
hookPtr := RegisterCallback("GLGetDrawableSizeHook", "C", 3)
DllCall("MinHook\MH_CreateHookApi", "Str", "SDL2", "AStr", "SDL_GL_GetDrawableSize", "Ptr", hookPtr, "PtrP", origPtr, "Int")
origGLGetDrawableSize := DynaCall(origPtr, "ttt")

; enable everything
DllCall("MinHook\MH_EnableHook", "Ptr", 0, "Int")

; --------------------------------------------------------------------------
; start the party

update()

return

; END OF AUTOEXEC

; --------------------------------------------------------------------------
; hooked functions

GetWindowSizeHook(window, width, height) {
  critical
  global origGetWindowSize, cWidth, cHeight

  ; return the resolution that we want the game to render at
  NumPut(cWidth, width + 0, "Int")
  NumPut(cHeight, height + 0, "Int")
}

GLGetDrawableSizeHook(window, width, height) {
  critical
  global origGLGetDrawableSize, cWidth, cHeight

  ; these will be used by the game in a glViewport() call
  NumPut(cWidth, width + 0, "Int")
  NumPut(cHeight, height + 0, "Int")
}

SwapWindowHook(window) {
  critical
  global GL_FRAMEBUFFER, GL_RENDERBUFFER, GL_FRAMEBUFFER_COMPLETE
  global GL_DRAW_FRAMEBUFFER, GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_BACK, GL_COLOR_BUFFER_BIT, GL_LINEAR, GL_RGBA8
  global BUFFERWIDTH, BUFFERHEIGHT
  global glGenFramebuffers, glBindFramebuffer, glBindRenderbuffer, glRenderbufferStorage, glGenRenderbuffers
  global glFramebufferRenderbuffer, glCheckFramebufferStatus, glBlitFramebuffer, glGetError
  global origSwapWindow, needsetup, framebuffer, renderbuffer
  global wWidth, wHeight, cWidth, cHeight

  if (needsetup) {
    InitGLFunctions()

    ; framebuffer
    glGenFramebuffers[1, &framebuffer]
    checkGLError("glGenFramebuffers")
    framebuffer := NumGet(&framebuffer)
    glBindFramebuffer[GL_FRAMEBUFFER, framebuffer]
    checkGLError("glBindFramebuffer")

    ; renderbuffer
    glGenRenderbuffers[1, &renderbuffer]
    checkGLError("glGenRenderbuffers")
    renderbuffer := NumGet(&renderbuffer)
    glBindRenderbuffer[GL_RENDERBUFFER, renderbuffer]
    checkGLError("glBindRenderbuffer")
    glRenderbufferStorage[GL_RENDERBUFFER, GL_RGBA8, BUFFERWIDTH, BUFFERHEIGHT]
    checkGLError("glRenderbufferStorage")

    ; attach one to the other
    glFramebufferRenderbuffer[GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer]
    checkGLError("glFramebufferRenderbuffer")

    ; check for gremlins
    status := glCheckFramebufferStatus[GL_FRAMEBUFFER]
    if (status != GL_FRAMEBUFFER_COMPLETE) {
      MsgBox, 16, , Framebuffer is not complete.`nStatus code: %status%
      ExitApp
    }
    needsetup := false
  }

  ; copy what was drawn on the framebuffer to the screen
  glBindFramebuffer[GL_DRAW_FRAMEBUFFER, 0]
  glBlitFramebuffer[0, 0, cWidth, cHeight, 0, 0, wWidth, wHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR]
  checkGLError("glBlitFramebuffer")

  ; don't forget to call the original function
  glBindFramebuffer[GL_FRAMEBUFFER, 0]
  origSwapWindow[window]

  ; redirect drawing to our framebuffer
  glBindFramebuffer[GL_FRAMEBUFFER, framebuffer]

  ; we are already running every frame, might as well do hotkeys by hand
  checkKeys()
}

; --------------------------------------------------------------------------
; hotkey functions

checkKeys() {
  global lastKeyTime, keyDelay, keyNative, keyZoomIn, keyZoomOut
  if (A_TickCount - lastKeyTime < keyDelay) {
    return
  }
  if (GetKeyState(keyNative, "P")) {
    lastKeyTime := A_TickCount
    native()
    return
  }
  if (GetKeyState(keyZoomIn, "P")) {
    lastKeyTime := A_TickCount
    zoomin()
    return
  }
  if (GetKeyState(keyZoomOut, "P")) {
    lastKeyTime := A_TickCount
    zoomout()
    return
  }
}

zoomout() {
  global zoom, maxZoom
  pz := zoom
  zoom := Round(zoom + 1)
  if (zoom > maxZoom) {
    zoom := maxZoom
  }
  if (pz = zoom)
    return
  update()
}

zoomin() {
  global zoom, minZoom
  pz := zoom
  zoom := Round(zoom - 1)
  if (zoom < minZoom) {
    zoom := minZoom
  }
  if (pz = zoom)
    return
  update()
}

native() {
  global wWidth, zoom, zstep
  pz := zoom
  zoom := wWidth / zstep
  if (pz = zoom)
    return
  update()
}

update() {
  global zoom, zstep, aspectRatio, cWidth, cHeight, window, PID
  WinGet, window, ID, ahk_pid %PID%
  if (!window) {
    MsgBox, 16, , Unexpected condition: the game window no longer exists.
    ExitApp
  }
  cWidth := Round(zoom * zstep)
  cHeight := Round(cWidth * aspectRatio)
  WinSet, Style, -0xC40000, ahk_id %window%
  pingWindow()
  str := cWidth . " x " . cHeight
  Menu, tray, tip, %str%
}

; send resize event to trigger the hooks
pingWindow() {
  global setWinPos, window, wLeft, wTop, wWidth, wHeight
  setWinPos[window, 0, wLeft, wTop, wWidth, wHeight + 1, 0]
  setWinPos[window, 0, wLeft, wTop, wWidth, wHeight, 0]
}

log(str) {
  logFile := FileOpen("zoomlog.txt", "a")
  logFile.WriteLine(A_Now . " " . str)
  logFile.Close()
}

InitGLFunctions() {
  global
  glGenRenderbuffers := DynaCall(getGLProc["glGenRenderbuffers"], "it")
  glDeleteRenderbuffers := DynaCall(getGLProc["glDeleteRenderbuffers"], "it")
  glRenderbufferStorage := DynaCall(getGLProc["glRenderbufferStorage"], "iiii")
  glBindRenderbuffer := DynaCall(getGLProc["glBindRenderbuffer"], "ii")
  glBlitFramebuffer := DynaCall(getGLProc["glBlitFramebuffer"], "iiiiiiiiii")
  glCheckFramebufferStatus := DynaCall(getGLProc["glCheckFramebufferStatus"], "i==i")
  glBindFramebuffer := DynaCall(getGLProc["glBindFramebuffer"], "ii")
  glGenFramebuffers := DynaCall(getGLProc["glGenFramebuffers"], "it")
  glDeleteFramebuffers := DynaCall(getGLProc["glDeleteFramebuffers"], "it")
  glFramebufferRenderbuffer := DynaCall(getGLProc["glFramebufferRenderbuffer"], "iiii")
  glGetError := DynaCall(getGLProc["glGetError"], "i==")
}

checkGLError(lastfunc) {
  global glGetError
  err := glGetError[]
  if (err = 0)
    return
  MsgBox, 16, , GL error!`n`nFunction: %lastfunc%`nError code: %err%
  ExitApp
}

Cleanup:
; probably fogetting something
DllCall("MinHook\MH_Uninitialize", "Int")
DllCall("FreeLibrary", "Ptr", hMinHook)
if (!needsetup) {
  glBindFramebuffer[GL_FRAMEBUFFER, 0]
  glDeleteRenderbuffers[1, &renderbuffer]
  glDeleteFramebuffers[1, &framebuffer]
}
ExitApp
