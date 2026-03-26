# Configure-WSUS-ClientGPO.ps1
# Configure Group Policy for WSUS clients

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$WSUSServer = "QBE-DEN-WINUP1",
    
    [Parameter(Mandatory=$false)]
    [int]$WSUSPort = 8530,
    
    [Parameter(Mandatory=$false)]
    [string]$GPOName = "WSUS Client Configuration",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetOU = $null  # Leave null to link to domain root
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "WSUS Client GPO Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if Group Policy module is available
if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
    Write-Host "ERROR: Group Policy module not available" -ForegroundColor Red
    Write-Host "Install RSAT tools: Add-WindowsFeature RSAT-AD-PowerShell`n" -ForegroundColor Yellow
    
    Write-Host "Manual GPO Configuration Steps:" -ForegroundColor Yellow
    Write-Host "================================`n" -ForegroundColor Yellow
    
    Write-Host "1. Open Group Policy Management (gpmc.msc)" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Create new GPO: '$GPOName'" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Edit GPO and navigate to:" -ForegroundColor White
    Write-Host "   Computer Configuration > Policies > Administrative Templates" -ForegroundColor Gray
    Write-Host "   > Windows Components > Windows Update" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Configure these settings:" -ForegroundColor White
    Write-Host ""
    Write-Host "   [REQUIRED SETTINGS]" -ForegroundColor Cyan
    Write-Host "   a) Specify intranet Microsoft update service location" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host "      Intranet update service: http://$WSUSServer`:$WSUSPort" -ForegroundColor Gray
    Write-Host "      Intranet statistics server: http://$WSUSServer`:$WSUSPort" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   b) Configure Automatic Updates" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host "      Configure automatic updating: 4 - Auto download and schedule install" -ForegroundColor Gray
    Write-Host "      Scheduled install day: 0 - Every day" -ForegroundColor Gray
    Write-Host "      Scheduled install time: 03:00" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   [RECOMMENDED SETTINGS]" -ForegroundColor Cyan
    Write-Host "   c) Automatic Updates detection frequency" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host "      Check for updates every: 4 hours" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   d) Allow non-administrators to receive update notifications" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   e) No auto-restart with logged on users for scheduled installations" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   f) Re-prompt for restart with scheduled installations" -ForegroundColor White
    Write-Host "      Status: Enabled" -ForegroundColor Gray
    Write-Host "      Wait time: 30 minutes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Link GPO to appropriate OU" -ForegroundColor White
    Write-Host ""
    Write-Host "6. Force Group Policy update on client:" -ForegroundColor White
    Write-Host "   gpupdate /force" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "7. Verify client is configured:" -ForegroundColor White
    Write-Host "   reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "8. Force WSUS check-in:" -ForegroundColor White
    Write-Host "   wuauclt /detectnow /reportnow" -ForegroundColor Cyan
    Write-Host ""
    
    exit 0
}

# Import Group Policy module
Import-Module GroupPolicy -ErrorAction Stop

Write-Host "WSUS Server: http://$WSUSServer`:$WSUSPort" -ForegroundColor White
Write-Host "GPO Name: $GPOName`n" -ForegroundColor White

# Check if GPO already exists
Write-Host "Checking for existing GPO..." -ForegroundColor Yellow

$ExistingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue

