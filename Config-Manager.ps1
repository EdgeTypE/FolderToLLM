# Config-Manager.ps1
# Manages configuration loading, saving, and defaults for FolderToLLM

$script:ConfigFileName = "folderToLLM.config.json"

function Get-ConfigFilePath {
    # Returns the path to the global config file (in script directory)
    return Join-Path $PSScriptRoot $script:ConfigFileName
}

function Get-DefaultConfig {
    # Returns a hashtable with default configuration values
    return @{
        lastUsed = $null
        useGitignore = $true
        excludeFolders = @("node_modules", ".git", "dist", "build", ".svelte-kit", "__pycache__", ".venv", "venv")
        excludeExtensions = @(".env", ".log", ".tmp", ".cache")
        includeFolders = @()
        includeExtensions = @()
        maxFileSize = 1048576  # 1MB
        minFileSize = -1
        outputPrefix = "LLM_Output"
    }
}

function Get-SavedConfig {
    # Loads configuration from file, returns default if file doesn't exist
    $configPath = Get-ConfigFilePath
    
    if (Test-Path $configPath) {
        try {
            $jsonContent = Get-Content -Path $configPath -Raw -Encoding UTF8
            $config = $jsonContent | ConvertFrom-Json -AsHashtable
            Write-Host "Configuration loaded from: $configPath" -ForegroundColor Green
            return $config
        }
        catch {
            Write-Warning "Failed to load config file. Using defaults. Error: $($_.Exception.Message)"
            return Get-DefaultConfig
        }
    }
    else {
        Write-Host "No config file found. Using defaults." -ForegroundColor Yellow
        return Get-DefaultConfig
    }
}

function Save-Config {
    # Saves configuration to file
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $configPath = Get-ConfigFilePath
    
    # Update lastUsed timestamp
    $Config.lastUsed = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    
    try {
        $jsonContent = $Config | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $configPath -Encoding UTF8 -Force
        Write-Host "Configuration saved to: $configPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to save config file. Error: $($_.Exception.Message)"
        return $false
    }
}

function Merge-ConfigWithDefaults {
    # Ensures all required keys exist in config by merging with defaults
    param(
        [hashtable]$Config
    )
    
    $defaults = Get-DefaultConfig
    
    foreach ($key in $defaults.Keys) {
        if (-not $Config.ContainsKey($key)) {
            $Config[$key] = $defaults[$key]
        }
    }
    
    return $Config
}

function Format-FileSize {
    # Converts bytes to human-readable format
    param([long]$Bytes)
    
    if ($Bytes -lt 0) { return "No limit" }
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N1} GB" -f ($Bytes / 1GB)
}

function Parse-FileSize {
    # Converts human-readable size string to bytes
    param([string]$SizeString)
    
    $SizeString = $SizeString.Trim().ToUpper()
    
    if ($SizeString -match '^(\d+(?:\.\d+)?)\s*(B|KB|MB|GB)?$') {
        $value = [double]$Matches[1]
        $unit = if ($Matches[2]) { $Matches[2] } else { "B" }
        
        switch ($unit) {
            "B"  { return [long]$value }
            "KB" { return [long]($value * 1KB) }
            "MB" { return [long]($value * 1MB) }
            "GB" { return [long]($value * 1GB) }
        }
    }
    
    return -1  # Invalid input
}
