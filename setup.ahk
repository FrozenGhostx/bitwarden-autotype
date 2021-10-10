﻿; Defaults
ListLines Off
SetBatchLines -1
DetectHiddenWindows On

; Preload the turtle...
Run PowerShell -C Exit,, Hide

; Arguments
verbose := !quiet := false
if (A_Args[1] ~= "i)-quiet")
	verbose := !quiet := true

; Upgrade notice
if (verbose && A_OSVersion = "WIN_7")
	Alert(0x10, "Officially unsupported OS", "In January of 2020, Microsoft stopped the support of Windows 7. Is highly recommended to upgrade your OS.")

if !FileExist(A_ProgramFiles "\Auto-Type\bw.exe")
	&& !DllCall("Wininet\InternetCheckConnection", "Str","https://github.com", "Ptr",1, "Ptr",0)
{
	Alert(0x10, "Error", "Internet connectivity is required to download Bitwarden CLI.")
	ExitApp 1
}

; Check if latest version
if (A_IsCompiled && !Update_IsLatest())
{
	Alert(0x44, "Outdated installer", "There is a new version of this application.`n`nIs NOT recommended the usage of older versions. Do you want to go to GitHub and download the current release?")
	IfMsgBox Yes
	{
		Run https://github.com/anonymous1184/bitwarden-autotype/releases/latest
		ExitApp
	}
}

; Registry key
RegRead isInstalled, % key := "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Auto-Type"

; Ask
if (verbose && !isInstalled)
{
	Alert_Labels("", "&Exit")
	Alert(0x24, "Install?", "Do you want to install Bitwarden Auto-Type?")
	IfMsgBox No ; Relabeled as `Exit`
		ExitApp
}

; Close if running
WinKill ahk_exe bw-at.exe

; Download progress
Gui New, +AlwaysOnTop +HwndHwnd +LastFound -SysMenu
Gui Font, s11 q5, Consolas
Gui Add, Text,, Getting version...
Gui Show,, > Bitwarden CLI
Hotkey IfWinActive, % "ahk_id" hWnd
Hotkey !F4, WinExist

; If exists...
FileGetVersion offline, % A_ProgramFiles "\Auto-Type\bw.exe"

; Releases file
UrlDownloadToFile https://api.github.com/repos/bitwarden/cli/releases/latest
	, % A_Temp "\bw-releases.json"
if (ErrorLevel && !offline)
{
	Alert(0x11, "Error", "Bitwarden CLI release information cannot be retrieved.")
	ExitApp 1
}

; Check for latest
asset := {}
assets := {}
JSON._init()
FileRead buffer, % A_Temp "\bw-releases.json"
FileDelete % A_Temp "\bw-releases.json"
try
	assets := JSON.Load(buffer).assets
for i,asset in assets
{
	if RegExMatch(asset.name, "windows-\K.+(?=.zip)", online)
		break
	asset := {}
}

; No release for Windows, use last known
if !asset.HasKey("browser_download_url")
{
	online := "1.18.1"
	asset := { "browser_download_url":"https://github.com/bitwarden/cli/releases/download/v1.18.1/bw-windows-1.18.1.zip", "size":18788019 }
}

; Check if already latest
if CheckVersion(offline, online)
	Gui % hWnd ":Destroy"
else
{
	WinSetTitle % "> Bitwarden CLI v" online

	; Download
	SetTimer Download, -1
	SetTimer Percentage, 1

	; Destination
	FileCreateDir % A_ProgramFiles "\Auto-Type"
}

; App
FileInstall bw-at.exe, % A_ProgramFiles "\Auto-Type\bw-at.exe", % true

; Signature
/*TODO: Move into assets\ after the bug is fixed:
 * https://www.autohotkey.com/boards/viewtopic.php?f=14&t=94956
 */
FileInstall bw-at.ps1, % A_Temp "\bw-at.ps1", % true
Run % "PowerShell -ExecutionPolicy Bypass -File .\bw-at.ps1 "
		. Quote("Auto-Type") " "
		. Quote(A_ProgramFiles "\Auto-Type\bw-at.exe")
	, % A_Temp, Hide, psPid
