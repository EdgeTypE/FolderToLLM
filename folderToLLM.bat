@echo off
chcp 65001 >nul
REM FolderToLLM - Batch wrapper for easy execution
REM This batch file automatically detects its own location

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "MAIN_SCRIPT_PATH=%SCRIPT_DIR%CollectAndPrint.ps1"

REM Check if -f or -Fast flag is present for fast mode
echo %* | findstr /i /r "\-f \-Fast" >nul
if %errorlevel% equ 0 (
    REM Fast mode detected - pass -Fast switch
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MAIN_SCRIPT_PATH%" -Fast
) else (
    REM Normal mode - pass all arguments
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MAIN_SCRIPT_PATH%" %*
)