# Show-InteractiveMenu.ps1
# Interactive configuration menu for FolderToLLM

function Show-MenuHeader {
    Clear-Host
    Write-Host ""
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host "  |           " -ForegroundColor Cyan -NoNewline
    Write-Host "FolderToLLM Configuration Menu" -ForegroundColor White -NoNewline
    Write-Host "            |" -ForegroundColor Cyan
    Write-Host "  =======================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ConfigSummary {
    param([hashtable]$Config, [string]$RootPath)
    
    $gitignoreStatus = if ($Config.useGitignore) { "ON " } else { "OFF" }
    $gitignoreColor = if ($Config.useGitignore) { "Green" } else { "Red" }
    
    $excludeFoldersDisplay = if ($Config.excludeFolders.Count -gt 0) {
        ($Config.excludeFolders | Select-Object -First 3) -join ", "
        if ($Config.excludeFolders.Count -gt 3) { " (+$($Config.excludeFolders.Count - 3) more)" }
    }
    else { "(none)" }
    
    $excludeExtDisplay = if ($Config.excludeExtensions.Count -gt 0) {
        ($Config.excludeExtensions | Select-Object -First 5) -join ", "
        if ($Config.excludeExtensions.Count -gt 5) { " (+$($Config.excludeExtensions.Count - 5) more)" }
    }
    else { "(none)" }
    
    $includeExtDisplay = if ($Config.includeExtensions.Count -gt 0) {
        ($Config.includeExtensions | Select-Object -First 5) -join ", "
    }
    else { "(all files)" }
    
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "Current Settings:" -ForegroundColor Yellow
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    
    # Root Path
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(1)" -ForegroundColor Magenta -NoNewline
    Write-Host " Root Path: " -NoNewline
    $displayPath = if ($RootPath.Length -gt 45) { "..." + $RootPath.Substring($RootPath.Length - 42) } else { $RootPath }
    Write-Host $displayPath -ForegroundColor White
    
    # Use Gitignore
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(2)" -ForegroundColor Magenta -NoNewline
    Write-Host " Use .gitignore: " -NoNewline
    Write-Host $gitignoreStatus -ForegroundColor $gitignoreColor
    
    # Exclude Folders
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(3)" -ForegroundColor Magenta -NoNewline
    Write-Host " Exclude Folders: " -NoNewline
    $folderDisplay = if ($excludeFoldersDisplay.Length -gt 40) { $excludeFoldersDisplay.Substring(0, 37) + "..." } else { $excludeFoldersDisplay }
    Write-Host $folderDisplay -ForegroundColor Gray
    
    # Exclude Extensions
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(4)" -ForegroundColor Magenta -NoNewline
    Write-Host " Exclude Extensions: " -NoNewline
    $extDisplay = if ($excludeExtDisplay.Length -gt 35) { $excludeExtDisplay.Substring(0, 32) + "..." } else { $excludeExtDisplay }
    Write-Host $extDisplay -ForegroundColor Gray
    
    # Include Extensions
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(5)" -ForegroundColor Magenta -NoNewline
    Write-Host " Include Extensions: " -NoNewline
    $incDisplay = if ($includeExtDisplay.Length -gt 35) { $includeExtDisplay.Substring(0, 32) + "..." } else { $includeExtDisplay }
    Write-Host $incDisplay -ForegroundColor Gray
    
    # Max File Size
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(6)" -ForegroundColor Magenta -NoNewline
    Write-Host " Max File Size: " -NoNewline
    $sizeDisplay = Format-FileSize -Bytes $Config.maxFileSize
    Write-Host $sizeDisplay -ForegroundColor White
    
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
}

function Show-ActionMenu {
    Write-Host ""
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "Actions:" -ForegroundColor Yellow
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(R)" -ForegroundColor Green -NoNewline
    Write-Host " RUN - Generate Output"
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(S)" -ForegroundColor Blue -NoNewline
    Write-Host " Save Config (for -f mode)"
    Write-Host "  | " -ForegroundColor DarkGray -NoNewline
    Write-Host "(Q)" -ForegroundColor Red -NoNewline
    Write-Host " Quit"
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Read-MenuChoice {
    Write-Host "  Enter your choice: " -ForegroundColor Yellow -NoNewline
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host $key.Character
    return $key.Character.ToString().ToUpper()
}

function Edit-RootPath {
    param([string]$CurrentPath)
    
    Write-Host ""
    Write-Host "  Current Root Path: $CurrentPath" -ForegroundColor Gray
    Write-Host "  Enter new path (or press Enter to keep current): " -NoNewline
    $newPath = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($newPath)) {
        return $CurrentPath
    }
    
    if (Test-Path $newPath -PathType Container) {
        return (Resolve-Path $newPath).Path
    }
    else {
        Write-Host "  Invalid path! Keeping current." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return $CurrentPath
    }
}

