strCommand = "cmd /c C:\Users\[username]\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v3.3.4\scrcpy.exe --turn-screen-off --stay-awake --max-size=800 --video-bit-rate=2M --power-off-on-close --pause-on-exit=if-error --keyboard=uhid"

For Each Arg In WScript.Arguments
    strCommand = strCommand & " """ & replace(Arg, """", """""""""") & """"
Next

CreateObject("Wscript.Shell").Run strCommand, 0, false