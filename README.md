## Zoom for StarBreak (Steam edition)

### Features

- adjustable zoom during play
- borderless fullscreen

### Usage

- make sure your game is set to windowed mode
- download the .EXE from latest [release](https://github.com/atomizer/starbreak-zoom/releases/latest)
- put the executable in a separate folder, it will drop some files next to it
- on first start, show where the game is located
- loader will sit in tray, you can now launch the game

### Default keys

Zoom in: Numpad +

Zoom out: Numpad -

Native resolution: Numpad 0

### Limitations

- Assigned keys are always active while the game is running. Do not assign keys that you are going to use for something else.
- Does not work correctly in fullscreen mode.
- Can't use the mouse in menus if the game is not at native resolution. Just switch to native and back.
- Can't toggle vsync while the script is running. If you need to change vsync, exit the game, close the loader and launch the game clean.
- OBS Classic will crash the game in "Game capture" mode. Use OBS Studio.

### Settings

To edit the keys, window size and which monitor to put the window on, right-click the loader icon. To apply the settings you need to close and re-open the game. Acceptable key names can be found [here](https://autohotkey.com/docs/KeyList.htm).

### Updating

If you want to update from an older release, remove everything except `loader.ini` from the folder where `sbzoom.exe` is and replace the EXE with the new one.

### Troubleshooting

If encounter an error, please post an [issue](https://github.com/atomizer/starbreak-zoom/issues).

### Creating the binary

If you don't trust me, you can compile the EXE yourself. You will need:

- installed [AutoHotkey](https://autohotkey.com/download/ahk-install.exe)
- 32 bit Unicode [AutoHotkey.dll](https://github.com/HotKeyIt/ahkdll-v1-release/tree/master/Win32w)
- 32 bit [MinHook.dll](http://www.codeproject.com/Articles/44326/MinHook-The-Minimalistic-x-x-API-Hooking-Libra)

Put the DLLs next to the scripts and use the "Convert .ahk to .exe" AutoHotkey tool on `loader.ahk`, using 32 bit unicode AutoHotkey as base executable.

Alternatively, after acquiring the DLLs, you can just run `loader.ahk` without compiling (don't forget to use 32 bit AutoHotkey).

### Credits

- Everything in `Lib/` folder and [AutoHotkey_H](https://github.com/HotKeyIt/ahkdll): [HotKeyIt](https://github.com/HotKeyIt)
- [MinHook](https://github.com/TsudaKageyu/minhook/): [TsudaKageyu](https://github.com/TsudaKageyu)

### License

MIT for my code (`loader.ahk` and `remote.ahk`); licenses for other components can be found by following the links above.
