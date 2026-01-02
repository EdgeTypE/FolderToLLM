# Get-GitignorePatterns.ps1
# Parses .gitignore files and extracts exclusion patterns

function Get-GitignorePatterns {
    # Finds and parses .gitignore file in the specified path
    # Returns a hashtable with folder and file patterns
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )
    
    $result = @{
        FolderPatterns = [System.Collections.Generic.List[string]]::new()
        FilePatterns = [System.Collections.Generic.List[string]]::new()
        RawPatterns = [System.Collections.Generic.List[string]]::new()
    }
    
    $gitignorePath = Join-Path $RootPath ".gitignore"
    
    if (-not (Test-Path $gitignorePath)) {
        Write-Host "No .gitignore file found in: $RootPath" -ForegroundColor Yellow
        return $result
    }
    
    Write-Host "Parsing .gitignore: $gitignorePath" -ForegroundColor Cyan
    
    try {
        $lines = Get-Content -Path $gitignorePath -Encoding UTF8
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")) {
                continue
            }
            
            # Skip negation patterns (we only handle exclusions)
            if ($trimmedLine.StartsWith("!")) {
                continue
            }
            
            $result.RawPatterns.Add($trimmedLine)
            
            # Determine if it's a folder pattern or file pattern
            if ($trimmedLine.EndsWith("/")) {
                # Explicit folder pattern (e.g., "node_modules/")
                $folderName = $trimmedLine.TrimEnd('/')
                $result.FolderPatterns.Add($folderName)
            }
            elseif ($trimmedLine.Contains("/") -and -not $trimmedLine.StartsWith("*")) {
                # Path-based pattern (e.g., "build/output")
                $result.FolderPatterns.Add($trimmedLine.Split('/')[0])
            }
            elseif ($trimmedLine.StartsWith("*.") -or $trimmedLine.StartsWith(".")) {
                # File extension or dotfile pattern (e.g., "*.log", ".env")
                $result.FilePatterns.Add($trimmedLine)
            }
            elseif (-not $trimmedLine.Contains("*") -and -not $trimmedLine.Contains(".")) {
                # Simple name without extension - likely a folder (e.g., "node_modules")
                $result.FolderPatterns.Add($trimmedLine)
            }
            else {
                # Other patterns - treat as file patterns
                $result.FilePatterns.Add($trimmedLine)
            }
        }
        
        # Remove duplicates
        $result.FolderPatterns = [System.Collections.Generic.List[string]]($result.FolderPatterns | Select-Object -Unique)
        $result.FilePatterns = [System.Collections.Generic.List[string]]($result.FilePatterns | Select-Object -Unique)
        
        Write-Host "Found $($result.FolderPatterns.Count) folder patterns and $($result.FilePatterns.Count) file patterns" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to parse .gitignore: $($_.Exception.Message)"
    }
    
    return $result
}

function Convert-GitignoreToExtensions {
    # Converts gitignore file patterns to extension list
    # e.g., "*.log" -> ".log"
    param(
        [string[]]$FilePatterns
    )
    
    $extensions = [System.Collections.Generic.List[string]]::new()
    
    foreach ($pattern in $FilePatterns) {
        if ($pattern -match '^\*\.(\w+)$') {
            # Simple extension pattern like "*.log"
            $extensions.Add("." + $Matches[1].ToLowerInvariant())
        }
        elseif ($pattern -match '^\.(\w+)$') {
            # Dotfile pattern like ".env"
            $extensions.Add($pattern.ToLowerInvariant())
        }
    }
    
    return ($extensions | Select-Object -Unique)
}

function Test-FileMatchesGitignore {
    # Tests if a file matches any gitignore pattern
    param(
        [System.IO.FileInfo]$FileItem,
        [string[]]$FilePatterns
    )
    
    foreach ($pattern in $FilePatterns) {
        # Convert gitignore glob to PowerShell wildcard
        $psPattern = $pattern -replace '\*\*', '*'
        
        if ($FileItem.Name -like $psPattern) {
            return $true
        }
    }
    
    return $false
}

function Test-FolderMatchesGitignore {
    # Tests if a folder path matches any gitignore folder pattern
    param(
        [string]$FolderPath,
        [string[]]$FolderPatterns
    )
    
    $folderName = Split-Path $FolderPath -Leaf
    
    foreach ($pattern in $FolderPatterns) {
        if ($folderName -eq $pattern -or $folderName -like $pattern) {
            return $true
        }
    }
    
    return $false
}
