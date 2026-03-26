<#
.SYNOPSIS
    Download cumulative updates using PSWindowsUpdate module
.DESCRIPTION
    Simpler, more reliable method using the PSWindowsUpdate PowerShell module
    to query and download cumulative updates from Microsoft.
.PARAMETER Products
    Which products to download (default: all)
.PARAMETER DownloadPath  
    Where to save files (default: D:\UpdateFiles)
.PARAMETER InstallModule
    Install PSWindowsUpdate module if not present
.EXAMPLE
    .\Download-CumulativeUpdates-Simple.ps1 -InstallModule
.EXAMPLE
    .\Download-CumulativeUpdates-Simple.ps1 -Products Windows10,Windows11
.NOTES
    Version: 1.0
    Uses: PSWindowsUpdate module (more reliable than web scraping)
    Requires: Administrator, Internet connection
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Windows10", "Windows11", "Server2019", "Server2022", "All")]
    [string[]]$Products = @("All"),
    
    [Parameter()]
    [string]$DownloadPath = "D:\UpdateFiles",
    
    [Parameter()]
    [switch]$InstallModule
)

#Requires -RunAsAdministrator

# ============================================================
# MODULE INSTALLATION
# ============================================================

function Install-PSWindowsUpdateModule {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Installing PSWindowsUpdate Module" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Check if already installed
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Write-Host "PSWindowsUpdate module already installed" -ForegroundColor Green
        return $true
    }
    
    try {
        Write-Host "Installing PSWindowsUpdate from PowerShell Gallery..." -ForegroundColor Yellow
        
        # Trust PSGallery
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        
        # Install module
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
        
        Write-Host "Module installed successfully!`n" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to install module: $_" -ForegroundColor Red
        Write-Host "`nManual installation:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name PSWindowsUpdate -Force" -ForegroundColor Gray
        return $false
    }
}

# ============================================================
# DOWNLOAD FUNCTIONS
# ============================================================

function Get-CumulativeUpdatesForProduct {
    param(
        [string]$ProductFilter,
        [string]$TargetPath,
        [string]$Month = (Get-Date -Format "yyyy-MM")
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Searching for: $ProductFilter" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    try {
        # Query Windows Update for cumulative updates
        $Updates = Get-WindowsUpdate -MicrosoftUpdate |
            Where-Object {
                $_.Title -match "Cumulative" -and
                $_.Title -notmatch "Preview" -and
                $_.Title -match $ProductFilter
            } |
            Sort-Object LastDeploymentChangeTime -Descending |
            Select-Object -First 1
        
        if (-not $Updates) {
            Write-Host "No cumulative updates found for $ProductFilter" -ForegroundColor Yellow
            return @()
        }
        
        $DownloadedFiles = @()
        
        foreach ($Update in @($Updates)) {
            Write-Host "Found: $($Update.Title)" -ForegroundColor Green
            Write-Host "  KB: $($Update.KB)" -ForegroundColor Gray
            Write-Host "  Size: $([math]::Round($Update.Size/1MB, 2)) MB" -ForegroundColor Gray
            Write-Host "  Date: $($Update.LastDeploymentChangeTime)" -ForegroundColor Gray
            
            # Determine folder
            $FolderName = switch -Regex ($ProductFilter) {
                "Windows 10" { "Windows10" }
                "Windows 11" { "Windows11" }
                "Server 2019" { "Server2019" }
                "Server 2022" { "Server2022" }
                default { "Unknown" }
            }
            
            $DestPath = Join-Path $TargetPath "$FolderName\$Month"
            
            # Create destination
            if (-not (Test-Path $DestPath)) {
                New-Item -Path $DestPath -ItemType Directory -Force | Out-Null
            }
            
            # Download using Windows Update downloader
            Write-Host "`n  Downloading..." -ForegroundColor Yellow
            
            $Result = Get-WindowsUpdate -MicrosoftUpdate -UpdateID $Update.UpdateID -Download -AcceptAll
            
            if ($Result) {
                Write-Host "  Downloaded successfully!`n" -ForegroundColor Green
                
                # Note: PSWindowsUpdate downloads to Windows Update cache
                # We need to extract the .msu file
                $CacheFiles = Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -Recurse -Filter "*.msu" -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-10) } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                
                if ($CacheFiles) {
                    $DestFile = Join-Path $DestPath "KB$($Update.KB).msu"
                    Copy-Item -Path $CacheFiles.FullName -Destination $DestFile -Force
                    
                    $DownloadedFiles += [PSCustomObject]@{
                        Product = $FolderName
                        KB = "KB$($Update.KB)"
                        Title = $Update.Title
                        FilePath = $DestFile
                        SizeMB = [math]::Round((Get-Item $DestFile).Length / 1MB, 2)
                    }
                }
            }
        }
        
        return $DownloadedFiles
    }
    catch {
        Write-Host "Error searching for updates: $_" -ForegroundColor Red
        return @()
    }
}

# ============================================================
# MAIN
# ============================================================

# Install module if requested
if ($InstallModule) {
    $Installed = Install-PSWindowsUpdateModule
    if (-not $Installed) {
        exit 1
    }
}

# Check if module is available
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "`nERROR: PSWindowsUpdate module not found" -ForegroundColor Red
    Write-Host "Install it with: .\Download-CumulativeUpdates-Simple.ps1 -InstallModule`n" -ForegroundColor Yellow
    exit 1
}

# Import module
Import-Module PSWindowsUpdate -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "QB Energy - Cumulative Update Downloader" -ForegroundColor Cyan
Write-Host "Using PSWindowsUpdate Module" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Expand "All" to all products
if ($Products -contains "All") {
    $Products = @("Windows10", "Windows11", "Server2019", "Server2022")
}

# Product search terms
$ProductFilters = @{
    "Windows10" = "Windows 10"
    "Windows11" = "Windows 11"  
    "Server2019" = "Windows Server 2019"
    "Server2022" = "Windows Server 2022"
}

$AllDownloads = @()

# Download for each product
foreach ($Product in $Products) {
    $Filter = $ProductFilters[$Product]
    
    if ($Filter) {
        $Downloads = Get-CumulativeUpdatesForProduct -ProductFilter $Filter -TargetPath $DownloadPath
        $AllDownloads += $Downloads
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DOWNLOAD SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($AllDownloads.Count -gt 0) {
    Write-Host "Total files downloaded: $($AllDownloads.Count)`n" -ForegroundColor Green
    
    foreach ($File in $AllDownloads) {
        Write-Host "  [$($File.Product)] $($File.KB) - $($File.SizeMB) MB" -ForegroundColor Green
        Write-Host "    $($File.FilePath)" -ForegroundColor Gray
    }
    
    Write-Host "`nFiles ready for deployment!" -ForegroundColor Green
}
else {
    Write-Host "No updates downloaded" -ForegroundColor Yellow
}

Write-Host ""
