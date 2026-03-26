<#
.SYNOPSIS
    Collect inventory files from client machines
.DESCRIPTION
    If client machines couldn't save to the network share and saved locally,
    this script collects those files and copies them to the central location.
    
    With -CleanupOldFiles, it removes ALL old inventory files from clients,
    keeping only the newest file per machine (regardless of age).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "\\qbe-den-qnap\File4\Inventory",
    
    [Parameter(Mandatory=$false)]
    [string]$LocalFallbackPath = "C:\PatchManagement\Inventory",
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanupOldFiles
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Collect Inventory Files from Clients" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure destination is accessible
if (-not (Test-Path $DestinationPath -ErrorAction SilentlyContinue)) {
    Write-Host "⚠ Network share not accessible: $DestinationPath" -ForegroundColor Yellow
    Write-Host "Using local fallback: $LocalFallbackPath" -ForegroundColor Yellow
    
    if (-not (Test-Path $LocalFallbackPath)) {
        New-Item -Path $LocalFallbackPath -ItemType Directory -Force | Out-Null
        Write-Host "Created: $LocalFallbackPath" -ForegroundColor Green
    }
    
    $DestinationPath = $LocalFallbackPath
}

# Get computers from AD
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    
    # Load OUs from config file
    $ConfigPath = "C:\PatchManagement\Config\settings.json"
    
    if (Test-Path $ConfigPath) {
        try {
            $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($Config.OUs -and $Config.OUs.Count -gt 0) {
                $OUs = $Config.OUs
                Write-Host "Loaded $($OUs.Count) OU(s) from config file" -ForegroundColor Cyan
            } else {
                # Fallback to default
                $OUs = @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com")
                Write-Host "Config file has no OUs, using default Test OU" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to load config, using default OU" -ForegroundColor Yellow
            $OUs = @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com")
        }
    } else {
        # No config file, use default
        Write-Host "No config file found, using default Test OU" -ForegroundColor Yellow
        $OUs = @("OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com")
    }
    
    $AllComputers = @()
    foreach ($OU in $OUs) {
        Write-Host "Querying OU: $OU" -ForegroundColor Gray
        $Computers = Get-ADComputer -Filter {Enabled -eq $true} -SearchBase $OU -ErrorAction SilentlyContinue
        $AllComputers += $Computers
    }
    
    Write-Host "Found $($AllComputers.Count) computers to check`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Cannot query Active Directory: $_" -ForegroundColor Red
    exit 1
}

$CollectedCount = 0
$FailedCount = 0

foreach ($Computer in $AllComputers) {
    $ComputerName = $Computer.Name
    Write-Host "Checking $ComputerName..." -ForegroundColor Yellow
    
    # Test connectivity
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        Write-Host "  ⚠ Cannot reach (offline)" -ForegroundColor Gray
        continue
    }
    
    # Check for local inventory files
    $RemotePath = "\\$ComputerName\C$\PatchManagement\Inventory"
    
    try {
        if (Test-Path $RemotePath -ErrorAction Stop) {
            $RemoteFiles = Get-ChildItem -Path $RemotePath -Filter "*.json" -ErrorAction Stop
            
            if ($RemoteFiles.Count -gt 0) {
                # Get only the newest file for this computer
                $NewestFile = $RemoteFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                
                Write-Host "  Found $($RemoteFiles.Count) file(s), using newest: $($NewestFile.Name)" -ForegroundColor White
                
                try {
                    $DestFile = Join-Path $DestinationPath $NewestFile.Name
                    
                    # Check if file already exists and is newer
                    if (Test-Path $DestFile) {
                        $ExistingFile = Get-Item $DestFile
                        if ($ExistingFile.LastWriteTime -ge $NewestFile.LastWriteTime) {
                            Write-Host "    ⊘ Already have newer version" -ForegroundColor Gray
                        } else {
                            Copy-Item $NewestFile.FullName -Destination $DestFile -Force -ErrorAction Stop
                            Write-Host "    ✓ Copied (updated)" -ForegroundColor Green
                            $CollectedCount++
                        }
                    } else {
                        Copy-Item $NewestFile.FullName -Destination $DestFile -Force -ErrorAction Stop
                        Write-Host "    ✓ Copied" -ForegroundColor Green
                        $CollectedCount++
                    }
                    
                } catch {
                    Write-Host "    ✗ Failed to copy: $_" -ForegroundColor Red
                    $FailedCount++
                }
            } else {
                Write-Host "  ⊘ No inventory files" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ⊘ No inventory folder" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  ✗ Cannot access C$ share: $_" -ForegroundColor Red
        $FailedCount++
    }
}

# Cleanup old files on clients if requested
if ($CleanupOldFiles) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Cleaning Up Old Files on Clients" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $CleanedCount = 0
    
    foreach ($Computer in $AllComputers) {
        $ComputerName = $Computer.Name
        
        if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            continue
        }
        
        $RemotePath = "\\$ComputerName\C$\PatchManagement\Inventory"
        
        try {
            if (Test-Path $RemotePath -ErrorAction SilentlyContinue) {
                $RemoteFiles = Get-ChildItem -Path $RemotePath -Filter "*.json" -ErrorAction SilentlyContinue
                
                if ($RemoteFiles.Count -gt 1) {
                    # Keep the newest, delete ALL older files (regardless of age)
                    $NewestFile = $RemoteFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $OldFiles = $RemoteFiles | Where-Object {$_.FullName -ne $NewestFile.FullName}
                    
                    Write-Host "  Found $($RemoteFiles.Count) files, keeping newest, deleting $($OldFiles.Count)" -ForegroundColor Gray
                    
                    foreach ($OldFile in $OldFiles) {
                        try {
                            Remove-Item $OldFile.FullName -Force -ErrorAction Stop
                            Write-Host "    ✓ Deleted: $($OldFile.Name)" -ForegroundColor DarkGray
                            $CleanedCount++
                        } catch {
                            Write-Host "    ✗ Failed to delete: $($OldFile.Name) - $_" -ForegroundColor Red
                        }
                    }
                }
            }
        } catch {
            # Skip if can't access
        }
    }
    
    Write-Host "`nCleaned up $CleanedCount old file(s)" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Collection Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Files collected: $CollectedCount" -ForegroundColor $(if ($CollectedCount -gt 0) {"Green"} else {"Yellow"})
Write-Host "Failed: $FailedCount" -ForegroundColor $(if ($FailedCount -gt 0) {"Red"} else {"Green"})
Write-Host "Destination: $DestinationPath" -ForegroundColor Cyan

if ($CleanupOldFiles) {
    Write-Host "Old files cleaned: $CleanedCount" -ForegroundColor Cyan
}

if ($CollectedCount -gt 0) {
    Write-Host "`n✓ You can now run analysis:" -ForegroundColor Green
    Write-Host "  .\Master-Orchestrator.ps1 -Phase Analyze" -ForegroundColor White
}

Write-Host "`nTip: Use -CleanupOldFiles to remove old inventory files from clients" -ForegroundColor Gray
Write-Host "     (keeps only the newest file per machine)" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan
