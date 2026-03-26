<#
.SYNOPSIS
    Collects hardware and software inventory from local machine
.DESCRIPTION
    Gathers comprehensive system information for patch compatibility analysis
    Reports back to central server via file share or saves locally
.NOTES
    Deploy via GPO or run remotely via Invoke-Command
    Requires local admin rights for complete hardware enumeration
    Author: QB Energy IT Infrastructure Team
    Version: 1.0
    Date: January 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$CentralServer = "\\qbe-den-qnap\File4\Inventory",
    
    [Parameter(Mandatory=$false)]
    [string]$LocalFallbackPath = "C:\PatchManagement\Inventory",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeInstalledSoftware,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedDriverInfo
)

# Initialize inventory object
$inventory = @{
    CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $env:COMPUTERNAME
    Domain = $env:USERDOMAIN
    Hardware = @{}
    Software = @{}
    Configuration = @{}
    InstalledUpdates = @()
}

Write-Host "Collecting inventory for $($env:COMPUTERNAME)..." -ForegroundColor Cyan

# === HARDWARE INFORMATION ===
Write-Host "  Gathering hardware info..." -ForegroundColor Gray

# Computer System Info
$computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
if ($computerInfo) {
    $inventory.Hardware.Manufacturer = $computerInfo.CsManufacturer
    $inventory.Hardware.Model = $computerInfo.CsModel
    $inventory.Hardware.TotalPhysicalMemoryGB = [math]::Round($computerInfo.CsTotalPhysicalMemory / 1GB, 2)
    $inventory.Hardware.NumberOfProcessors = $computerInfo.CsNumberOfProcessors
    $inventory.Hardware.NumberOfLogicalProcessors = $computerInfo.CsNumberOfLogicalProcessors
}

# CPU Information
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$inventory.Hardware.CPU = @{
    Name = $cpu.Name
    Manufacturer = $cpu.Manufacturer
    MaxClockSpeed = $cpu.MaxClockSpeed
    NumberOfCores = $cpu.NumberOfCores
    NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
    Architecture = $cpu.Architecture
}

# BIOS/UEFI Information
$bios = Get-WmiObject Win32_BIOS
$inventory.Hardware.BIOS = @{
    Manufacturer = $bios.Manufacturer
    Version = $bios.SMBIOSBIOSVersion
    ReleaseDate = $bios.ReleaseDate
    SerialNumber = $bios.SerialNumber
}

# Disk Controllers (Important for boot issues)
$diskControllers = Get-WmiObject Win32_SCSIController
$inventory.Hardware.DiskControllers = @()
foreach ($controller in $diskControllers) {
    $inventory.Hardware.DiskControllers += @{
        Name = $controller.Name
        Manufacturer = $controller.Manufacturer
        DriverVersion = $controller.DriverVersion
        DeviceID = $controller.DeviceID
    }
}

# Physical Disks
$physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
$inventory.Hardware.PhysicalDisks = @()
foreach ($disk in $physicalDisks) {
    $inventory.Hardware.PhysicalDisks += @{
        FriendlyName = $disk.FriendlyName
        MediaType = $disk.MediaType
        BusType = $disk.BusType
        SizeGB = [math]::Round($disk.Size / 1GB, 2)
    }
}

# Network Adapters
$netAdapters = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
$inventory.Hardware.NetworkAdapters = @()
foreach ($adapter in $netAdapters) {
    $inventory.Hardware.NetworkAdapters += @{
        Name = $adapter.Name
        Description = $adapter.InterfaceDescription
        MacAddress = $adapter.MacAddress
        LinkSpeed = $adapter.LinkSpeed
        DriverVersion = $adapter.DriverVersion
        DriverDate = $adapter.DriverDate
        DriverProvider = $adapter.DriverProvider
    }
}

# TPM Information
try {
    $tpm = Get-Tpm -ErrorAction SilentlyContinue
    if ($tpm) {
        $inventory.Hardware.TPM = @{
            Enabled = $tpm.TpmPresent
            Activated = $tpm.TpmActivated
            Owned = $tpm.TpmOwned
            Version = (Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
        }
    }
} catch {
    $inventory.Hardware.TPM = @{ Present = $false }
}

# === SOFTWARE INFORMATION ===
Write-Host "  Gathering software info..." -ForegroundColor Gray

# Operating System
$os = Get-WmiObject Win32_OperatingSystem
$inventory.Software.OS = @{
    Caption = $os.Caption
    Version = $os.Version
    BuildNumber = $os.BuildNumber
    OSArchitecture = $os.OSArchitecture
    InstallDate = $os.ConvertToDateTime($os.InstallDate)
    LastBootUpTime = $os.ConvertToDateTime($os.LastBootUpTime)
    UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction SilentlyContinue).UBR
}