function Edit-ListSetting {
    param(
        [string]$SettingName,
        [string[]]$CurrentValues
    )
    
    Write-Host ""
    Write-Host "  Current $SettingName :" -ForegroundColor Yellow
    if ($CurrentValues.Count -eq 0) {
        Write-Host "    (empty)" -ForegroundColor Gray
    }
    else {
        foreach ($val in $CurrentValues) {
            Write-Host "    - $val" -ForegroundColor Gray
        }
    }
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Cyan
    Write-Host "    (A) Add items (comma-separated)"
    Write-Host "    (R) Remove items (comma-separated)"
    Write-Host "    (C) Clear all"
    Write-Host "    (B) Back to menu"
    Write-Host ""
    Write-Host "  Choice: " -NoNewline
    $choice = Read-Host
    
    switch ($choice.ToUpper()) {
        "A" {
            Write-Host "  Enter items to add (comma-separated): " -NoNewline
            $inputVal = Read-Host
            $newItems = $inputVal.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            return @($CurrentValues) + @($newItems) | Select-Object -Unique
        }
        "R" {
            Write-Host "  Enter items to remove (comma-separated): " -NoNewline
            $inputVal = Read-Host
            $removeItems = $inputVal.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() }
            return @($CurrentValues | Where-Object { $_.ToLowerInvariant() -notin $removeItems })
        }
        "C" {
            return @()
        }
        default {
            return $CurrentValues
        }
    }
}

function Edit-MaxFileSize {
    param([long]$CurrentSize)
    
    Write-Host ""
    Write-Host "  Current Max Size: $(Format-FileSize -Bytes $CurrentSize)" -ForegroundColor Gray
    Write-Host "  Enter new size (e.g., 512KB, 2MB, or -1 for no limit): " -NoNewline
    $inputVal = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($inputVal)) {
        return $CurrentSize
    }
    
    if ($inputVal.Trim() -eq "-1") {
        return -1
    }
    
    $newSize = Parse-FileSize -SizeString $inputVal
    if ($newSize -ge 0) {
        return $newSize
    }
    else {
        Write-Host "  Invalid size format! Keeping current." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return $CurrentSize
    }
}

function Show-MainMenu {
    param(
        [string]$RootPath = (Get-Location).Path
    )
    
    # Load saved config or use defaults
    $config = Get-SavedConfig
    $config = Merge-ConfigWithDefaults -Config $config
    
    # If gitignore is enabled, parse it
    $gitignorePatterns = $null
    
    $continueMenu = $true
    $runAfterMenu = $false
    
    while ($continueMenu) {
        Show-MenuHeader
        Show-ConfigSummary -Config $config -RootPath $RootPath
        Show-ActionMenu
        
        $choice = Read-MenuChoice
        
        switch ($choice) {
            "1" {
                $RootPath = Edit-RootPath -CurrentPath $RootPath
            }
            "2" {
                $config.useGitignore = -not $config.useGitignore
                $statusText = if ($config.useGitignore) { "ENABLED" } else { "DISABLED" }
                $statusColor = if ($config.useGitignore) { "Green" } else { "Red" }
                Write-Host "  .gitignore usage: $statusText" -ForegroundColor $statusColor
                Start-Sleep -Milliseconds 500
            }
            "3" {
                $config.excludeFolders = Edit-ListSetting -SettingName "Exclude Folders" -CurrentValues $config.excludeFolders
            }
            "4" {
                $config.excludeExtensions = Edit-ListSetting -SettingName "Exclude Extensions" -CurrentValues $config.excludeExtensions
            }
            "5" {
                $config.includeExtensions = Edit-ListSetting -SettingName "Include Extensions" -CurrentValues $config.includeExtensions
            }
            "6" {
                $config.maxFileSize = Edit-MaxFileSize -CurrentSize $config.maxFileSize
            }
            "R" {
                $runAfterMenu = $true
                $continueMenu = $false
                # Auto-save config when running
                Save-Config -Config $config | Out-Null
            }
            "S" {
                Save-Config -Config $config
                Write-Host ""
                Write-Host "  Config saved! Use FolderToLLM -f for quick run." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "Q" {
                $continueMenu = $false
                Write-Host ""
                Write-Host "  Goodbye!" -ForegroundColor Yellow
            }
            default {
                Write-Host "  Invalid choice!" -ForegroundColor Red
                Start-Sleep -Milliseconds 500
            }
        }
    }
    
    # Return result
    return @{
        ShouldRun = $runAfterMenu
        Config    = $config
        RootPath  = $RootPath
    }
}
