# Get-FilteredFiles.ps1

function Get-FilteredFileItems {
    # Function to get file items based on various filter criteria.
    param(
        [string]$RootPath,
        [string[]]$IncludeFolders = @(),
        [string[]]$ExcludeFolders = @(), # Bu parametre [".svelte-kit", "build", "node_modules", "backend"] şeklinde bir dizi olarak gelir
        [string[]]$IncludeExtensions = @(), 
        [string[]]$ExcludeExtensions = @(), 
        [long]$MinSize = -1, 
        [long]$MaxSize = -1  
    )

    Write-Host "DEBUG: Get-FilteredFileItems called." -ForegroundColor Yellow
    Write-Host "DEBUG: RootPath: $RootPath" -ForegroundColor Yellow
    Write-Host "DEBUG: IncludeFolders (raw): $($IncludeFolders -join ', ')" -ForegroundColor Yellow
    Write-Host "DEBUG: ExcludeFolders (raw): $($ExcludeFolders -join ', ')" -ForegroundColor Yellow # Bu, Write-Host'un diziyi yazdırma şekli
    Write-Host "DEBUG: IncludeExtensions (raw): $($IncludeExtensions -join ', ')" -ForegroundColor Cyan
    Write-Host "DEBUG: ExcludeExtensions (raw): $($ExcludeExtensions -join ', ')" -ForegroundColor Yellow
    Write-Host "DEBUG: MinSize: $MinSize, MaxSize: $MaxSize" -ForegroundColor Yellow

    # Default exclusion lists (merged with caller-provided lists)
    # Bu liste, tarama sırasında yaygın olarak gereksiz veya okunamayan dosyaların otomatik hariç tutulması için kullanılır.
    $defaultExcludeExtensions = @(
        ".pyc", ".pyo", ".class", ".jar", ".so", ".o", ".a", ".lib", ".ilk", ".pdb", ".obj",
        ".tmp", ".temp", ".bak", ".log", ".trace", ".cache", ".swp",
        ".zip", ".gz", ".tar",
        ".jpg", ".jpeg", ".png", ".gif", ".bmp",
        ".iso", ".mp3", ".mp4",
        ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
        ".DS_Store", "thumbs.db", ".env"
    )

    if (-not $ExcludeExtensions) { $ExcludeExtensions = @() }
    # Normalize to lowercase, ensure starts with dot, remove empty, and remove duplicates
    $ExcludeExtensions = ($ExcludeExtensions + $defaultExcludeExtensions) | ForEach-Object {
        if ($_ -and $_.Trim()) {
            ($_.Trim().ToLowerInvariant() -replace '^\*?(?!\.)', '.')
        }
    } | Where-Object {$_} | Select-Object -Unique

    # Default folders to exclude (common build, dependency and VCS folders)
    $defaultExcludeFolders = @("node_modules", "build", "dist", ".cache", ".git", ".svn", ".hg", ".venv", "__pycache__", ".svelte-kit", ".github", ".pytest_cache", "venv")
    if (-not $ExcludeFolders) { $ExcludeFolders = @() }
    $ExcludeFolders = ($ExcludeFolders + $defaultExcludeFolders) | Select-Object -Unique

    # Normalize RootPath to an absolute path
    $absoluteRootPath = ""
    try {
        $absoluteRootPath = (Resolve-Path $RootPath -ErrorAction Stop).Path
    } catch {
        Write-Error "CRITICAL: Could not resolve RootPath: $RootPath. Aborting."
        return # Fonksiyondan çık
    }
    Write-Host "DEBUG: Absolute RootPath: $absoluteRootPath" -ForegroundColor Yellow

    $allFiles = Get-ChildItem -Path $absoluteRootPath -Recurse -File -ErrorAction SilentlyContinue
    Write-Host "DEBUG: Found $($allFiles.Count) total files initially in $absoluteRootPath." -ForegroundColor Yellow

    # Prepare a list of absolute paths for excluded folders
    $normalizedAbsoluteExcludeFolderPaths = [System.Collections.Generic.List[string]]::new()
    if ($ExcludeFolders -and $ExcludeFolders.Count -gt 0) {
        Write-Host "DEBUG: Processing ExcludeFolders array. Count: $($ExcludeFolders.Count)" -ForegroundColor DarkCyan
        foreach ($excFolderItem in $ExcludeFolders) { # $ExcludeFolders bir dizi olduğu için her elemanı tek tek işlenir
            $folderPathToResolve = Join-Path $absoluteRootPath $excFolderItem
            try {
                # Resolve-Path ile klasörün varlığını kontrol et ve tam yolunu al
                $resolvedPath = (Resolve-Path $folderPathToResolve -ErrorAction Stop).Path
                if (Test-Path $resolvedPath -PathType Container) {
                    $normalizedAbsoluteExcludeFolderPaths.Add($resolvedPath)
                    Write-Host "DEBUG: Added to Exclude List (resolved): '$excFolderItem' -> '$resolvedPath'" -ForegroundColor DarkGreen
                } else {
                    Write-Warning "Exclude folder path '$excFolderItem' (resolved to '$resolvedPath') is not a directory. It will be ignored."
                }
            } catch {
                # Resolve-Path hata verirse, klasör bulunamadı demektir. Bu normaldir, uyarıyı sessizce geç.
                Write-Host "DEBUG: Exclude folder '$excFolderItem' not found (tried '$folderPathToResolve'). Skipping." -ForegroundColor DarkGray
            }
        }
        Write-Host "DEBUG: Final Normalized Absolute ExcludeFolderPaths for matching: $($normalizedAbsoluteExcludeFolderPaths -join '; ')" -ForegroundColor DarkCyan
    }

    # Prepare a list of absolute paths for included folders
    $normalizedAbsoluteIncludeFolderPaths = [System.Collections.Generic.List[string]]::new()
    if ($IncludeFolders -and $IncludeFolders.Count -gt 0) {
        Write-Host "DEBUG: Processing IncludeFolders array. Count: $($IncludeFolders.Count)" -ForegroundColor DarkCyan
        foreach ($incFolderItem in $IncludeFolders) {
            $folderPathToResolve = Join-Path $absoluteRootPath $incFolderItem
            try {
                $resolvedPath = (Resolve-Path $folderPathToResolve -ErrorAction Stop).Path
                if (Test-Path $resolvedPath -PathType Container) {
                    $normalizedAbsoluteIncludeFolderPaths.Add($resolvedPath)
                    Write-Host "DEBUG: Added to Include List (resolved): '$incFolderItem' -> '$resolvedPath'" -ForegroundColor DarkGreen
                } else {
                    Write-Warning "Include folder path '$incFolderItem' (resolved to '$resolvedPath') is not a directory. It will be ignored."
                }
            } catch {
                Write-Warning "Could not resolve include folder path: '$incFolderItem' (tried as '$folderPathToResolve'). It will be ignored for inclusion."
            }
        }
        Write-Host "DEBUG: Final Normalized Absolute IncludeFolderPaths for matching: $($normalizedAbsoluteIncludeFolderPaths -join '; ')" -ForegroundColor DarkCyan
    }


    $filteredFileResult = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($file in $allFiles) {
        $shouldProcess = $true
        [string]$reasonForFiltering = "Passed initial check."

        # Folder Include Filter
        if ($normalizedAbsoluteIncludeFolderPaths.Count -gt 0) {
            $matchIncludeFolder = $false
            foreach ($absIncFolderPath in $normalizedAbsoluteIncludeFolderPaths) {
                if ($file.FullName.StartsWith($absIncFolderPath + [System.IO.Path]::DirectorySeparatorChar) -or $file.DirectoryName -eq $absIncFolderPath) {
                    $matchIncludeFolder = $true; break
                }
            }
            if (-not $matchIncludeFolder) {
                $shouldProcess = $false
                $reasonForFiltering = "File '$($file.FullName)' not in any included folders: $($normalizedAbsoluteIncludeFolderPaths -join ', ')"
            }
        }

        # Folder Exclude Filter
        if ($shouldProcess -and $normalizedAbsoluteExcludeFolderPaths.Count -gt 0) {
            foreach ($absExcFolderPath in $normalizedAbsoluteExcludeFolderPaths) {
                if ($file.FullName.StartsWith($absExcFolderPath + [System.IO.Path]::DirectorySeparatorChar) -or $file.DirectoryName -eq $absExcFolderPath) {
                    $shouldProcess = $false
                    $reasonForFiltering = "File '$($file.FullName)' is within excluded folder '$absExcFolderPath'."
                    break 
                }
            }
        }

        # Extension Include Filter
        if ($shouldProcess -and $IncludeExtensions.Count -gt 0) {
            $currentFileExtForDebug = $file.Extension.ToLowerInvariant() # Normalleştirilmiş uzantılarla karşılaştırmak için
            if (-not ($IncludeExtensions -contains $currentFileExtForDebug)) { # $IncludeExtensions CollectAndPrint.ps1'de normalleştirilmiş olmalı
                $shouldProcess = $false
                $reasonForFiltering = "Ext '$($file.Extension)' NOT IN IncludeExtensions '$($IncludeExtensions -join '; ')'."
            }
        }

        # Extension Exclude Filter
        if ($shouldProcess -and $ExcludeExtensions.Count -gt 0) {
            $currentFileExtForDebug = $file.Extension.ToLowerInvariant() # Normalleştirilmiş uzantılarla karşılaştırmak için
            if ($ExcludeExtensions -contains $currentFileExtForDebug) { # $ExcludeExtensions CollectAndPrint.ps1'de normalleştirilmiş olmalı
                $shouldProcess = $false
                $reasonForFiltering = "Ext '$($file.Extension)' IN ExcludeExtensions '$($ExcludeExtensions -join '; ')'."
            }
        }

        # Min Size Filter
        if ($shouldProcess -and $MinSize -ge 0) {
            if ($file.Length -lt $MinSize) {
                $shouldProcess = $false; $reasonForFiltering = "Size $($file.Length) is less than MinSize $MinSize."
            }
        }

        # Max Size Filter
        if ($shouldProcess -and $MaxSize -ge 0) {
            if ($file.Length -gt $MaxSize) {
                $shouldProcess = $false; $reasonForFiltering = "Size $($file.Length) is greater than MaxSize $MaxSize."
                Write-Host "DEBUG: File '$($file.FullName)' FILTERED OUT due to size ($($file.Length) > $MaxSize)." -ForegroundColor Yellow
            }
        }

        if ($shouldProcess) {
            $filteredFileResult.Add($file)
        } else {
            # İsteğe bağlı: Her filtrelenen dosya için detaylı loglama
            # Write-Host "DEBUG: File '$($file.FullName)' FILTERED OUT. Final Reason: $reasonForFiltering" -ForegroundColor Red
        }
    }
    Write-Host "DEBUG: Get-FilteredFileItems returning $($filteredFileResult.Count) files." -ForegroundColor Yellow
    return $filteredFileResult
}