# .NET Framework Versions
$dotNetVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -ErrorAction SilentlyContinue | 
    Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | 
    Select-Object -ExpandProperty Version -Unique
$inventory.Software.DotNetVersions = $dotNetVersions

# PowerShell Version
$inventory.Software.PowerShellVersion = $PSVersionTable.PSVersion.ToString()

# Windows Features (limited to commonly problematic ones for performance)
# NOTE: SMB1Protocol removed from this list - Get-WindowsOptionalFeature returns the
# feature install state, not the protocol state. SMB1 is checked separately below
# via Get-SmbServerConfiguration which reflects the actual protocol enabled/disabled state.
$criticalFeatures = @(
    'Microsoft-Hyper-V',
    'VirtualMachinePlatform',
    'Microsoft-Windows-Subsystem-Linux',
    'NetFx3',
    'NetFx4-AdvSrvs',
    'BitLocker'
)

$inventory.Software.EnabledFeatures = @()
foreach ($feature in $criticalFeatures) {
    $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if ($featureState -and $featureState.State -eq 'Enabled') {
        $inventory.Software.EnabledFeatures += $feature
    }
}

# SMB1 protocol check -- uses Get-SmbServerConfiguration for accurate protocol state
# This correctly reflects Set-SmbServerConfiguration changes regardless of feature install state
try {
    $smb1Enabled = (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol
    if ($smb1Enabled -eq $true) {
        $inventory.Software.EnabledFeatures += 'SMB1Protocol'
    }
} catch {
    # Could not determine SMB1 state - do not flag
}

# Installed Software (if requested - can be slow)
if ($IncludeInstalledSoftware) {
    Write-Host "  Enumerating installed software (this may take a moment)..." -ForegroundColor Gray
    
    $installedSoftware = @()
    
    # 64-bit software
    $installedSoftware += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object {$_.DisplayName} |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    
    # 32-bit software on 64-bit OS
    if ([Environment]::Is64BitOperatingSystem) {
        $installedSoftware += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
            Where-Object {$_.DisplayName} |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }
    
    $inventory.Software.InstalledApplications = $installedSoftware | Sort-Object DisplayName -Unique
}

# Check for critical applications (security software, VPN, etc.)
$criticalApps = @{
    'Antivirus' = @('Defender', 'Symantec', 'McAfee', 'Trend Micro', 'Sophos', 'ESET', 'Kaspersky')
    'VPN' = @('Cisco AnyConnect', 'GlobalProtect', 'FortiClient', 'OpenVPN', 'Cisco Secure Client')
    'Backup' = @('Veeam', 'Backup Exec', 'Acronis')
}

$inventory.Software.CriticalApplications = @{}

foreach ($category in $criticalApps.Keys) {
    $found = @()
    foreach ($appName in $criticalApps[$category]) {
        $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
            Where-Object {$_.DisplayName -like "*$appName*"} |
            Select-Object -First 1
        
        if (-not $app -and [Environment]::Is64BitOperatingSystem) {
            $app = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
                Where-Object {$_.DisplayName -like "*$appName*"} |
                Select-Object -First 1
        }
        
        if ($app) {
            $found += @{
                Name = $app.DisplayName
                Version = $app.DisplayVersion
            }
        }
    }
    if ($found.Count -gt 0) {
        $inventory.Software.CriticalApplications[$category] = $found
    }
}

# === CONFIGURATION INFORMATION ===
Write-Host "  Gathering configuration info..." -ForegroundColor Gray

# BitLocker Status
$bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
if ($bitlockerVolumes) {
    $inventory.Configuration.BitLocker = @()
    foreach ($volume in $bitlockerVolumes) {
        $inventory.Configuration.BitLocker += @{
            MountPoint = $volume.MountPoint
            VolumeStatus = $volume.VolumeStatus.ToString()
            EncryptionPercentage = $volume.EncryptionPercentage
            ProtectionStatus = $volume.ProtectionStatus.ToString()
        }
    }
}

# Secure Boot
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    $inventory.Configuration.SecureBoot = $secureBoot
} catch {
    $inventory.Configuration.SecureBoot = $false
}

# Hyper-V Role
$hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
$inventory.Configuration.HyperVInstalled = ($hyperV.State -eq 'Enabled')

# Virtualization Detection
$computerSystem = Get-WmiObject Win32_ComputerSystem
$inventory.Configuration.IsVirtualMachine = ($computerSystem.Model -like '*Virtual*' -or $computerSystem.Manufacturer -like '*VMware*' -or $computerSystem.Manufacturer -like '*Microsoft*' -or $computerSystem.Manufacturer -like '*innotek*' -or $computerSystem.Manufacturer -like '*Xen*')

