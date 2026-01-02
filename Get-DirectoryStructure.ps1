# Get-DirectoryStructure.ps1

function Get-DirectoryStructureFormatted {
    # Function to recursively get the directory structure as a formatted string.
    # Now supports excluding folders from the tree output.
    param(
        [string]$Path,
        [string]$Indent = "",
        [string[]]$ExcludeFolders = @()
    )

    $childItems = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
    
    # Separate directories and files and sort them by name for consistent order
    $directories = $childItems | Where-Object {$_.PSIsContainer} | Sort-Object Name
    $files = $childItems | Where-Object {!$_.PSIsContainer} | Sort-Object Name
    
    # Filter out excluded folders
    if ($ExcludeFolders.Count -gt 0) {
        $directories = $directories | Where-Object {
            $dirName = $_.Name
            $excluded = $false
            foreach ($excPattern in $ExcludeFolders) {
                if ($dirName -eq $excPattern -or $dirName -like $excPattern) {
                    $excluded = $true
                    break
                }
            }
            -not $excluded
        }
    }
    
    $outputLines = @() # Use an array to build lines
    
    $totalChildrenCount = $directories.Count + $files.Count
    $processedChildrenCount = 0

    # Process directories
    foreach ($dir in $directories) {
        $processedChildrenCount++
        $isThisChildTheVeryLast = ($processedChildrenCount -eq $totalChildrenCount)
        
        # Determine the prefix for the current directory entry
        $linePrefix = if ($isThisChildTheVeryLast) { "└── " } else { "├── " }
        $outputLines += "$Indent$linePrefix$($dir.Name)"
        
        # Determine the indent for the children of this directory
        $childIndentContinuation = if ($isThisChildTheVeryLast) { "    " } else { "│   " }
        $recursiveResult = Get-DirectoryStructureFormatted -Path $dir.FullName -Indent ($Indent + $childIndentContinuation) -ExcludeFolders $ExcludeFolders
        
        if (-not [string]::IsNullOrEmpty($recursiveResult)) {
            # Add the multi-line result from recursion to our output lines
            $outputLines += $recursiveResult
        }
    }

    # Process files
    foreach ($file in $files) {
        $processedChildrenCount++
        $isThisChildTheVeryLast = ($processedChildrenCount -eq $totalChildrenCount)
        
        # Determine the prefix for the current file entry
        $linePrefix = if ($isThisChildTheVeryLast) { "└── " } else { "├── " }
        $outputLines += "$Indent$linePrefix$($file.Name)"
    }

    # Join all collected lines with newlines
    return $outputLines -join "`n"
}