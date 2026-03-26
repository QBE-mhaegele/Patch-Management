<#
.SYNOPSIS
    Poll server configuration to identify Patch Management dependencies
    
.DESCRIPTION
    This script collects information about services, features, firewall rules,
    PowerShell modules, and configurations needed for the QB Energy Patch 
    Management system to function properly.
    
.PARAMETER ComputerName
    Target computer to poll. Defaults to local machine.
    
.PARAMETER OutputPath
    Path to save the JSON report. Defaults to current directory.
    
.PARAMETER IncludeAllServices
    Include all services, not just relevant ones
    
.EXAMPLE
    .\Get-PatchMgmtDependencies.ps1
    
.EXAMPLE
    .\Get-PatchMgmtDependencies.ps1 -ComputerName "SERVER01" -OutputPath "C:\Reports"
    
.NOTES
    Author: QB Energy IT Infrastructure
    Version: 1.0
    Date: February 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "\\qbe-den-qnap\File4\Inventory",
    
    [switch]$IncludeAllServices
)

$IsRemote = $ComputerName -ne $env:COMPUTERNAME

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "QB Energy Patch Management - Dependency Scanner" -ForegroundColor Cyan
Write-Host "Target: $ComputerName $(if ($IsRemote) { '(Remote)' } else { '(Local)' })" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Initialize report object
$Report = [ordered]@{
    ComputerName = $ComputerName
    ScanDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    ScanType = if ($IsRemote) { "Remote" } else { "Local" }
    OperatingSystem = @{}
    Services = @{}
    WindowsFeatures = @{}
    FirewallRules = @{}
    PowerShellConfig = @{}
    PowerShellModules = @{}
    ScheduledTasks = @{}
    FolderStructure = @{}
    NetworkShares = @{}
    Permissions = @{}
    RegistrySettings = @{}
    Summary = @{
        RequiredServices = @()
        MissingServices = @()
        RequiredFeatures = @()
        MissingFeatures = @()
        RequiredModules = @()
        MissingModules = @()
        Issues = @()
        Recommendations = @()
    }
}

# Helper function to run commands locally or remotely
function Invoke-TargetCommand {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList
    )
    
    if ($IsRemote) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction SilentlyContinue
    } else {
        & $ScriptBlock @ArgumentList
    }
}

# ============================================================
# 1. OPERATING SYSTEM INFORMATION
# ============================================================
Write-Host "Collecting OS information..." -ForegroundColor Yellow

