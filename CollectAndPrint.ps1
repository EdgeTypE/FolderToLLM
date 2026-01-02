# CollectAndPrint.ps1 - Main script to collect directory structure and file contents.

[CmdletBinding()]
param(
    # Default root path to the current directory where the script is run.
    [string]$RootPath = (Get-Location).Path,

    # Fast mode: use last saved configuration without showing menu
    [Alias("f")]
    [switch]$Fast,

    # Skip menu and use command-line parameters (legacy mode)
    [switch]$NoMenu,

    # Folders to include. If specified, only files in these folders (and subfolders) are processed.
    [string[]]$IncludeFolderPaths = @(),

    # Folders to exclude. Default to "node_modules". User can override or add more.
    [string[]]$ExcludeFolderPaths = @("node_modules"), # Default exclusion

    # File extensions to include. If specified, only files with these extensions are processed.
    [string[]]$IncludeExtensions = @(),

    # File extensions to exclude. Default to ".env". User can override or add more.
    [string[]]$ExcludeExtensions = @(".env"), # Default exclusion

    # Minimum file size in bytes. -1 for no limit.
    [long]$MinFileSize = -1,

    # Maximum file size in bytes. Default to 1MB (1024 * 1024 bytes). -1 for no limit.
    [long]$MaxFileSize = 1048576, # Default max size: 1MB
    
    # Prefix for the output file name.
    [string]$OutputFileNamePrefix = "LLM_Output"
)

#region Helper Scripts Loading
# Dot-source the helper scripts to make their functions available.
try {
    . "$PSScriptRoot\Get-DirectoryStructure.ps1"
    . "$PSScriptRoot\Get-FilteredFiles.ps1"
    . "$PSScriptRoot\Read-TextFileContent.ps1"
    . "$PSScriptRoot\Format-OutputString.ps1"
    . "$PSScriptRoot\Config-Manager.ps1"
    . "$PSScriptRoot\Get-GitignorePatterns.ps1"
    . "$PSScriptRoot\Show-InteractiveMenu.ps1"
}
catch {
    Write-Error "Failed to load helper scripts. Ensure they are in the same directory: $PSScriptRoot. Error: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Mode Detection and Configuration Loading
$useInteractiveMenu = $false
$config = $null

# Determine execution mode
if ($Fast) {
    # Fast mode: load saved config and run immediately
    Write-Host "Fast mode (-f): Loading saved configuration..." -ForegroundColor Cyan
    $config = Get-SavedConfig
    $config = Merge-ConfigWithDefaults -Config $config
    
    # Apply gitignore if enabled
    if ($config.useGitignore) {
        $gitignorePatterns = Get-GitignorePatterns -RootPath $RootPath
        if ($gitignorePatterns.FolderPatterns.Count -gt 0) {
            $config.excludeFolders = @($config.excludeFolders) + @($gitignorePatterns.FolderPatterns) | Select-Object -Unique
        }
        if ($gitignorePatterns.FilePatterns.Count -gt 0) {
            $gitExtensions = Convert-GitignoreToExtensions -FilePatterns $gitignorePatterns.FilePatterns
            $config.excludeExtensions = @($config.excludeExtensions) + @($gitExtensions) | Select-Object -Unique
        }
    }
    
    # Apply config to parameters
    $ExcludeFolderPaths = $config.excludeFolders
    $ExcludeExtensions = $config.excludeExtensions
    $IncludeFolderPaths = $config.includeFolders
    $IncludeExtensions = $config.includeExtensions
    $MaxFileSize = $config.maxFileSize
    $MinFileSize = $config.minFileSize
    $OutputFileNamePrefix = $config.outputPrefix
}
elseif ($NoMenu -or $PSBoundParameters.Count -gt 1) {
    # NoMenu mode or explicit parameters provided: use legacy command-line behavior
    Write-Host "Using command-line parameters (legacy mode)..." -ForegroundColor Yellow
    
    #region Parameter Pre-processing for bat file compatibility
    if ($IncludeFolderPaths.Count -eq 1 -and $IncludeFolderPaths[0] -match ',') {
        $IncludeFolderPaths = $IncludeFolderPaths[0].Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_}
    }
    if ($ExcludeFolderPaths.Count -eq 1 -and $ExcludeFolderPaths[0] -match ',') {
        $ExcludeFolderPaths = $ExcludeFolderPaths[0].Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_}
    }
    if ($IncludeExtensions.Count -eq 1 -and $IncludeExtensions[0] -match ',') {
        $IncludeExtensions = $IncludeExtensions[0].Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_}
    }
    if ($ExcludeExtensions.Count -eq 1 -and $ExcludeExtensions[0] -match ',') {
        $ExcludeExtensions = $ExcludeExtensions[0].Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_}
    }
    #endregion
}
else {
    # No parameters: show interactive menu
    $useInteractiveMenu = $true
}

