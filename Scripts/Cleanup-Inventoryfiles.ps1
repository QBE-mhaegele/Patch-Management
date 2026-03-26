<#
.SYNOPSIS
    Clean up old inventory files from central locations
.DESCRIPTION
    Removes old duplicate inventory files from the network share and/or local inventory folder
    Keeps only the newest file for each computer
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InventoryShare = "\\qbe-den-qnap\File4\Inventory",
    
    [Parameter(Mandatory=$false)]
    [string]$LocalInventoryPath = "C:\PatchManagement\Inventory",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Inventory File Cleanup Utility" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "? WHATIF MODE - No files will be deleted`n" -ForegroundColor Yellow
}

$TotalDeleted = 0
$TotalKept = 0

# Function to clean up a folder
function Clean-InventoryFolder {
    param(
        [string]$Path,
        [string]$LocationName
    )
    
    Write-Host "Cleaning: $LocationName" -ForegroundColor Cyan
    Write-Host "  Path: $Path" -ForegroundColor Gray
    
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        Write-Host "  ? Path not accessible or doesn't exist`n" -ForegroundColor Gray
        return
    }
    
    # Get all JSON files
    $AllFiles = Get-ChildItem -Path $Path -Filter "*.json" -ErrorAction SilentlyContinue
    
    if ($AllFiles.Count -eq 0) {
        Write-Host "  ? No inventory files found`n" -ForegroundColor Gray
        return
    }
    
    Write-Host "  Found $($AllFiles.Count) total files" -ForegroundColor White
    
    # Group files by computer name (extract from filename: COMPUTERNAME_timestamp.json)
    $ComputerGroups = $AllFiles | Group-Object {
        if ($_.Name -match '^([^_]+)_') {
            $matches[1]
        } else {
            $_.Name
        }
    }
    
    Write-Host "  Computers: $($ComputerGroups.Count)" -ForegroundColor White
    
    $LocationDeleted = 0
    $LocationKept = 0
    
    foreach ($Group in $ComputerGroups) {
        $ComputerName = $Group.Name
        $Files = $Group.Group
        
        if ($Files.Count -eq 1) {
            # Only one file, keep it
            Write-Host "    $ComputerName : 1 file (kept)" -ForegroundColor Green
            $LocationKept++
        } else {
            # Multiple files - keep newest, delete rest
            $Newest = $Files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $ToDelete = $Files | Where-Object {$_.FullName -ne $Newest.FullName}
            
            Write-Host "    $ComputerName : $($Files.Count) files, keeping newest, deleting $($ToDelete.Count)" -ForegroundColor Yellow
            
            foreach ($File in $ToDelete) {
                if ($WhatIf) {
                    Write-Host "      [WHATIF] Would delete: $($File.Name)" -ForegroundColor DarkGray
                    $LocationDeleted++
                } else {
                    try {
                        Remove-Item $File.FullName -Force -ErrorAction Stop
                        Write-Host "      ? Deleted: $($File.Name)" -ForegroundColor DarkGray
                        $LocationDeleted++
                    } catch {
                        Write-Host "      ? Failed to delete: $($File.Name) - $_" -ForegroundColor Red
                    }
                }
            }
            
            $LocationKept++
        }
    }
    
    Write-Host "`n  Summary for $LocationName :" -ForegroundColor Cyan
    Write-Host "    Computers with inventory: $LocationKept" -ForegroundColor Green
    Write-Host "    Old files deleted: $LocationDeleted" -ForegroundColor $(if ($WhatIf) {"Yellow"} else {"White"})
    Write-Host ""
    
    $script:TotalDeleted += $LocationDeleted
    $script:TotalKept += $LocationKept
}

# Clean network share
if ($InventoryShare) {
    Clean-InventoryFolder -Path $InventoryShare -LocationName "Network Share"
}

# Clean local folder
if ($LocalInventoryPath) {
    Clean-InventoryFolder -Path $LocalInventoryPath -LocationName "Local Folder"
}

# Final summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Total computers with inventory: $TotalKept" -ForegroundColor Green
Write-Host "Total old files removed: $TotalDeleted" -ForegroundColor $(if ($TotalDeleted -gt 0) {"Green"} else {"Gray"})

if ($WhatIf) {
    Write-Host "`n? This was a WHATIF run - no files were actually deleted" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to perform cleanup" -ForegroundColor Gray
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