$OSInfo = Invoke-TargetCommand -ScriptBlock {
    $OS = Get-CimInstance Win32_OperatingSystem
    $CS = Get-CimInstance Win32_ComputerSystem
    @{
        Caption = $OS.Caption
        Version = $OS.Version
        BuildNumber = $OS.BuildNumber
        OSArchitecture = $OS.OSArchitecture
        ServicePackMajorVersion = $OS.ServicePackMajorVersion
        InstallDate = $OS.InstallDate
        LastBootTime = $OS.LastBootUpTime
        TotalMemoryGB = [math]::Round($CS.TotalPhysicalMemory / 1GB, 2)
        Domain = $CS.Domain
        DomainRole = $CS.DomainRole
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
}

$Report.OperatingSystem = $OSInfo
Write-Host "  OS: $($OSInfo.Caption)" -ForegroundColor Gray
Write-Host "  PowerShell: $($OSInfo.PowerShellVersion)" -ForegroundColor Gray

# ============================================================
# 2. SERVICES - Focus on relevant ones
# ============================================================
Write-Host "Collecting service information..." -ForegroundColor Yellow

# Services relevant to Patch Management
$RelevantServices = @(
    @{ Name = "WinRM"; DisplayName = "Windows Remote Management"; Required = $true; Purpose = "Remote PowerShell execution" }
    @{ Name = "wuauserv"; DisplayName = "Windows Update"; Required = $true; Purpose = "Windows Update API" }
    @{ Name = "BITS"; DisplayName = "Background Intelligent Transfer"; Required = $true; Purpose = "Update downloads" }
    @{ Name = "CryptSvc"; DisplayName = "Cryptographic Services"; Required = $true; Purpose = "Update verification" }
    @{ Name = "TrustedInstaller"; DisplayName = "Windows Modules Installer"; Required = $true; Purpose = "Update installation" }
    @{ Name = "EventLog"; DisplayName = "Windows Event Log"; Required = $true; Purpose = "Logging" }
    @{ Name = "Schedule"; DisplayName = "Task Scheduler"; Required = $true; Purpose = "Agent scheduled task" }
    @{ Name = "RpcSs"; DisplayName = "Remote Procedure Call"; Required = $true; Purpose = "Core Windows services" }
    @{ Name = "DcomLaunch"; DisplayName = "DCOM Server Process Launcher"; Required = $true; Purpose = "COM objects" }
    @{ Name = "LanmanWorkstation"; DisplayName = "Workstation"; Required = $true; Purpose = "Network share access" }
    @{ Name = "LanmanServer"; DisplayName = "Server"; Required = $false; Purpose = "File sharing (if hosting shares)" }
    @{ Name = "Netlogon"; DisplayName = "Netlogon"; Required = $true; Purpose = "Domain authentication" }
    @{ Name = "W32Time"; DisplayName = "Windows Time"; Required = $true; Purpose = "Time sync for auth" }
    @{ Name = "RemoteRegistry"; DisplayName = "Remote Registry"; Required = $false; Purpose = "Remote registry access" }
    @{ Name = "Winmgmt"; DisplayName = "WMI"; Required = $true; Purpose = "Windows Management" }
    @{ Name = "PolicyAgent"; DisplayName = "IPsec Policy Agent"; Required = $false; Purpose = "If IPsec is used" }
    @{ Name = "gpsvc"; DisplayName = "Group Policy Client"; Required = $true; Purpose = "GPO application" }
    @{ Name = "IKEEXT"; DisplayName = "IKE and AuthIP IPsec"; Required = $false; Purpose = "Secure connections" }
    @{ Name = "SessionEnv"; DisplayName = "Remote Desktop Configuration"; Required = $false; Purpose = "RDP access" }
    @{ Name = "TermService"; DisplayName = "Remote Desktop Services"; Required = $false; Purpose = "RDP access" }
    @{ Name = "UsoSvc"; DisplayName = "Update Orchestrator Service"; Required = $false; Purpose = "Windows 10+ update orchestration" }
)

$ServicesInfo = Invoke-TargetCommand -ScriptBlock {
    param($ServiceList, $IncludeAll)
    
    $Results = @{}
    
    # Get relevant services
    foreach ($SvcDef in $ServiceList) {
        $Svc = Get-Service -Name $SvcDef.Name -ErrorAction SilentlyContinue
        if ($Svc) {
            $Results[$SvcDef.Name] = @{
                Name = $Svc.Name
                DisplayName = $Svc.DisplayName
                Status = $Svc.Status.ToString()
                StartType = $Svc.StartType.ToString()
                Required = $SvcDef.Required
                Purpose = $SvcDef.Purpose
                Exists = $true
            }
        } else {
            $Results[$SvcDef.Name] = @{
                Name = $SvcDef.Name
                DisplayName = $SvcDef.DisplayName
                Status = "NotFound"
                StartType = "N/A"
                Required = $SvcDef.Required
                Purpose = $SvcDef.Purpose
                Exists = $false
            }
        }
    }
    
    $Results
} -ArgumentList @(,$RelevantServices), $IncludeAllServices

$Report.Services = $ServicesInfo

# Check for issues
foreach ($SvcName in $ServicesInfo.Keys) {
    $Svc = $ServicesInfo[$SvcName]
    if ($Svc.Required -and $Svc.Status -ne "Running") {
        $Report.Summary.MissingServices += "$SvcName ($($Svc.Purpose))"
        $Report.Summary.Issues += "Service '$SvcName' is not running (Status: $($Svc.Status))"
    }
    if ($Svc.Required) {
        $Report.Summary.RequiredServices += $SvcName
    }
}

Write-Host "  Found $($ServicesInfo.Count) relevant services" -ForegroundColor Gray
Write-Host "  Running: $(($ServicesInfo.Values | Where-Object { $_.Status -eq 'Running' }).Count)" -ForegroundColor Gray

# ============================================================
# 3. WINDOWS FEATURES
# ============================================================
Write-Host "Collecting Windows Features..." -ForegroundColor Yellow

$RelevantFeatures = @(
    @{ Name = "WinRM-IIS-Ext"; Required = $false; Purpose = "WinRM IIS Extension" }
    @{ Name = "WindowsPowerShellWebAccess"; Required = $false; Purpose = "PowerShell Web Access" }
    @{ Name = "NET-Framework-45-Core"; Required = $true; Purpose = ".NET Framework 4.5+" }
    @{ Name = "NET-Framework-45-Features"; Required = $false; Purpose = ".NET Framework Features" }
    @{ Name = "PowerShell"; Required = $true; Purpose = "PowerShell" }
    @{ Name = "PowerShell-V2"; Required = $false; Purpose = "PowerShell 2.0 (legacy)" }
    @{ Name = "WoW64-Support"; Required = $false; Purpose = "32-bit support" }
    @{ Name = "RSAT-AD-PowerShell"; Required = $false; Purpose = "AD PowerShell module (admin only)" }
    @{ Name = "Windows-Defender"; Required = $false; Purpose = "Windows Defender" }
    @{ Name = "FS-FileServer"; Required = $false; Purpose = "File Server role" }
)

$FeaturesInfo = Invoke-TargetCommand -ScriptBlock {
    param($FeatureList)
    
    $Results = @{}
    $IsServer = (Get-CimInstance Win32_OperatingSystem).ProductType -ne 1
    
    foreach ($FeatDef in $FeatureList) {
        try {
            if ($IsServer) {
                $Feature = Get-WindowsFeature -Name $FeatDef.Name -ErrorAction SilentlyContinue
                if ($Feature) {
                    $Results[$FeatDef.Name] = @{
                        Name = $Feature.Name
                        DisplayName = $Feature.DisplayName
                        Installed = $Feature.Installed
                        InstallState = $Feature.InstallState.ToString()
                        Required = $FeatDef.Required
                        Purpose = $FeatDef.Purpose
                    }
                }
            } else {
                # Workstation - use Get-WindowsOptionalFeature
                $Feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatDef.Name -ErrorAction SilentlyContinue
                if ($Feature) {
                    $Results[$FeatDef.Name] = @{
                        Name = $Feature.FeatureName
                        DisplayName = $Feature.FeatureName
                        Installed = $Feature.State -eq "Enabled"
                        InstallState = $Feature.State.ToString()
                        Required = $FeatDef.Required
                        Purpose = $FeatDef.Purpose
                    }
                }
            }
        } catch { }
    }
    
    $Results
} -ArgumentList @(,$RelevantFeatures)

$Report.WindowsFeatures = $FeaturesInfo
Write-Host "  Found $($FeaturesInfo.Count) features" -ForegroundColor Gray

# ============================================================
# 4. FIREWALL RULES
# ============================================================
Write-Host "Collecting Firewall Rules..." -ForegroundColor Yellow

$FirewallInfo = Invoke-TargetCommand -ScriptBlock {
    $RelevantRules = @{}
    
    # WinRM rules
    $WinRMRules = Get-NetFirewallRule -DisplayName "*WinRM*" -ErrorAction SilentlyContinue
    foreach ($Rule in $WinRMRules) {
        $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $RelevantRules["WinRM_$($Rule.Name)"] = @{
            Name = $Rule.Name
            DisplayName = $Rule.DisplayName
            Enabled = $Rule.Enabled.ToString()
            Direction = $Rule.Direction.ToString()
            Action = $Rule.Action.ToString()
            Profile = $Rule.Profile.ToString()
            LocalPort = $PortFilter.LocalPort
        }
    }
    
    # Remote Management rules
    $RemoteMgmt = Get-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
    foreach ($Rule in $RemoteMgmt) {
        if (-not $RelevantRules.ContainsKey("WinRM_$($Rule.Name)")) {
            $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
            $RelevantRules["RemoteMgmt_$($Rule.Name)"] = @{
                Name = $Rule.Name
                DisplayName = $Rule.DisplayName
                Enabled = $Rule.Enabled.ToString()
                Direction = $Rule.Direction.ToString()
                Action = $Rule.Action.ToString()
                Profile = $Rule.Profile.ToString()
                LocalPort = $PortFilter.LocalPort
            }
        }
    }
    
    # File and Printer Sharing
    $FileShare = Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue | Select-Object -First 5
    foreach ($Rule in $FileShare) {
        $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $RelevantRules["FileShare_$($Rule.Name)"] = @{
            Name = $Rule.Name
            DisplayName = $Rule.DisplayName
            Enabled = $Rule.Enabled.ToString()
            Direction = $Rule.Direction.ToString()
            Action = $Rule.Action.ToString()
            Profile = $Rule.Profile.ToString()
            LocalPort = $PortFilter.LocalPort
        }
    }
    
    # Check if specific ports are open
    $PortStatus = @{
        "5985_HTTP" = (Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true } | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 5985 }) -ne $null
        "5986_HTTPS" = (Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true } | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 5986 }) -ne $null
        "445_SMB" = (Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true } | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 445 }) -ne $null
    }
    
    @{
        Rules = $RelevantRules
        PortStatus = $PortStatus
    }
}

