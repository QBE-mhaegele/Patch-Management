# Get-AvailableUpdates.ps1
# Lists available updates in the file repository

param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath = "\\QBE-DEN-WINUP1\Updates$",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "Windows10", "Windows11", "Server2019", "Server2022")]
    [string]$OS = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Month = $null,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportToCSV = $false
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Available Updates in Repository" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test repository access
if (-not (Test-Path $RepositoryPath)) {
    Write-Host "ERROR: Cannot access repository: $RepositoryPath" -ForegroundColor Red
    Write-Host "Please verify:`n  - Network connectivity`n  - Share permissions`n  - VPN connection (if remote)`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "Repository: $RepositoryPath" -ForegroundColor White
Write-Host "OS Filter:  $OS" -ForegroundColor White

if ($Month) {
    Write-Host "Month:      $Month" -ForegroundColor White
}

Write-Host ""

# Define search paths
$SearchPaths = @()

if ($OS -eq "All" -or $OS -eq "Windows10") {
    $SearchPaths += "$RepositoryPath\Windows10\x64\*\*.msu"
}

if ($OS -eq "All" -or $OS -eq "Windows11") {
    $SearchPaths += "$RepositoryPath\Windows11\x64\*\*.msu"
}

if ($OS -eq "All" -or $OS -eq "Server2019") {
    $SearchPaths += "$RepositoryPath\Server2019\*\*.msu"
}

if ($OS -eq "All" -or $OS -eq "Server2022") {
    $SearchPaths += "$RepositoryPath\Server2022\*\*.msu"
}

# Search for .msu files
Write-Host "Scanning repository..." -ForegroundColor Yellow

$Updates = @()

foreach ($Pattern in $SearchPaths) {
    $Files = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue
    
    foreach ($File in $Files) {
        # Extract KB number from filename
        if ($File.Name -match 'KB(\d+)') {
            $KBNumber = "KB$($Matches[1])"
        } else {
            $KBNumber = "Unknown"
        }
        
        # Determine OS from path
        $OSType = "Unknown"
        if ($File.FullName -match '\\Windows10\\') {
            $OSType = "Windows 10 x64"
        } elseif ($File.FullName -match '\\Windows11\\') {
            $OSType = "Windows 11 x64"
        } elseif ($File.FullName -match '\\Server2019\\') {
            $OSType = "Server 2019"
        } elseif ($File.FullName -match '\\Server2022\\') {
            $OSType = "Server 2022"
        }
        
        # Extract month from path
        if ($File.FullName -match '\\(\d{4}-\d{2})\\') {
            $MonthFolder = $Matches[1]
        } else {
            $MonthFolder = "Unknown"
        }
        
        # Filter by month if specified
        if ($Month -and $MonthFolder -ne $Month) {
            continue
        }
        
        # Check for metadata file
        $MetadataPath = $File.FullName.Replace(".msu", ".txt")
        $HasMetadata = Test-Path $MetadataPath
        
        # Get file size
        $SizeMB = [math]::Round($File.Length / 1MB, 2)
        
        # Create update object
        $Update = [PSCustomObject]@{
            KB = $KBNumber
            OS = $OSType
            Month = $MonthFolder
            FileName = $File.Name
            FilePath = $File.FullName
            SizeMB = $SizeMB
            LastModified = $File.LastWriteTime
            HasMetadata = $HasMetadata
        }
        
        $Updates += $Update
    }
}

# Sort by OS, Month, KB
$Updates = $Updates | Sort-Object OS, Month, KB

# Display results
Write-Host ""
Write-Host "Found $($Updates.Count) update(s)`n" -ForegroundColor Green

if ($Updates.Count -eq 0) {
    Write-Host "No updates found matching criteria`n" -ForegroundColor Yellow
    exit 0
}

# Group by OS and Month
$Grouped = $Updates | Group-Object OS, Month

foreach ($Group in $Grouped) {
    $OS = $Group.Group[0].OS
    $Month = $Group.Group[0].Month
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "$OS - $Month" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    foreach ($Update in $Group.Group) {
        $MetadataIndicator = if ($Update.HasMetadata) { "[M]" } else { "   " }
        
        Write-Host "$MetadataIndicator $($Update.KB)" -ForegroundColor White
        Write-Host "    File: $($Update.FileName)" -ForegroundColor Gray
        Write-Host "    Size: $($Update.SizeMB) MB" -ForegroundColor Gray
        Write-Host "    Date: $($Update.LastModified.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        
        # Read metadata if available
        if ($Update.HasMetadata) {
            $MetadataPath = $Update.FilePath.Replace(".msu", ".txt")
            $Metadata = Get-Content $MetadataPath -ErrorAction SilentlyContinue
            
            # Extract title
            $Title = $Metadata | Where-Object { $_ -match '^Title:' } | ForEach-Object { $_ -replace '^Title:\s*', '' }
            if ($Title) {
                Write-Host "    $Title" -ForegroundColor DarkGray
            }
        }
        
        Write-Host ""
    }
}

# Summary by OS
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ByOS = $Updates | Group-Object OS

foreach ($OSGroup in $ByOS) {
    $TotalSize = ($OSGroup.Group | Measure-Object -Property SizeMB -Sum).Sum
    Write-Host "$($OSGroup.Name): $($OSGroup.Count) update(s), $([math]::Round($TotalSize, 2)) MB" -ForegroundColor White
}

$GrandTotalSize = ($Updates | Measure-Object -Property SizeMB -Sum).Sum
Write-Host "Total: $($Updates.Count) update(s), $([math]::Round($GrandTotalSize, 2)) MB" -ForegroundColor Green

Write-Host ""

# Legend
Write-Host "Legend:" -ForegroundColor White
Write-Host "  [M] = Has metadata file" -ForegroundColor Gray
Write-Host ""

# Export to CSV if requested
if ($ExportToCSV) {
    $ExportPath = "C:\PatchManagement\Reports\Available-Updates-$(Get-Date -Format 'yyyyMMdd').csv"
    $ExportDir = Split-Path $ExportPath -Parent
    
    if (-not (Test-Path $ExportDir)) {
        New-Item -Path $ExportDir -ItemType Directory -Force | Out-Null
    }
    
    $Updates | Select-Object KB, OS, Month, FileName, SizeMB, LastModified, HasMetadata | 
        Export-Csv -Path $ExportPath -NoTypeInformation -Force
    
    Write-Host "Exported to: $ExportPath" -ForegroundColor Green
    Write-Host ""
}

# Return updates object for script use
return $Updates