if ($ExistingGPO) {
    Write-Host "  GPO already exists: $GPOName" -ForegroundColor Yellow
    $Overwrite = Read-Host "  Overwrite existing GPO? (Y/N)"
    
    if ($Overwrite -ne "Y" -and $Overwrite -ne "y") {
        Write-Host "`nOperation cancelled`n" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "  Using existing GPO" -ForegroundColor Green
    $GPO = $ExistingGPO
} else {
    Write-Host "  Creating new GPO..." -ForegroundColor White
    
    try {
        $GPO = New-GPO -Name $GPOName -Comment "Configures Windows Update clients to use WSUS server $WSUSServer"
        Write-Host "  Created: $GPOName" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to create GPO - $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Configure WSUS server location
Write-Host "Configuring GPO settings..." -ForegroundColor Yellow

$WSUSServerURL = "http://$WSUSServer`:$WSUSPort"

try {
    # Set intranet update service location
    Write-Host "  [1/8] Setting WSUS server location..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
        -ValueName "WUServer" -Type String -Value $WSUSServerURL | Out-Null
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
        -ValueName "WUStatusServer" -Type String -Value $WSUSServerURL | Out-Null
    
    Write-Host "    Server: $WSUSServerURL" -ForegroundColor Gray
    
    # Enable client-side targeting
    Write-Host "  [2/8] Enabling client-side targeting..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
        -ValueName "TargetGroupEnabled" -Type DWord -Value 1 | Out-Null
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
        -ValueName "TargetGroup" -Type String -Value "All Computers" | Out-Null
    
    Write-Host "    Target Group: All Computers" -ForegroundColor Gray
    
    # Configure Automatic Updates
    Write-Host "  [3/8] Configuring Automatic Updates..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "UseWUServer" -Type DWord -Value 1 | Out-Null
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "AUOptions" -Type DWord -Value 4 | Out-Null  # 4 = Auto download and schedule install
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "ScheduledInstallDay" -Type DWord -Value 0 | Out-Null  # 0 = Every day
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "ScheduledInstallTime" -Type DWord -Value 3 | Out-Null  # 3 AM
    
    Write-Host "    Mode: Auto download and schedule install" -ForegroundColor Gray
    Write-Host "    Schedule: Daily at 3:00 AM" -ForegroundColor Gray
    
    # Set detection frequency
    Write-Host "  [4/8] Setting update detection frequency..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "DetectionFrequencyEnabled" -Type DWord -Value 1 | Out-Null
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "DetectionFrequency" -Type DWord -Value 4 | Out-Null  # Check every 4 hours
    
    Write-Host "    Check for updates every: 4 hours" -ForegroundColor Gray
    
    # Allow non-admin notifications
    Write-Host "  [5/8] Allowing non-admin update notifications..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "ElevateNonAdmins" -Type DWord -Value 1 | Out-Null
    
    Write-Host "    Non-admins can see notifications" -ForegroundColor Gray
    
    # No auto-restart with logged on users
    Write-Host "  [6/8] Configuring restart behavior..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1 | Out-Null
    
    Write-Host "    No auto-restart with logged on users" -ForegroundColor Gray
    
    # Re-prompt for restart
    Write-Host "  [7/8] Configuring restart prompts..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "RebootRelaunchTimeoutEnabled" -Type DWord -Value 1 | Out-Null
    
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "RebootRelaunchTimeout" -Type DWord -Value 30 | Out-Null  # 30 minutes
    
    Write-Host "    Re-prompt every: 30 minutes" -ForegroundColor Gray
    
    # Disable Windows Update access
    Write-Host "  [8/8] Disabling direct Windows Update access..." -ForegroundColor White
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" `
        -ValueName "NoWindowsUpdateAccess" -Type DWord -Value 0 | Out-Null  # 0 = Allow access (for status)
    
    Write-Host "    Users can view update status" -ForegroundColor Gray
    
    Write-Host "`n  GPO configured successfully" -ForegroundColor Green
    
} catch {
    Write-Host "`n  ERROR: Failed to configure GPO - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Link GPO
Write-Host "Linking GPO..." -ForegroundColor Yellow

if ($TargetOU) {
    Write-Host "  Target OU: $TargetOU" -ForegroundColor White
    
    try {
        New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -ErrorAction Stop | Out-Null
        Write-Host "  GPO linked to OU" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*already linked*") {
            Write-Host "  GPO already linked to OU" -ForegroundColor Gray
        } else {
            Write-Host "  ERROR: Failed to link GPO - $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  Target: Domain root" -ForegroundColor White
    
    try {
        $Domain = Get-ADDomain
        $DomainDN = $Domain.DistinguishedName
        
        New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes -ErrorAction Stop | Out-Null
        Write-Host "  GPO linked to domain root" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*already linked*") {
            Write-Host "  GPO already linked to domain" -ForegroundColor Gray
        } else {
            Write-Host "  WARNING: Could not link GPO automatically - $_" -ForegroundColor Yellow
            Write-Host "  Please link GPO manually using gpmc.msc" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GPO Configuration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "GPO Details:" -ForegroundColor White
Write-Host "  Name: $GPOName" -ForegroundColor Gray
Write-Host "  WSUS Server: $WSUSServerURL" -ForegroundColor Gray
Write-Host "  Update Schedule: Daily at 3:00 AM" -ForegroundColor Gray
Write-Host "  Detection Frequency: Every 4 hours" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Wait for Group Policy to apply (may take 90 minutes)" -ForegroundColor Gray
Write-Host "     Or force on client: gpupdate /force" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Verify GPO applied on client:" -ForegroundColor Gray
Write-Host "     gpresult /r /scope:computer" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Check WSUS server registry on client:" -ForegroundColor Gray
Write-Host "     reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. Force client to report to WSUS:" -ForegroundColor Gray
Write-Host "     wuauclt /detectnow /reportnow" -ForegroundColor Cyan
Write-Host ""
Write-Host "  5. Verify in WSUS console (may take 24 hours):" -ForegroundColor Gray
Write-Host "     updateservices.msc" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================`n" -ForegroundColor Cyan

# Create verification script
$VerifyScriptPath = "C:\PatchManagement\Scripts\Verify-WSUSClient.ps1"

$VerifyScript = @"
# Verify-WSUSClient.ps1
# Verify WSUS client configuration

Write-Host "`nWSUS Client Verification`n" -ForegroundColor Cyan

# Check registry settings
`$WUServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -ErrorAction SilentlyContinue).WUServer

if (`$WUServer) {
    Write-Host "WSUS Server: `$WUServer" -ForegroundColor Green
} else {
    Write-Host "WSUS Server: Not configured" -ForegroundColor Red
}

# Check last detection time
`$LastDetection = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect" -Name LastSuccessTime -ErrorAction SilentlyContinue).LastSuccessTime

if (`$LastDetection) {
    Write-Host "Last Detection: `$LastDetection" -ForegroundColor Green
} else {
    Write-Host "Last Detection: Never" -ForegroundColor Yellow
}

# Force detection
Write-Host "`nForcing update detection..." -ForegroundColor Yellow
`$WUService = Get-Service wuauserv
if (`$WUService.Status -ne "Running") {
    Start-Service wuauserv
}

wuauclt /detectnow /reportnow

Write-Host "Check WSUS console in 5-10 minutes`n" -ForegroundColor Gray
"@

try {
    $VerifyScript | Out-File -FilePath $VerifyScriptPath -Encoding UTF8 -Force
    Write-Host "Created client verification script:" -ForegroundColor Green
    Write-Host "  $VerifyScriptPath`n" -ForegroundColor Gray
} catch {
    # Silent fail
}