$Report.FirewallRules = $FirewallInfo
Write-Host "  Found $($FirewallInfo.Rules.Count) relevant rules" -ForegroundColor Gray

# ============================================================
# 5. POWERSHELL CONFIGURATION
# ============================================================
Write-Host "Collecting PowerShell Configuration..." -ForegroundColor Yellow

$PSConfig = Invoke-TargetCommand -ScriptBlock {
    @{
        Version = $PSVersionTable.PSVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        ExecutionPolicy = (Get-ExecutionPolicy).ToString()
        ExecutionPolicyMachine = (Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue)
        ExecutionPolicyUser = (Get-ExecutionPolicy -Scope UserPolicy -ErrorAction SilentlyContinue)
        ExecutionPolicyProcess = (Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue)
        ExecutionPolicyCurrentUser = (Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue)
        ExecutionPolicyLocalMachine = (Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue)
        PSModulePath = $env:PSModulePath -split ";"
        RemotingEnabled = (Get-PSSessionConfiguration -Name Microsoft.PowerShell -ErrorAction SilentlyContinue) -ne $null
        WSManRunning = (Get-Service WinRM -ErrorAction SilentlyContinue).Status -eq "Running"
        TrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
    }
}

$Report.PowerShellConfig = $PSConfig
Write-Host "  Execution Policy: $($PSConfig.ExecutionPolicy)" -ForegroundColor Gray
Write-Host "  Remoting Enabled: $($PSConfig.RemotingEnabled)" -ForegroundColor Gray