; Run PowerShell -ExecutionPolicy Bypass -File .\bw-at.ps1, % A_Temp, Hide, psPid

; Uninstaller
FileInstall uninstall.exe, % A_ProgramFiles "\Auto-Type\uninstall.exe", % true

; Start Menu
start := A_AppDataCommon "\Microsoft\Windows\Start Menu\Programs\Auto-Type"
FileCreateDir % start
FileCreateShortcut % A_ProgramFiles "\Auto-Type\bw-at.exe"
	, % start "\Auto-Type.lnk"
FileCreateShortcut % A_ProgramFiles "\Auto-Type\uninstall.exe"
	, % start "\Uninstall.lnk"
FileCreateShortcut % A_ProgramFiles "\Auto-Type\bw-at.exe"
	, % A_DesktopCommon "\Auto-Type.lnk"
pretty := Quote("BW_PRETTY=true")
appDataDir := Quote("BITWARDENCLI_APPDATA_DIR=%AppData%\Auto-Type")
FileCreateShortcut % A_ComSpec, % start "\BW CLI.lnk"
	, % A_ProgramFiles "\Auto-Type"
	, % "/K " Quote("set " pretty " && set " appDataDir " && bw status")
IniWrite https://github.com/anonymous1184/bitwarden-autotype, % start
	. "\Project Page.url", InternetShortcut, URL
IniWrite % A_WinDir "\System32\shell32.dll", % start "\Project Page.url"
	, InternetShortcut, IconFile
IniWrite 14, % start "\Project Page.url", InternetShortcut, IconIndex

; Size calculation
installSize := 0
for i,dir in [start, A_ProgramFiles "\Auto-Type"]
{
	loop files, % dir "\*"
	{
		FileGetSize size, % A_LoopFileLongPath
		installSize += size
	}
}

; Uninstall information
FileGetVersion version, % A_ProgramFiles "\Auto-Type\bw-at.exe"

