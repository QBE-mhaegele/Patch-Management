<#
.SYNOPSIS
    Generate Phase Import CSV from Inventory JSONs
    
.DESCRIPTION
    Scans the inventory folder for JSON files and generates a CSV file
    with all server and workstation details ready for phase import.
    
    The output CSV can be edited to assign servers to phases, then imported
    into the Patch Automation tab.

.PARAMETER InventoryPath
    Path to the inventory share containing JSON files
    Default: \\qbe-den-qnap\File4\Inventory

.PARAMETER OutputPath
    Path for the output CSV file
    Default: Current directory\PhaseImport-{timestamp}.csv

.PARAMETER Type
    Filter by machine type: Server, Workstation, or All
    Default: All

.PARAMETER Location
    Filter by location (e.g., DEN, PAR)
    Default: All locations

.PARAMETER IncludeOffline
    Include machines that haven't been inventoried in the last X days
    Default: 30 days

.EXAMPLE
    .\Get-InventoryForPhaseImport.ps1
    
    Generates CSV with all machines from inventory

.EXAMPLE
    .\Get-InventoryForPhaseImport.ps1 -Type Server -Location DEN
    
    Generates CSV with only Denver servers

.EXAMPLE
    .\Get-InventoryForPhaseImport.ps1 -Type Server -OutputPath "C:\PatchManagement\Phase1-Servers.csv"
    
    Generates CSV with all servers to specific path

.NOTES
    Author: QB Energy IT Infrastructure
    Version: 1.0
    Date: February 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InventoryPath = "\\qbe-den-qnap\File4\Inventory",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Server", "Workstation", "All")]
    [string]$Type = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "",
    
    [Parameter(Mandatory=$false)]
    [int]$IncludeOffline = 30
)

# ============================================================
# FUNCTIONS
# ============================================================

function Get-OSFolderName {
    param(
        [string]$OSCaption,
        [string]$BuildNumber
    )
    
    $mapping = @{
        "Windows Server 2022" = "Server2022"
        "Windows Server 2019" = "Server2019"
        "Windows Server 2016" = "Server2016"
        "Windows 11" = "Windows11"
        "Windows 10" = "Windows10"
    }
    
    foreach ($key in $mapping.Keys) {
        if ($OSCaption -match [regex]::Escape($key)) {
            $folder = $mapping[$key]
            
            if ($folder -eq "Windows11") {
                if ([int]$BuildNumber -ge 26100) { return "Windows11-24H2" }
                elseif ([int]$BuildNumber -ge 22631) { return "Windows11-23H2" }
                elseif ([int]$BuildNumber -ge 22621) { return "Windows11-22H2" }
                else { return "Windows11-21H2" }
            }
            elseif ($folder -eq "Windows10") {
                if ([int]$BuildNumber -ge 19045) { return "Windows10-22H2" }
                else { return "Windows10-21H2" }
            }
            
            return $folder
        }
    }
    
    return "Unknown"
}

function Get-MachineTypeFromName {
    param([string]$ComputerName)
    
    # Server naming: QBE-{Location}-{Purpose}
    # Workstation naming: {Location}-{Serial}-{Type}
    
    if ($ComputerName -match "^QBE-") {
        return "Server"
    } else {
        return "Workstation"
    }
}

function Get-LocationFromFolder {
    param([string]$FolderName)
    
    # Folder format: "{Location} - Servers" or "{Location} - Workstations"
    if ($FolderName -match "^([A-Z]+)\s*-\s*(Server|Workstation)") {
        return $Matches[1]
    }
    return "Unknown"
}

# ============================================================
# MAIN SCRIPT
# ============================================================

Write-Host ""
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  QB Energy - Generate Phase Import CSV from Inventory" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Validate inventory path
if (-not (Test-Path $InventoryPath)) {
    Write-Host "ERROR: Inventory path not accessible: $InventoryPath" -ForegroundColor Red
    exit 1
}

Write-Host "Inventory Path: $InventoryPath" -ForegroundColor Gray
Write-Host "Type Filter: $Type" -ForegroundColor Gray
if ($Location) {
    Write-Host "Location Filter: $Location" -ForegroundColor Gray
}
Write-Host "Include machines inventoried within: $IncludeOffline days" -ForegroundColor Gray
Write-Host ""

# Set default output path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $typeLabel = if ($Type -eq "All") { "AllMachines" } else { $Type + "s" }
    $OutputPath = Join-Path (Get-Location) "PhaseImport-$typeLabel-$timestamp.csv"
}

# Get all location folders
$locationFolders = Get-ChildItem -Path $InventoryPath -Directory -ErrorAction SilentlyContinue

