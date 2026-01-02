@echo off
REM MODIFY THIS SECTION CAREFULLY!
REM Full path to the CollectAndPrint.ps1 script:
set "MAIN_SCRIPT_PATH=C:\src\FolderToLLM\CollectAndPrint.ps1"

REM Run the main script using PowerShell.exe and pass all arguments (%*).
REM -NoProfile: Does not load the PowerShell profile, starts faster.
REM -ExecutionPolicy Bypass: Temporarily relaxes the execution policy (use with caution).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MAIN_SCRIPT_PATH%" %*