# ============================================================
# 6. POWERSHELL MODULES
# ============================================================
Write-Host "Collecting PowerShell Modules..." -ForegroundColor Yellow

$RequiredModules = @(
    @{ Name = "Microsoft.PowerShell.Management"; Required = $true; Purpose = "Core management" }
    @{ Name = "Microsoft.PowerShell.Utility"; Required = $true; Purpose = "Core utilities" }
    @{ Name = "Microsoft.PowerShell.Security"; Required = $true; Purpose = "Security cmdlets" }
    @{ Name = "CimCmdlets"; Required = $true; Purpose = "CIM/WMI access" }
    @{ Name = "NetSecurity"; Required = $true; Purpose = "Firewall management" }
    @{ Name = "ScheduledTasks"; Required = $true; Purpose = "Scheduled task management" }
    @{ Name = "ActiveDirectory"; Required = $false; Purpose = "AD cmdlets (admin workstation)" }
    @{ Name = "MSCatalogLTS"; Required = $false; Purpose = "Microsoft Catalog downloads (admin)" }
    @{ Name = "BitsTransfer"; Required = $true; Purpose = "BITS file transfers" }
    @{ Name = "Dism"; Required = $true; Purpose = "DISM operations" }
    @{ Name = "WindowsUpdate"; Required = $false; Purpose = "WU PowerShell module" }
    @{ Name = "PSWindowsUpdate"; Required = $false; Purpose = "Third-party WU module" }
)

$ModulesInfo = Invoke-TargetCommand -ScriptBlock {
    param($ModuleList)
    
    $Results = @{}
    
    foreach ($ModDef in $ModuleList) {
        $Mod = Get-Module -ListAvailable -Name $ModDef.Name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Mod) {
            $Results[$ModDef.Name] = @{
                Name = $Mod.Name
                Version = $Mod.Version.ToString()
                Path = $Mod.ModuleBase
                Available = $true
                Required = $ModDef.Required
                Purpose = $ModDef.Purpose
            }
        } else {
            $Results[$ModDef.Name] = @{
                Name = $ModDef.Name
                Version = "N/A"
                Path = "N/A"
                Available = $false
                Required = $ModDef.Required
                Purpose = $ModDef.Purpose
            }
        }
    }
    
    $Results
} -ArgumentList @(,$RequiredModules)

$Report.PowerShellModules = $ModulesInfo
Write-Host "  Found $($ModulesInfo.Count) modules checked" -ForegroundColor Gray