if (-not $locationFolders) {
    Write-Host "ERROR: No folders found in inventory path" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning inventory folders..." -ForegroundColor Yellow
Write-Host ""

$machines = @()
$cutoffDate = (Get-Date).AddDays(-$IncludeOffline)

foreach ($folder in $locationFolders) {
    $folderName = $folder.Name
    $folderLocation = Get-LocationFromFolder -FolderName $folderName
    
    # Determine if this is a server or workstation folder
    $isServerFolder = $folderName -match "Server"
    $isWorkstationFolder = $folderName -match "Workstation"
    $folderType = if ($isServerFolder) { "Server" } elseif ($isWorkstationFolder) { "Workstation" } else { "Unknown" }
    
    # Apply type filter
    if ($Type -ne "All") {
        if ($Type -eq "Server" -and -not $isServerFolder) { continue }
        if ($Type -eq "Workstation" -and -not $isWorkstationFolder) { continue }
    }
    
    # Apply location filter
    if ($Location -and $folderLocation -ne $Location) { continue }
    
    Write-Host "  Scanning: $folderName" -ForegroundColor Gray
    
    # Get JSON files in folder
    $jsonFiles = Get-ChildItem -Path $folder.FullName -Filter "*.json" -ErrorAction SilentlyContinue
    
    foreach ($jsonFile in $jsonFiles) {
        try {
            $data = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            
            # Parse collection date
            $collectionDate = $null
            if ($data.CollectionDate) {
                try {
                    $collectionDate = [DateTime]::Parse($data.CollectionDate)
                } catch {
                    $collectionDate = $null
                }
            }
            
            # Skip if too old
            if ($collectionDate -and $collectionDate -lt $cutoffDate) {
                continue
            }
            
            # Extract machine info
            $computerName = $data.ComputerName
            $osCaption = $data.Software.OS.Caption
            $osVersion = $data.Software.OS.Version
            $buildNumber = $data.Software.OS.BuildNumber
            $osFolder = Get-OSFolderName -OSCaption $osCaption -BuildNumber $buildNumber
            
            # Get installed updates count
            $installedUpdates = if ($data.InstalledUpdates) { $data.InstalledUpdates.Count } else { 0 }
            
            # Get last boot time
            $lastBoot = $null
            if ($data.Software.OS.LastBootUpTime) {
                try {
                    # Handle JSON date format /Date(timestamp)/
                    if ($data.Software.OS.LastBootUpTime -match '/Date\((\d+)\)/') {
                        $lastBoot = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc).AddMilliseconds([long]$Matches[1]).ToLocalTime()
                    }
                } catch { }
            }
            
            $machines += [PSCustomObject]@{
                ComputerName = $computerName
                OSFolder = $osFolder
                Location = $folderLocation
                Type = $folderType
                OSCaption = $osCaption
                OSVersion = $osVersion
                BuildNumber = $buildNumber
                CollectionDate = if ($collectionDate) { $collectionDate.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
                LastBoot = if ($lastBoot) { $lastBoot.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
                InstalledUpdates = $installedUpdates
                Phase = ""  # Empty for user to fill in
            }
            
        } catch {
            Write-Host "    Warning: Failed to parse $($jsonFile.Name): $_" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

if ($machines.Count -eq 0) {
    Write-Host "No machines found matching criteria." -ForegroundColor Yellow
    exit 0
}

# Sort machines
$machines = $machines | Sort-Object Type, Location, ComputerName

# Display summary
Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Host "  SUMMARY" -ForegroundColor Green
Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Host ""

$serverCount = ($machines | Where-Object { $_.Type -eq "Server" }).Count
$workstationCount = ($machines | Where-Object { $_.Type -eq "Workstation" }).Count

Write-Host "  Total Machines: $($machines.Count)" -ForegroundColor White
Write-Host "    Servers: $serverCount" -ForegroundColor Gray
Write-Host "    Workstations: $workstationCount" -ForegroundColor Gray
Write-Host ""

# Group by OS
Write-Host "  By Operating System:" -ForegroundColor White
$machines | Group-Object OSFolder | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count)" -ForegroundColor Gray
}
Write-Host ""

# Group by Location
Write-Host "  By Location:" -ForegroundColor White
$machines | Group-Object Location | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count)" -ForegroundColor Gray
}
Write-Host ""

# Export to CSV
try {
    $machines | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "---------------------------------------------------------------" -ForegroundColor Green
    Write-Host "  CSV EXPORTED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Output File: $OutputPath" -ForegroundColor White
    Write-Host ""
    Write-Host "  Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open the CSV in Excel" -ForegroundColor Gray
    Write-Host "  2. Fill in the 'Phase' column (1, 2, 3, etc.)" -ForegroundColor Gray
    Write-Host "  3. Save as CSV" -ForegroundColor Gray
    Write-Host "  4. Import into Patch Automation tab" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Or use the filtered CSVs below for direct import:" -ForegroundColor Yellow
    Write-Host ""
    
    # Also create per-type CSVs for convenience
    if ($Type -eq "All" -and $serverCount -gt 0 -and $workstationCount -gt 0) {
        $basePath = [System.IO.Path]::GetDirectoryName($OutputPath)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
        
        # Servers only
        $serverPath = Join-Path $basePath "$baseName-ServersOnly.csv"
        $machines | Where-Object { $_.Type -eq "Server" } | Export-Csv -Path $serverPath -NoTypeInformation -Encoding UTF8
        Write-Host "  Servers Only: $serverPath" -ForegroundColor Gray
        
        # Workstations only
        $workstationPath = Join-Path $basePath "$baseName-WorkstationsOnly.csv"
        $machines | Where-Object { $_.Type -eq "Workstation" } | Export-Csv -Path $workstationPath -NoTypeInformation -Encoding UTF8
        Write-Host "  Workstations Only: $workstationPath" -ForegroundColor Gray
        Write-Host ""
    }
    
} catch {
    Write-Host "ERROR: Failed to export CSV: $_" -ForegroundColor Red
    exit 1
}

# Display sample of data
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  SAMPLE DATA (First 10 rows)" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

$machines | Select-Object ComputerName, OSFolder, Location, Type, CollectionDate | 
    Select-Object -First 10 | 
    Format-Table -AutoSize

Write-Host ""
Write-Host "Script complete." -ForegroundColor Green