<#
.SYNOPSIS
    Diagnose inventory file locations and accessibility
.DESCRIPTION
    Helps troubleshoot where inventory files are being saved and whether
    the Master-Orchestrator can access them
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InventoryShare = "\\qbe-den-qnap\File4\Inventory",
    
    [Parameter(Mandatory=$false)]
    [string]$LocalInventoryPath = "C:\PatchManagement\Inventory"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Inventory File Diagnostics" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Network Share Access
Write-Host "[Test 1] Checking network share access..." -ForegroundColor Yellow
Write-Host "  Path: $InventoryShare" -ForegroundColor Gray

if (Test-Path $InventoryShare -ErrorAction SilentlyContinue) {
    Write-Host "  Success: Share is accessible" -ForegroundColor Green
    
    # Check permissions
    try {
        $TestFile = Join-Path $InventoryShare "test_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
        "Test" | Out-File $TestFile -ErrorAction Stop
        Remove-Item $TestFile -ErrorAction SilentlyContinue
        Write-Host "  Success: Write access confirmed" -ForegroundColor Green
    } catch {
        Write-Host "  Error: No write access to share" -ForegroundColor Red
        Write-Host "    Details: $_" -ForegroundColor Red
    }
    
    # Count inventory files
    $ShareFiles = Get-ChildItem -Path $InventoryShare -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Files found: $($ShareFiles.Count)" -ForegroundColor Cyan
    
    if ($ShareFiles.Count -gt 0) {
        Write-Host "`n  Recent inventory files in share:" -ForegroundColor Cyan
        $ShareFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object {
            $SizeKB = [math]::Round($_.Length / 1KB, 2)
            Write-Host "    - $($_.Name)" -ForegroundColor White
            Write-Host "      Size: $SizeKB KB, Modified: $($_.LastWriteTime)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Warning: No .json files found in share" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "  Error: Share is not accessible" -ForegroundColor Red
    Write-Host "    This is likely the problem!" -ForegroundColor Yellow
}

# Test 2: Local Inventory Folder
Write-Host "`n[Test 2] Checking local inventory folder..." -ForegroundColor Yellow
Write-Host "  Path: $LocalInventoryPath" -ForegroundColor Gray

if (Test-Path $LocalInventoryPath) {
    Write-Host "  Success: Local folder exists" -ForegroundColor Green
    
    $LocalFiles = Get-ChildItem -Path $LocalInventoryPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Files found: $($LocalFiles.Count)" -ForegroundColor Cyan
    
    if ($LocalFiles.Count -gt 0) {
        Write-Host "`n  Recent inventory files in local folder:" -ForegroundColor Cyan
        $LocalFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object {
            $SizeKB = [math]::Round($_.Length / 1KB, 2)
            Write-Host "    - $($_.Name)" -ForegroundColor White
            Write-Host "      Size: $SizeKB KB, Modified: $($_.LastWriteTime)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Warning: No .json files found in local folder" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "  Warning: Local folder does not exist" -ForegroundColor Yellow
    Write-Host "    Creating it..." -ForegroundColor Gray
    
    try {
        New-Item -Path $LocalInventoryPath -ItemType Directory -Force | Out-Null
        Write-Host "    Success: Created $LocalInventoryPath" -ForegroundColor Green
    } catch {
        Write-Host "    Error: Failed to create folder: $_" -ForegroundColor Red
    }
}

# Test 3: Check Client Machines for Local Saves
Write-Host "`n[Test 3] Checking if clients saved locally..." -ForegroundColor Yellow

# Get list of computers from AD
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    
    # Load OUs from config file
    $ConfigPath = "C:\PatchManagement\Config\settings.json"
    
    if (Test-Path $ConfigPath) {
        try {
            $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $OUs = if ($Config.OUs -and $Config.OUs.Count -gt 0) { $Config.OUs } else { @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com") }
        } catch {
            $OUs = @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com")
        }
    } else {
        $OUs = @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com")
    }
    
    $AllComputers = @()
    foreach ($OU in $OUs) {
        $Computers = Get-ADComputer -Filter {Enabled -eq $true} -SearchBase $OU -ErrorAction SilentlyContinue
        $AllComputers += $Computers
    }
    
    Write-Host "  Checking $($AllComputers.Count) computers for local inventory files..." -ForegroundColor Gray
    
    $ClientsWithLocalInventory = @()
    
    foreach ($Computer in ($AllComputers | Select-Object -First 5)) {
        $ComputerName = $Computer.Name
        
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
            try {
                $RemotePath = "\\$ComputerName\C$\PatchManagement\Inventory"
                
                if (Test-Path $RemotePath -ErrorAction SilentlyContinue) {
                    $RemoteFiles = Get-ChildItem -Path $RemotePath -Filter "*.json" -ErrorAction SilentlyContinue
                    
                    if ($RemoteFiles.Count -gt 0) {
                        Write-Host "    Found: $ComputerName has $($RemoteFiles.Count) local inventory files" -ForegroundColor Yellow
                        $ClientsWithLocalInventory += $ComputerName
                    }
                }
            } catch {
                # Cannot access, skip silently
            }
        }
    }
    
    if ($ClientsWithLocalInventory.Count -gt 0) {
        Write-Host "`n  Warning: Found local inventory files on client machines!" -ForegroundColor Yellow
        Write-Host "    This means they could not save to the network share" -ForegroundColor Yellow
        Write-Host "    Machines: $($ClientsWithLocalInventory -join ', ')" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "  Warning: Cannot check AD computers: $_" -ForegroundColor Yellow
}

# Summary and Recommendations
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary and Recommendations" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$TotalFiles = 0
if (Test-Path $InventoryShare -ErrorAction SilentlyContinue) {
    $ShareCount = (Get-ChildItem -Path $InventoryShare -Filter "*.json" -Recurse -ErrorAction SilentlyContinue).Count
    $TotalFiles += $ShareCount
}
if (Test-Path $LocalInventoryPath) {
    $LocalCount = (Get-ChildItem -Path $LocalInventoryPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue).Count
    $TotalFiles += $LocalCount
}

Write-Host "Total inventory files found: $TotalFiles" -ForegroundColor Cyan

if ($TotalFiles -eq 0) {
    Write-Host "`nERROR: NO INVENTORY FILES FOUND!" -ForegroundColor Red
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  1. Inventory collection has not been run yet" -ForegroundColor Gray
    Write-Host "  2. Network share permissions are blocking saves" -ForegroundColor Gray
    Write-Host "  3. Client machines do not have network connectivity to share" -ForegroundColor Gray
    Write-Host "  4. Files are being saved with wrong extension or naming" -ForegroundColor Gray
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Run: .\Master-Orchestrator.ps1 -Phase Collect" -ForegroundColor White
    Write-Host "  2. Check share permissions on QBE-DEN-FILE4" -ForegroundColor White
    Write-Host "  3. Manually test: .\Get-ClientInventory.ps1 -CentralServer '$InventoryShare'" -ForegroundColor White
    
} elseif (-not (Test-Path $InventoryShare -ErrorAction SilentlyContinue)) {
    Write-Host "`nERROR: Share is not accessible from this server!" -ForegroundColor Red
    Write-Host "`nFix:" -ForegroundColor Yellow
    Write-Host "  1. Verify share exists: \\qbe-den-qnap\File4\Inventory" -ForegroundColor White
    Write-Host "  2. Check network connectivity to QBE-DEN-FILE4" -ForegroundColor White
    Write-Host "  3. Verify share permissions (read/write for this server)" -ForegroundColor White
    Write-Host "  4. Try accessing in File Explorer: \\qbe-den-qnap\File4\Inventory" -ForegroundColor White
    
} elseif ($ClientsWithLocalInventory.Count -gt 0) {
    Write-Host "`nWARNING: Client machines are saving locally, not to share!" -ForegroundColor Yellow
    Write-Host "`nFix:" -ForegroundColor Yellow
    Write-Host "  1. Check network share permissions for 'Domain Computers'" -ForegroundColor White
    Write-Host "  2. Verify clients can access \\qbe-den-qnap\File4\Inventory" -ForegroundColor White
    Write-Host "  3. Copy local files to share manually, or" -ForegroundColor White
    Write-Host "  4. Run: .\Collect-ClientInventoryFiles.ps1" -ForegroundColor White
    
} else {
    Write-Host "`nSUCCESS: Inventory files found and accessible!" -ForegroundColor Green
    Write-Host "`nFiles are ready for analysis" -ForegroundColor White
}

Write-Host "`n========================================`n" -ForegroundColor Cyan