# Detect virtualization platform
$virtPlatform = 'Physical'
if ($computerSystem.Manufacturer -like '*VMware*') { $virtPlatform = 'VMware' }
elseif ($computerSystem.Manufacturer -like '*Microsoft*' -and $computerSystem.Model -like '*Virtual*') { $virtPlatform = 'Hyper-V' }
elseif ($computerSystem.Manufacturer -like '*QEMU*' -or $computerSystem.Model -like '*QEMU*') { $virtPlatform = 'Proxmox/KVM' }
elseif ($computerSystem.Manufacturer -like '*innotek*' -or $computerSystem.Model -like '*VirtualBox*') { $virtPlatform = 'VirtualBox' }
elseif ($computerSystem.Manufacturer -like '*Xen*') { $virtPlatform = 'Xen' }

$inventory.Configuration.VirtualizationPlatform = $virtPlatform

# === USER LOGIN INFORMATION ===
Write-Host "  Gathering user login info..." -ForegroundColor Gray

$inventory.UserInfo = @{
    LastLoggedOnUser = "Unknown"
    LastLogonTime = "Unknown"
    CurrentUser = $env:USERNAME
}

# Method 1: Get last logged on user from registry (works on workstations)
try {
    $lastLogonReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -ErrorAction SilentlyContinue
    if ($lastLogonReg -and $lastLogonReg.LastLoggedOnUser) {
        $inventory.UserInfo.LastLoggedOnUser = $lastLogonReg.LastLoggedOnUser
    }
    if ($lastLogonReg -and $lastLogonReg.LastLoggedOnDisplayName) {
        $inventory.UserInfo.LastLoggedOnDisplayName = $lastLogonReg.LastLoggedOnDisplayName
    }
} catch {
    # Silent fail
}

# Method 2: Get from user profile (fallback, works on servers)
try {
    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { 
        -not $_.Special -and $_.LocalPath -notmatch 'systemprofile|LocalService|NetworkService'
    } | Sort-Object LastUseTime -Descending | Select-Object -First 1
    
    if ($userProfiles -and $userProfiles.LastUseTime) {
        $lastUseTime = [Management.ManagementDateTimeConverter]::ToDateTime($userProfiles.LastUseTime)
        $inventory.UserInfo.LastLogonTime = $lastUseTime.ToString("yyyy-MM-dd HH:mm:ss")
        
        # Extract username from profile path
        if ($userProfiles.LocalPath -match '\\([^\\]+)$') {
            $profileUser = $matches[1]
            if ($inventory.UserInfo.LastLoggedOnUser -eq "Unknown") {
                $inventory.UserInfo.LastLoggedOnUser = $profileUser
            }
        }
    }
} catch {
    # Silent fail
}

