# Integrate-WSUS-PatchManagement.ps1
# Integrate WSUS server with existing Patch Management system

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$WSUSServer = "QBE-DEN-WINUP1",
    
    [Parameter(Mandatory=$false)]
    [int]$WSUSPort = 8530,
    
    [Parameter(Mandatory=$false)]
    [string]$PatchManagementPath = "C:\PatchManagement"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "WSUS Integration - Patch Management" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "WSUS Server: $WSUSServer`:$WSUSPort" -ForegroundColor White
Write-Host "Patch Management Path: $PatchManagementPath`n" -ForegroundColor White

# Verify WSUS server is accessible
Write-Host "[1/6] Testing WSUS server connection..." -ForegroundColor Yellow

try {
    $TestWSUS = Get-WsusServer -Name $WSUSServer -PortNumber $WSUSPort -ErrorAction Stop
    Write-Host "  Connected to WSUS server successfully" -ForegroundColor Green
    Write-Host "  Server: $($TestWSUS.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($TestWSUS.Version)" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Cannot connect to WSUS server - $_" -ForegroundColor Red
    Write-Host "  Please verify WSUS is installed and running`n" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Verify patch management directory exists
Write-Host "[2/6] Verifying Patch Management installation..." -ForegroundColor Yellow

if (-not (Test-Path $PatchManagementPath)) {
    Write-Host "  ERROR: Patch Management not found at $PatchManagementPath" -ForegroundColor Red
    exit 1
}

$ScriptsPath = Join-Path $PatchManagementPath "Scripts"
$ConfigPath = Join-Path $PatchManagementPath "Config"

if (-not (Test-Path $ScriptsPath)) {
    Write-Host "  ERROR: Scripts directory not found" -ForegroundColor Red
    exit 1
}

Write-Host "  Patch Management found" -ForegroundColor Green
Write-Host "  Scripts: $ScriptsPath" -ForegroundColor Gray

# Create Config directory if needed
if (-not (Test-Path $ConfigPath)) {
    New-Item -Path $ConfigPath -ItemType Directory -Force | Out-Null
    Write-Host "  Created: $ConfigPath" -ForegroundColor Green
}

Write-Host ""

# Create WSUS configuration file
Write-Host "[3/6] Creating WSUS configuration..." -ForegroundColor Yellow

$ConfigFile = Join-Path $ConfigPath "WSUS-Config.xml"

$ConfigXML = @"
<?xml version="1.0" encoding="utf-8"?>
<WSUSConfiguration>
    <Server>$WSUSServer</Server>
    <Port>$WSUSPort</Port>
    <UseSSL>false</UseSSL>
    <Enabled>true</Enabled>
    <LastUpdated>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</LastUpdated>
</WSUSConfiguration>
"@

try {
    $ConfigXML | Out-File -FilePath $ConfigFile -Encoding UTF8 -Force
    Write-Host "  Created: $ConfigFile" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create config file - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Backup existing scripts
Write-Host "[4/6] Backing up existing scripts..." -ForegroundColor Yellow

$BackupDate = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $PatchManagementPath "Backup\Pre-WSUS-Integration_$BackupDate"

try {
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    }
    
    $ScriptsToBackup = @(
        "Collect-PendingUpdates.ps1",
        "Deploy-WindowsUpdates.ps1",
        "PatchManagement-GUI.ps1"
    )
    
    foreach ($Script in $ScriptsToBackup) {
        $SourceFile = Join-Path $ScriptsPath $Script
        if (Test-Path $SourceFile) {
            Copy-Item -Path $SourceFile -Destination $BackupPath -Force
            Write-Host "  Backed up: $Script" -ForegroundColor Green
        }
    }
    
    Write-Host "  Backup location: $BackupPath" -ForegroundColor Gray
    
} catch {
    Write-Host "  WARNING: Backup failed - $_" -ForegroundColor Yellow
    Write-Host "  Continuing with integration..." -ForegroundColor Gray
}

Write-Host ""

# Create WSUS helper functions module
Write-Host "[5/6] Creating WSUS helper module..." -ForegroundColor Yellow

$ModulePath = Join-Path $ScriptsPath "WSUS-Functions.psm1"

$ModuleContent = @'
# WSUS-Functions.psm1
# Helper functions for WSUS integration

function Get-WSUSServerConfig {
    $ConfigFile = "C:\PatchManagement\Config\WSUS-Config.xml"
    
    if (-not (Test-Path $ConfigFile)) {
        throw "WSUS configuration not found: $ConfigFile"
    }
    
    [xml]$Config = Get-Content $ConfigFile
    
    return [PSCustomObject]@{
        Server = $Config.WSUSConfiguration.Server
        Port = [int]$Config.WSUSConfiguration.Port
        UseSSL = [bool]::Parse($Config.WSUSConfiguration.UseSSL)
        Enabled = [bool]::Parse($Config.WSUSConfiguration.Enabled)
    }
}

function Connect-WSUSServer {
    param(
        [string]$ServerName,
        [int]$Port = 8530
    )
    
    try {
        $WSUSServer = Get-WsusServer -Name $ServerName -PortNumber $Port -ErrorAction Stop
        return $WSUSServer
    } catch {
        throw "Cannot connect to WSUS server ${ServerName}:${Port} - $_"
    }
}

function Get-WSUSUpdatesForComputer {
    param(
        [string]$ComputerName,
        [string]$WSUSServerName = "QBE-DEN-WINUP1",
        [int]$Port = 8530
    )
    
    try {
        $WSUSServer = Connect-WSUSServer -ServerName $WSUSServerName -Port $Port
        
        # Find computer in WSUS
        $ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
        $ComputerScope.NameIncludes = $ComputerName
        
        $Computers = $WSUSServer.GetComputerTargets($ComputerScope)
        
        if ($Computers.Count -eq 0) {
            return @{
                Found = $false
                Error = "Computer not found in WSUS"
                Updates = @()
            }
        }
        
        $Computer = $Computers[0]
        
        # Get update status
        $UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        $UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::Any
        
        $UpdatesNeeded = $Computer.GetUpdateInstallationInfoPerUpdate($UpdateScope) | 
            Where-Object { $_.UpdateInstallationState -eq "NotInstalled" -or 
                           $_.UpdateInstallationState -eq "Downloaded" }
        
        $UpdateList = @()
        foreach ($UpdateInfo in $UpdatesNeeded) {
            $Update = $WSUSServer.GetUpdate([guid]$UpdateInfo.UpdateId)
            
            $UpdateList += [PSCustomObject]@{
                Title = $Update.Title
                KB = if ($Update.KnowledgebaseArticles.Count -gt 0) { "KB$($Update.KnowledgebaseArticles[0])" } else { "N/A" }
                Classification = $Update.UpdateClassificationTitle
                IsApproved = $Update.IsApproved
                IsSuperseded = $Update.IsSuperseded
                InstallationState = $UpdateInfo.UpdateInstallationState
                ArrivalDate = $Update.ArrivalDate
            }
        }
        
        return @{
            Found = $true
            ComputerName = $Computer.FullDomainName
            LastSync = $Computer.LastSyncTime
            UpdatesNeeded = $UpdateList.Count
            Updates = $UpdateList
        }
        
    } catch {
        return @{
            Found = $false
            Error = $_.Exception.Message
            Updates = @()
        }
    }
}

function Get-WSUSComputerGroups {
    param(
        [string]$WSUSServerName = "QBE-DEN-WINUP1",
        [int]$Port = 8530
    )
    
    try {
        $WSUSServer = Connect-WSUSServer -ServerName $WSUSServerName -Port $Port
        $Groups = $WSUSServer.GetComputerTargetGroups()
        
        return $Groups | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                ID = $_.Id
                ComputerCount = $_.GetComputerTargets().Count
            }
        }
    } catch {
        throw "Failed to get computer groups: $_"
    }
}