# ============================================================
# 7. SCHEDULED TASKS
# ============================================================
Write-Host "Collecting Scheduled Tasks..." -ForegroundColor Yellow

$TasksInfo = Invoke-TargetCommand -ScriptBlock {
    $RelevantTasks = @{}
    
    # Look for patch-related tasks
    $PatchTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskName -match "Patch|Update|KB|WSUS|Agent|QBE|Energy" -or
        $_.TaskPath -match "Microsoft\\Windows\\WindowsUpdate"
    }
    
    foreach ($Task in $PatchTasks) {
        $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction SilentlyContinue
        $RelevantTasks[$Task.TaskName] = @{
            TaskName = $Task.TaskName
            TaskPath = $Task.TaskPath
            State = $Task.State.ToString()
            Description = $Task.Description
            LastRunTime = $TaskInfo.LastRunTime
            NextRunTime = $TaskInfo.NextRunTime
            LastResult = $TaskInfo.LastTaskResult
            Author = $Task.Author
            RunAsUser = $Task.Principal.UserId
        }
    }
    
    # Specifically check for QB Energy - Patch Management Agent
    $QBEAgent = Get-ScheduledTask -TaskName "QB Energy - Patch Management Agent" -ErrorAction SilentlyContinue
    if ($QBEAgent) {
        $RelevantTasks["QB Energy - Patch Management Agent"] = @{
            TaskName = "QB Energy - Patch Management Agent"
            State = $QBEAgent.State.ToString()
            Exists = $true
            Triggers = ($QBEAgent.Triggers | ForEach-Object { $_.Repetition.Interval })
        }
    } else {
        $RelevantTasks["QB Energy - Patch Management Agent"] = @{
            TaskName = "QB Energy - Patch Management Agent"
            Exists = $false
            State = "NotFound"
        }
    }
    
    $RelevantTasks
}

$Report.ScheduledTasks = $TasksInfo
Write-Host "  Found $($TasksInfo.Count) relevant tasks" -ForegroundColor Gray

# ============================================================
# 8. FOLDER STRUCTURE
# ============================================================
Write-Host "Checking Folder Structure..." -ForegroundColor Yellow

$FolderInfo = Invoke-TargetCommand -ScriptBlock {
    $Folders = @{
        "C:\PatchManagement" = @{ Exists = Test-Path "C:\PatchManagement"; Type = "Base" }
        "C:\PatchManagement\Agent" = @{ Exists = Test-Path "C:\PatchManagement\Agent"; Type = "Agent" }
        "C:\PatchManagement\Logs" = @{ Exists = Test-Path "C:\PatchManagement\Logs"; Type = "Logs" }
        "C:\PatchManagement\Scripts" = @{ Exists = Test-Path "C:\PatchManagement\Scripts"; Type = "Scripts" }
        "C:\Windows\Temp" = @{ Exists = Test-Path "C:\Windows\Temp"; Type = "System Temp" }
    }
    
    # Check for agent script
    $AgentScript = "C:\PatchManagement\Agent\PatchAgent.ps1"
    $Folders["AgentScript"] = @{
        Path = $AgentScript
        Exists = Test-Path $AgentScript
        Size = if (Test-Path $AgentScript) { (Get-Item $AgentScript).Length } else { 0 }
        Modified = if (Test-Path $AgentScript) { (Get-Item $AgentScript).LastWriteTime } else { $null }
    }
    
    $Folders
}

$Report.FolderStructure = $FolderInfo
Write-Host "  Agent folder exists: $($FolderInfo['C:\PatchManagement\Agent'].Exists)" -ForegroundColor Gray
Write-Host "  Agent script exists: $($FolderInfo['AgentScript'].Exists)" -ForegroundColor Gray

# ============================================================
# 9. NETWORK SHARE ACCESS
# ============================================================
Write-Host "Checking Network Share Access..." -ForegroundColor Yellow