; https://docs.microsoft.com/en-us/windows/win32/msi/uninstall-registry-key
; https://nsis.sourceforge.io/Add_uninstall_information_to_Add/Remove_Programs
RegWrite REG_SZ, % key,, % A_Now
RegWrite REG_SZ, % key, Comments, Bitwarden Auto-Type capability via its CLI.
RegWrite REG_SZ, % key, DisplayIcon, % Quote(A_ProgramFiles "\Auto-Type\bw-at.exe")
RegWrite REG_SZ, % key, DisplayName, Bitwarden Auto-Type
RegWrite REG_SZ, % key, DisplayVersion, % version
RegWrite REG_DWORD, % key, EstimatedSize, % Format("{:#x}", installSize // 1024) ; In kb
RegWrite REG_SZ, % key, HelpLink, https://github.com/anonymous1184/bitwarden-autotype#readme
RegWrite REG_SZ, % key, InstallDate, % A_YYYY A_MM A_DD
RegWrite REG_SZ, % key, InstallLocation, % A_ProgramFiles "\Auto-Type"
RegWrite REG_DWORD, % key, Language, % Format("{:#x}", 1033) ; || SZ "x64;1033"
RegWrite REG_DWORD, % key, NoModify, 0x1
RegWrite REG_DWORD, % key, NoRepair, 0x1
RegWrite REG_SZ, % key, Publisher, u/anonymous1184
RegWrite REG_SZ, % key, QuietUninstallString, % Quote(A_ProgramFiles "\Auto-Type\uninstall.exe") " -quiet -s:0"
RegWrite REG_SZ, % key, UninstallString, % Quote(A_ProgramFiles "\Auto-Type\uninstall.exe")
RegWrite REG_SZ, % key, URLInfoAbout, https://github.com/anonymous1184/bitwarden-autotype/issues
RegWrite REG_SZ, % key, URLUpdateInfo, https://github.com/anonymous1184/bitwarden-autotype/releases/latest
version := StrSplit(version, ".")
RegWrite REG_SZ, % key, Version, % version[1] "." version[2] "." version[3]
RegWrite REG_DWORD, % key, VersionMajor, % Format("{:#x}", version[1])
RegWrite REG_DWORD, % key, VersionMinor, % Format("{:#x}", version[2])

/*
If installing after an uninstall that couldn't remove directories, those directories
are queued for deletion on the next reboot. The entries contain a double line-ending
that AHK can't handle, thus reg.exe is used to query the values then parsed/imported
*/
pending := GetStdStream("reg query " Quote("HKLM\SYSTEM\CurrentControlSet\Control\Session Manager") " /v PendingFileRenameOperations /se *")
if InStr(pending, "Auto-Type")
{
	regData := ""
	for _,file in StrSplit(pending, "\??\", "*`r`n")
	{
		if (FileExist(file) && !InStr(file, "\Auto-Type"))
			regData .=  "\??\" file "`n`n"
	}
	RegWrite REG_MULTI_SZ, HKLM\SYSTEM\CurrentControlSet\Control\Session Manager, PendingFileRenameOperations, % regData
}

; Acknowledge
Alert(0x40, (isInstalled ? "Update" : "Installation") " complete!"
	, "Application will be launched now.")

; PowerShell
ErrorLevel := psPid
while ErrorLevel
{
	Process Exist, % psPid
	ToolTip Please wait...
}
ToolTip
FileDelete % A_Temp "\bw-at.ps1"

; Run, unelevated
app := A_ProgramFiles "\Auto-Type\bw-at.exe" (isInstalled ? "" : " -settings")
DllCall("wdc\WdcRunTaskAsInteractiveUser", "Str",app, "Ptr",0)


ExitApp


Download:
	UrlDownloadToFile % asset.browser_download_url, % A_Temp "\bw.zip"
	SetTimer Percentage, Delete
	Gui % hWnd ":Destroy"
	; Unzip
	Zip_Extract(A_Temp "\bw.zip", A_ProgramFiles "\Auto-Type")
	FileDelete % A_Temp "\bw.zip"
return

Percentage:
	FileGetSize current, % A_Temp "\bw.zip"
	GuiControl % hWnd ":", Static1, % "Downloaded: " Round(current / asset.size * 100, 2) "%"
return

#NoEnv
#NoTrayIcon
#KeyHistory 0
;@Ahk2Exe-IgnoreBegin
#SingleInstance Force
#Warn All, OutputDebug
;@Ahk2Exe-IgnoreEnd
/*@Ahk2Exe-Keep
#SingleInstance Ignore
*/

; Includes
#Include %A_ScriptDir%
#Include <JSON>


;@Ahk2Exe-Base %A_ScriptDir%\assets\bw-at.bin, setup.exe, CP65001
;@Ahk2Exe-SetCompanyName u/anonymous1184
;@Ahk2Exe-SetCopyright Copyleft 2020
;@Ahk2Exe-SetDescription Bitwarden Auto-Type Installer
;@Ahk2Exe-SetLanguage 0x0409
;@Ahk2Exe-SetMainIcon %A_ScriptDir%\assets\bw-at.ico
;@Ahk2Exe-SetName Bitwarden Auto-Type
;@Ahk2Exe-SetOrigFilename setup.ahk
;@Ahk2Exe-SetProductVersion 1.1.1.1
;@Ahk2Exe-SetVersion 1.1.1.1
;@Ahk2Exe-UpdateManifest 1, Auto-Type, 1.1.1.1, 0
; BinMod
;@Ahk2Exe-PostExec "%A_ScriptDir%\assets\BinMod.exe" "%A_WorkFileName%"
;@Ahk2Exe-Cont  "2.AutoHotkeyGUI.Auto-Type-GUI"
;@Ahk2Exe-PostExec "%A_ScriptDir%\assets\BinMod.exe" "%A_WorkFileName%"
;@Ahk2Exe-Cont  "22.>AUTOHOTKEY SCRIPT<.$APPLICATION SOURCE"
;@Ahk2Exe-PostExec "%A_ScriptDir%\assets\BinMod.exe" "%A_WorkFileName%" /SetUTC