Export-ModuleMember -Function Get-WSUSServerConfig, Connect-WSUSServer, Get-WSUSUpdatesForComputer, Get-WSUSComputerGroups
'@

try {
    $ModuleContent | Out-File -FilePath $ModulePath -Encoding UTF8 -Force
    Write-Host "  Created: WSUS-Functions.psm1" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create module - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Create WSUS-enabled collection script
Write-Host "[6/6] Creating WSUS collection scripts..." -ForegroundColor Yellow

$CollectWSUSScript = Join-Path $ScriptsPath "Collect-PendingUpdates-WSUS.ps1"

$CollectScriptContent = @'
# Collect-PendingUpdates-WSUS.ps1
# Collect pending updates from WSUS for a computer

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

# Import WSUS functions
Import-Module "$PSScriptRoot\WSUS-Functions.psm1" -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Collect Pending Updates (WSUS)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Computer: $ComputerName`n" -ForegroundColor White

# Get WSUS configuration
try {
    $WSUSConfig = Get-WSUSServerConfig
    Write-Host "WSUS Server: $($WSUSConfig.Server):$($WSUSConfig.Port)" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: WSUS not configured - $_" -ForegroundColor Red
    Write-Host "Run: .\Integrate-WSUS-PatchManagement.ps1`n" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Get updates from WSUS
Write-Host "Querying WSUS server..." -ForegroundColor Yellow

$Result = Get-WSUSUpdatesForComputer -ComputerName $ComputerName `
    -WSUSServerName $WSUSConfig.Server -Port $WSUSConfig.Port

if (-not $Result.Found) {
    Write-Host "  ERROR: $($Result.Error)" -ForegroundColor Red
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  - Computer hasn't reported to WSUS yet" -ForegroundColor Gray
    Write-Host "  - Computer name mismatch" -ForegroundColor Gray
    Write-Host "  - Group Policy not configured`n" -ForegroundColor Gray
    exit 1
}