# Show interactive menu if needed
if ($useInteractiveMenu) {
    $menuResult = Show-MainMenu -RootPath $RootPath
    
    if (-not $menuResult.ShouldRun) {
        Write-Host "Exiting without generating output." -ForegroundColor Yellow
        exit 0
    }
    
    # Apply menu config to parameters
    $RootPath = $menuResult.RootPath
    $config = $menuResult.Config
    
    # Apply gitignore if enabled
    if ($config.useGitignore) {
        $gitignorePatterns = Get-GitignorePatterns -RootPath $RootPath
        if ($gitignorePatterns.FolderPatterns.Count -gt 0) {
            $config.excludeFolders = @($config.excludeFolders) + @($gitignorePatterns.FolderPatterns) | Select-Object -Unique
        }
        if ($gitignorePatterns.FilePatterns.Count -gt 0) {
            $gitExtensions = Convert-GitignoreToExtensions -FilePatterns $gitignorePatterns.FilePatterns
            $config.excludeExtensions = @($config.excludeExtensions) + @($gitExtensions) | Select-Object -Unique
        }
    }
    
    $ExcludeFolderPaths = $config.excludeFolders
    $ExcludeExtensions = $config.excludeExtensions
    $IncludeFolderPaths = $config.includeFolders
    $IncludeExtensions = $config.includeExtensions
    $MaxFileSize = $config.maxFileSize
    $MinFileSize = $config.minFileSize
    $OutputFileNamePrefix = $config.outputPrefix
}
#endregion

#region Main Processing
Write-Host ""
Write-Host "Processing directory: $RootPath" -ForegroundColor Cyan
Write-Host "Exclude Folders: $($ExcludeFolderPaths -join ', ')"
Write-Host "Exclude Extensions: $($ExcludeExtensions -join ', ')"
if ($IncludeExtensions.Count -gt 0) {
    Write-Host "Include Extensions: $($IncludeExtensions -join ', ')"
}
Write-Host "Max File Size: $(Format-FileSize -Bytes $MaxFileSize)"
Write-Host ""

# 1. Get Directory Structure (with folder exclusions)
Write-Host "Generating directory structure..." -ForegroundColor Yellow
$directoryStructureString = Get-DirectoryStructureFormatted -Path $RootPath -ExcludeFolders $ExcludeFolderPaths

# 2. Get Filtered Files
Write-Host "Filtering files..." -ForegroundColor Yellow
# Normalize extension filters (ensure they start with a dot and are lowercase)
$normalizedIncludeExtensions = @($IncludeExtensions | ForEach-Object { ($_.Trim().ToLowerInvariant() -replace '^\*?(?!\.)','.') } | Where-Object {$_})
$normalizedExcludeExtensions = @($ExcludeExtensions | ForEach-Object { ($_.Trim().ToLowerInvariant() -replace '^\*?(?!\.)','.') } | Where-Object {$_})

# Ensure $filteredFileItems is always an array.
$filteredFileItems = @(Get-FilteredFileItems -RootPath $RootPath `
                                            -IncludeFolders $IncludeFolderPaths `
                                            -ExcludeFolders $ExcludeFolderPaths `
                                            -IncludeExtensions $normalizedIncludeExtensions `
                                            -ExcludeExtensions $normalizedExcludeExtensions `
                                            -MinSize $MinFileSize `
                                            -MaxSize $MaxFileSize)

Write-Host "Found $($filteredFileItems.Count) files matching criteria." -ForegroundColor Green

# 3. Format the output
Write-Host "Formatting output..." -ForegroundColor Yellow
$finalOutput = New-FormattedOutput -RootDirectory $RootPath `
    -DirectoryStructure $directoryStructureString `
    -FileItems $filteredFileItems `
    -ContentReader { param($FileItem) Read-SafeTextFileContent -FileItem $FileItem }

# 4. Output to File
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$outputFilePath = Join-Path -Path $RootPath -ChildPath "$($OutputFileNamePrefix)_$timestamp.txt"

try {
    Write-Host "Writing output to: $outputFilePath" -ForegroundColor Cyan
    $finalOutput | Out-File -FilePath $outputFilePath -Encoding UTF8 -Force
    Write-Host ""
    Write-Host "✓ Successfully generated output file!" -ForegroundColor Green
    Write-Host "  Path: $outputFilePath" -ForegroundColor Gray
    Write-Host "  Size: $(Format-FileSize -Bytes (Get-Item $outputFilePath).Length)" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to write output file: $($_.Exception.Message)"
}

# Optional: Display a snippet or confirmation
if ((Test-Path $outputFilePath) -and (Get-Item $outputFilePath).Length -lt 20000) {
    Write-Host ""
    Write-Host "--- Output File Preview (first 15 lines) ---" -ForegroundColor DarkGray
    Get-Content $outputFilePath -TotalCount 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "---" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Script finished. Use 'FolderToLLM -f' for quick re-run with same settings." -ForegroundColor Cyan
#endregion