$ShareInfo = Invoke-TargetCommand -ScriptBlock {
    $Shares = @{
        "\\qbe-den-qnap\File4\Inventory" = @{ 
            Accessible = Test-Path "\\qbe-den-qnap\File4\Inventory" -ErrorAction SilentlyContinue
            Purpose = "Inventory Share"
        }
        "\\qbe-den-qnap\File4\Inventory\Logs\PatchJobs" = @{
            Accessible = Test-Path "\\qbe-den-qnap\File4\Inventory\Logs\PatchJobs" -ErrorAction SilentlyContinue
            Purpose = "Job Queue"
        }
        "\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry" = @{
            Accessible = Test-Path "\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry" -ErrorAction SilentlyContinue
            Purpose = "Telemetry Share"
        }
        "\\QBE-DEN-WINUP1\UpdateFiles" = @{
            Accessible = Test-Path "\\QBE-DEN-WINUP1\UpdateFiles" -ErrorAction SilentlyContinue
            Purpose = "Update Repository"
        }
    }
    
    # Test write access to telemetry share
    $TelemetryShare = "\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry"
    $TestFile = Join-Path $TelemetryShare "_writetest_$($env:COMPUTERNAME).tmp"
    try {
        "test" | Out-File $TestFile -Force -ErrorAction Stop
        Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
        $Shares["TelemetryWriteAccess"] = @{ Accessible = $true; Purpose = "Write test" }
    } catch {
        $Shares["TelemetryWriteAccess"] = @{ Accessible = $false; Purpose = "Write test"; Error = $_.Exception.Message }
    }
    
    $Shares
}

$Report.NetworkShares = $ShareInfo
Write-Host "  Telemetry share accessible: $($ShareInfo['\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry'].Accessible)" -ForegroundColor Gray

# ============================================================
# 10. WINRM CONFIGURATION
# ============================================================
Write-Host "Checking WinRM Configuration..." -ForegroundColor Yellow

$WinRMInfo = Invoke-TargetCommand -ScriptBlock {
    $Config = @{}
    
    try {
        $Config["Service"] = @{
            Status = (Get-Service WinRM).Status.ToString()
            StartType = (Get-Service WinRM).StartType.ToString()
        }
        
        $Config["Listener"] = @(winrm enumerate winrm/config/listener 2>$null) -join "`n"
        
        $Config["Client"] = @{
            TrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
            AllowUnencrypted = (Get-Item WSMan:\localhost\Client\AllowUnencrypted -ErrorAction SilentlyContinue).Value
        }
        
        $Config["Service_Config"] = @{
            AllowRemoteAccess = (Get-Item WSMan:\localhost\Service\AllowRemoteAccess -ErrorAction SilentlyContinue).Value
            MaxConcurrentOperationsPerUser = (Get-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -ErrorAction SilentlyContinue).Value
            MaxConnections = (Get-Item WSMan:\localhost\Service\MaxConnections -ErrorAction SilentlyContinue).Value
        }
        
        $Config["Auth"] = @{
            Basic = (Get-Item WSMan:\localhost\Service\Auth\Basic -ErrorAction SilentlyContinue).Value
            Kerberos = (Get-Item WSMan:\localhost\Service\Auth\Kerberos -ErrorAction SilentlyContinue).Value
            Negotiate = (Get-Item WSMan:\localhost\Service\Auth\Negotiate -ErrorAction SilentlyContinue).Value
            CredSSP = (Get-Item WSMan:\localhost\Service\Auth\CredSSP -ErrorAction SilentlyContinue).Value
        }
        
    } catch {
        $Config["Error"] = $_.Exception.Message
    }
    
    $Config
}

$Report.RegistrySettings["WinRM"] = $WinRMInfo
Write-Host "  WinRM Status: $($WinRMInfo.Service.Status)" -ForegroundColor Gray

# ============================================================
# GENERATE SUMMARY
# ============================================================
Write-Host ""
Write-Host "Generating Summary..." -ForegroundColor Yellow

# Check for required modules
foreach ($ModName in $ModulesInfo.Keys) {
    $Mod = $ModulesInfo[$ModName]
    if ($Mod.Required) {
        $Report.Summary.RequiredModules += $ModName
        if (-not $Mod.Available) {
            $Report.Summary.MissingModules += $ModName
            $Report.Summary.Issues += "Required module '$ModName' is not available"
        }
    }
}

# Check for required features
foreach ($FeatName in $FeaturesInfo.Keys) {
    $Feat = $FeaturesInfo[$FeatName]
    if ($Feat.Required) {
        $Report.Summary.RequiredFeatures += $FeatName
        if (-not $Feat.Installed) {
            $Report.Summary.MissingFeatures += $FeatName
            $Report.Summary.Issues += "Required feature '$FeatName' is not installed"
        }
    }
}

# Check WinRM
if ($WinRMInfo.Service.Status -ne "Running") {
    $Report.Summary.Issues += "WinRM service is not running"
    $Report.Summary.Recommendations += "Run: Enable-PSRemoting -Force"
}