Write-Host "  Computer found in WSUS" -ForegroundColor Green
Write-Host "  Full Name: $($Result.ComputerName)" -ForegroundColor Gray
Write-Host "  Last Sync: $($Result.LastSync)" -ForegroundColor Gray
Write-Host ""

# Display results
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pending Updates: $($Result.UpdatesNeeded)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($Result.UpdatesNeeded -eq 0) {
    Write-Host "No pending updates found`n" -ForegroundColor Green
    exit 0
}

# Group by classification
$ByClassification = $Result.Updates | Group-Object Classification

foreach ($Group in $ByClassification) {
    Write-Host "$($Group.Name): $($Group.Count)" -ForegroundColor White
    foreach ($Update in $Group.Group) {
        $ApprovedText = if ($Update.IsApproved) { "[APPROVED]" } else { "[NOT APPROVED]" }
        $Color = if ($Update.IsApproved) { "Green" } else { "Yellow" }
        
        Write-Host "  $ApprovedText $($Update.KB)" -ForegroundColor $Color
        Write-Host "    $($Update.Title)" -ForegroundColor Gray
        Write-Host "    State: $($Update.InstallationState)" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "========================================`n" -ForegroundColor Cyan

# Export to CSV
$ExportPath = "C:\PatchManagement\Reports\Pending-Updates-$ComputerName-$(Get-Date -Format 'yyyyMMdd').csv"
$ExportDir = Split-Path $ExportPath -Parent

if (-not (Test-Path $ExportDir)) {
    New-Item -Path $ExportDir -ItemType Directory -Force | Out-Null
}

$Result.Updates | Export-Csv -Path $ExportPath -NoTypeInformation -Force
Write-Host "Report exported to: $ExportPath`n" -ForegroundColor Gray
'@

try {
    $CollectScriptContent | Out-File -FilePath $CollectWSUSScript -Encoding UTF8 -Force
    Write-Host "  Created: Collect-PendingUpdates-WSUS.ps1" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create collection script - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Integration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "WSUS Configuration:" -ForegroundColor White
Write-Host "  Server: $WSUSServer`:$WSUSPort" -ForegroundColor Gray
Write-Host "  Config File: $ConfigFile" -ForegroundColor Gray
Write-Host "  Module: WSUS-Functions.psm1" -ForegroundColor Gray
Write-Host ""

Write-Host "New Scripts Created:" -ForegroundColor White
Write-Host "  - Collect-PendingUpdates-WSUS.ps1" -ForegroundColor Gray
Write-Host ""

Write-Host "Backup Location:" -ForegroundColor White
Write-Host "  $BackupPath" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Configure Group Policy to point clients to WSUS:" -ForegroundColor White
Write-Host "   Server: http://$WSUSServer`:$WSUSPort" -ForegroundColor Cyan
Write-Host "   GPO Path: Computer Config > Policies > Administrative Templates" -ForegroundColor Gray
Write-Host "            > Windows Components > Windows Update" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Test WSUS collection:" -ForegroundColor White
Write-Host "   .\Collect-PendingUpdates-WSUS.ps1 -ComputerName QBE-DEN-TSGW1" -ForegroundColor Cyan
Write-Host ""

Write-Host "3. Wait for clients to report (may take 24 hours)" -ForegroundColor White
Write-Host "   Or force client update: wuauclt /detectnow /reportnow" -ForegroundColor Cyan
Write-Host ""

Write-Host "4. Configure automatic approval rules:" -ForegroundColor White
Write-Host "   .\Configure-WSUS-Approval.ps1" -ForegroundColor Cyan
Write-Host ""

Write-Host "5. Update Patch Management GUI (optional)" -ForegroundColor White
Write-Host "   Add WSUS tab for central management" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================`n" -ForegroundColor Cyan
