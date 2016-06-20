; Zoom for StarBreak (loader script)
; by atomizer

#NoEnv
#Persistent
#SingleInstance, force

Menu, tray, tip, zoom loader
Menu, tray, NoStandard
Menu, tray, Add, Edit settings, settings
Menu, tray, Add, Visit homepage, homepage
Menu, tray, Add, Exit, exit

FileInstall, remote.ahk, remote.ahk, 0
FileInstall, AutoHotkey.dll, AutoHotkey.dll, 0
FileInstall, MinHook.dll, MinHook.dll, 0

PROCNAME := "mvmmoclient.exe"
ini := "loader.ini"

IniRead, gamePath, %ini%, default, gamePath
if (!FileExist(gamePath . "\" . PROCNAME)) {
  ; first run
  FileSelectFile, fullPath, 3, , Select the StarBreak executable, StarBreak (%PROCNAME%)
  SplitPath, fullPath, fileName, gamePath
  if (!FileExist(gamePath . "\" . PROCNAME)) {
    MsgBox, 16, , Game EXE not found.
    ExitApp
  }
  IniWrite, %gamePath%, %ini%, default, gamePath
}
if (!FileExist(gamePath . "\MinHook.dll")) {
  FileCopy, MinHook.dll, %gamePath%\MinHook.dll, 1
  if (ErrorLevel) {
    MsgBox, 16, , Could not copy MinHook.dll into the game folder.
    ExitApp
  }
}

LoadScript() {
  global rThread, PID, PROCNAME

  Process, Exist, %PROCNAME%
  PID := ErrorLevel
  if (!PID) {
    return
  }
  TrayTip, , game process detected, 2
  sleep 1000

  FileRead, remoteScript, remote.ahk
  rThread := InjectAhkDll(PID, A_ScriptDir "\AutoHotkey.dll", remoteScript)

  if (rThread.PID = PID) {
    TrayTip
    Process, WaitClose, %PID%
    TrayTip, , game closed, 2
  }
  else {
    MsgBox, 48, , Failed to inject AutoHotkey.dll into the game process.
    ExitApp
  }
  PID := 0
}

SetTimer, LoadScript, 1000
return

settings:
if (FileExist(gamePath . "\zoom.ini")) {
  Run, notepad.exe %gamePath%\zoom.ini
} else {
  MsgBox Launch the game once to generate the settings file!
}
return

homepage:
Run, https://github.com/atomizer/starbreak-zoom
return

exit:
ExitApp