# Check Agent
if (-not $FolderInfo['AgentScript'].Exists) {
    $Report.Summary.Issues += "Patch Agent script is not installed"
    $Report.Summary.Recommendations += "Deploy PatchAgent.ps1 to C:\PatchManagement\Agent\"
}

if ($TasksInfo['QB Energy - Patch Management Agent'].State -eq "NotFound") {
    $Report.Summary.Issues += "QB Energy - Patch Management Agent scheduled task is not configured"
    $Report.Summary.Recommendations += "Run Install-PatchAgent.ps1 to deploy the agent"
}

# Check network shares
if (-not $ShareInfo['\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry'].Accessible) {
    $Report.Summary.Issues += "Cannot access telemetry share"
    $Report.Summary.Recommendations += "Verify network connectivity and share permissions"
}

if ($ShareInfo['TelemetryWriteAccess'] -and -not $ShareInfo['TelemetryWriteAccess'].Accessible) {
    $Report.Summary.Issues += "Cannot write to telemetry share"
    $Report.Summary.Recommendations += "Grant computer account write access to PatchTelemetry folder"
}

# Check execution policy
if ($PSConfig.ExecutionPolicy -eq "Restricted") {
    $Report.Summary.Issues += "PowerShell Execution Policy is Restricted"
    $Report.Summary.Recommendations += "Run: Set-ExecutionPolicy RemoteSigned -Scope LocalMachine"
}

# ============================================================
# OUTPUT RESULTS
# ============================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "SCAN COMPLETE" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Display Summary
Write-Host "SUMMARY" -ForegroundColor Yellow
Write-Host "-" * 40

Write-Host "Required Services: $($Report.Summary.RequiredServices.Count)" -ForegroundColor Gray
Write-Host "Missing Services: $($Report.Summary.MissingServices.Count)" -ForegroundColor $(if ($Report.Summary.MissingServices.Count -gt 0) { "Red" } else { "Green" })

Write-Host "Required Features: $($Report.Summary.RequiredFeatures.Count)" -ForegroundColor Gray
Write-Host "Missing Features: $($Report.Summary.MissingFeatures.Count)" -ForegroundColor $(if ($Report.Summary.MissingFeatures.Count -gt 0) { "Red" } else { "Green" })

Write-Host "Required Modules: $($Report.Summary.RequiredModules.Count)" -ForegroundColor Gray
Write-Host "Missing Modules: $($Report.Summary.MissingModules.Count)" -ForegroundColor $(if ($Report.Summary.MissingModules.Count -gt 0) { "Red" } else { "Green" })

Write-Host ""
if ($Report.Summary.Issues.Count -gt 0) {
    Write-Host "ISSUES FOUND: $($Report.Summary.Issues.Count)" -ForegroundColor Red
    foreach ($Issue in $Report.Summary.Issues) {
        Write-Host "  - $Issue" -ForegroundColor Red
    }
    Write-Host ""
}

if ($Report.Summary.Recommendations.Count -gt 0) {
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
    foreach ($Rec in $Report.Summary.Recommendations) {
        Write-Host "  - $Rec" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Save report
$OutputFile = Join-Path $OutputPath "PatchMgmt-Dependencies_$ComputerName`_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Convert hashtables to PSCustomObjects for JSON serialization
function ConvertTo-SerializableObject {
    param($InputObject)
    
    if ($InputObject -is [System.Collections.IDictionary]) {
        $NewObject = [ordered]@{}
        foreach ($Key in $InputObject.Keys) {
            $NewObject[[string]$Key] = ConvertTo-SerializableObject $InputObject[$Key]
        }
        return [PSCustomObject]$NewObject
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-SerializableObject $_ })
    }
    else {
        return $InputObject
    }
}

try {
    $SerializableReport = ConvertTo-SerializableObject $Report
    $SerializableReport | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8
    Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
} catch {
    Write-Host "Failed to save JSON report: $_" -ForegroundColor Red
    # Try saving as XML instead
    $XMLFile = $OutputFile -replace '\.json$', '.xml'
    try {
        $Report | Export-Clixml -Path $XMLFile
        Write-Host "Report saved as XML: $XMLFile" -ForegroundColor Yellow
    } catch {
        Write-Host "Could not save report: $_" -ForegroundColor Red
    }
}

Write-Host ""

# Return the report object
$Report