# Method 3: Query Win32_ComputerSystem for currently logged user (works on servers with active sessions)
try {
    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs -and $cs.UserName -and $cs.UserName -ne "") {
        # This gives DOMAIN\Username format for the current interactive user
        if ($inventory.UserInfo.LastLoggedOnUser -eq "Unknown") {
            $inventory.UserInfo.LastLoggedOnUser = $cs.UserName
        }
        # Also update logon time to now since user is currently logged in
        if ($inventory.UserInfo.LastLogonTime -eq "Unknown") {
            $inventory.UserInfo.LastLogonTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
} catch {
    # Silent fail
}

# Method 4: Check Security event log for last logon (most comprehensive but requires permissions)
try {
    if ($inventory.UserInfo.LastLoggedOnUser -eq "Unknown") {
        $logonEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4624  # Successful logon
        } -MaxEvents 50 -ErrorAction SilentlyContinue | Where-Object {
            $_.Properties[8].Value -in @(2, 10, 11)  # Interactive, RemoteInteractive, CachedInteractive
        } | Select-Object -First 1
        
        if ($logonEvents) {
            $userName = $logonEvents.Properties[5].Value  # Target username
            $domain = $logonEvents.Properties[6].Value    # Target domain
            if ($userName -and $userName -notmatch 'SYSTEM|\$$') {
                $inventory.UserInfo.LastLoggedOnUser = "$domain\$userName"
                $inventory.UserInfo.LastLogonTime = $logonEvents.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    }
} catch {
    # Silent fail - may not have permission to read security log
}

# Get currently logged on interactive users (if any)
try {
    $loggedOnUsers = Get-WmiObject Win32_LoggedOnUser -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty Antecedent | 
        Where-Object { $_ -match 'Name="([^"]+)"' } |
        ForEach-Object { 
            if ($_ -match 'Domain="([^"]+)".*Name="([^"]+)"') {
                "$($matches[1])\$($matches[2])"
            }
        } | Where-Object { 
            $_ -and $_ -notmatch 'SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-|UMFD-' 
        } | Select-Object -Unique
    
    if ($loggedOnUsers) {
        $inventory.UserInfo.CurrentlyLoggedOnUsers = @($loggedOnUsers)
    }
} catch {
    # Silent fail
}

# === INSTALLED UPDATES ===
Write-Host "  Gathering installed updates..." -ForegroundColor Gray

# Get installed hotfixes (last 50 to keep size manageable)
$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 50
$inventory.InstalledUpdates = $hotfixes | ForEach-Object {
    @{
        HotFixID = $_.HotFixID
        Description = $_.Description
        InstalledBy = $_.InstalledBy
        InstalledOn = if ($_.InstalledOn) { $_.InstalledOn.ToString("yyyy-MM-dd") } else { "Unknown" }
    }
}

# Get Windows Update history from registry (last update check time)
try {
    $wuKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install" -ErrorAction SilentlyContinue
    if ($wuKey) {
        $inventory.Configuration.LastUpdateInstall = $wuKey.LastSuccessTime
    }
} catch {
    $inventory.Configuration.LastUpdateInstall = "Unknown"
}

# Get pending updates/reboot status
try {
    $pendingReboot = $false
    
    # Check Component Based Servicing
    if (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
        $pendingReboot = $true
    }
    
    # Check Windows Update
    if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
        $pendingReboot = $true
    }
    
    # Check PendingFileRenameOperations
    $fileRename = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($fileRename -and $fileRename.PendingFileRenameOperations) {
        $pendingReboot = $true
    }
    
    $inventory.Configuration.PendingReboot = $pendingReboot
} catch {
    $inventory.Configuration.PendingReboot = $null
}

# === SAVE INVENTORY ===
Write-Host "  Saving inventory data..." -ForegroundColor Gray

# Create output filename
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filename = "$($env:COMPUTERNAME)_$timestamp.json"

$savedSuccessfully = $false
$savedLocation = ""

# Try to save to central server first
if ($CentralServer) {
    try {
        # Test if central server is accessible
        if (Test-Path $CentralServer -ErrorAction SilentlyContinue) {
            $centralPath = Join-Path $CentralServer $filename
            $inventory | ConvertTo-Json -Depth 10 | Out-File $centralPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "  Saved to central server: $centralPath" -ForegroundColor Green
            $savedSuccessfully = $true
            $savedLocation = $centralPath
        } else {
            Write-Warning "Central server path not accessible: $CentralServer"
        }
    } catch {
        Write-Warning "Failed to save to central server: $_"
    }
}

# Fallback to local save if central server failed
if (-not $savedSuccessfully) {
    Write-Host "  Attempting local save..." -ForegroundColor Yellow
    
    try {
        # Ensure local directory exists
        if (-not (Test-Path $LocalFallbackPath)) {
            New-Item -Path $LocalFallbackPath -ItemType Directory -Force | Out-Null
        }
        
        $localPath = Join-Path $LocalFallbackPath $filename
        $inventory | ConvertTo-Json -Depth 10 | Out-File $localPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "  Saved locally: $localPath" -ForegroundColor Green
        $savedSuccessfully = $true
        $savedLocation = $localPath
    } catch {
        Write-Error "Failed to save inventory: $_"
    }
}

# Display summary
Write-Host "`nInventory Collection Summary:" -ForegroundColor Yellow
Write-Host "  Computer: $($env:COMPUTERNAME)" -ForegroundColor White
Write-Host "  OS: $($inventory.Software.OS.Caption) Build $($inventory.Software.OS.BuildNumber).$($inventory.Software.OS.UBR)" -ForegroundColor White
Write-Host "  CPU: $($inventory.Hardware.CPU.Name)" -ForegroundColor White
Write-Host "  RAM: $($inventory.Hardware.TotalPhysicalMemoryGB) GB" -ForegroundColor White
Write-Host "  Platform: $($inventory.Configuration.VirtualizationPlatform)" -ForegroundColor White
Write-Host "  Installed Updates: $($inventory.InstalledUpdates.Count)" -ForegroundColor White
Write-Host "  Pending Reboot: $($inventory.Configuration.PendingReboot)" -ForegroundColor White
Write-Host "  Saved To: $savedLocation" -ForegroundColor Cyan

# Return inventory object for pipeline use
return $inventory
