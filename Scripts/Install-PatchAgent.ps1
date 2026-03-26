<#
.SYNOPSIS
    Install QB Energy Patch Management Agent on target servers
    
.DESCRIPTION
    Deploys the Patch Agent to target servers:
    - Copies agent script to C:\PatchManagement\Agent\
    - Creates scheduled task to run every 5 minutes
    - Optionally triggers immediate check
    
    Supports deployment by:
    - Individual computer names
    - Active Directory OU
    - Text file with computer names
    
.PARAMETER ComputerName
    Target computer(s) to install agent on
    
.PARAMETER OU
    Distinguished Name of OU to deploy to all computers within
    Example: "OU=Servers,OU=Denver,DC=qb-energy,DC=com"
    
.PARAMETER OURecurse
    Include computers in child OUs (default: $true)
    
.PARAMETER ServerOnly
    Only target server operating systems (skip workstations)
    
.PARAMETER InputFile
    Path to text file containing computer names (one per line)
    
.PARAMETER Credential
    Credentials for remote installation
    
.PARAMETER AgentSource
    Path to PatchAgent.ps1 (default: same folder as this script)
    
.PARAMETER TelemetryShare
    Central telemetry share path
    
.PARAMETER JobQueueShare
    Central job queue share path
    
.PARAMETER Uninstall
    Remove the agent instead of installing
    
.PARAMETER TriggerNow
    Trigger immediate agent run after installation
    
.PARAMETER WhatIf
    Show what would be done without making changes
    
.EXAMPLE
    # Deploy to specific servers
    .\Install-PatchAgent.ps1 -ComputerName "SERVER01","SERVER02"
    
.EXAMPLE
    # Deploy to all computers in an OU
    .\Install-PatchAgent.ps1 -OU "OU=Servers,DC=qb-energy,DC=com"
    
.EXAMPLE
    # Deploy to servers only in Denver OU (including child OUs)
    .\Install-PatchAgent.ps1 -OU "OU=Denver,DC=qb-energy,DC=com" -ServerOnly -OURecurse
    
.EXAMPLE
    # Deploy to Paris servers
    .\Install-PatchAgent.ps1 -OU "OU=Servers,OU=Paris,DC=qb-energy,DC=com" -TriggerNow

.EXAMPLE
    # Deploy from a text file
    .\Install-PatchAgent.ps1 -InputFile "C:\Temp\servers.txt"

.EXAMPLE
    # Preview what would be deployed (WhatIf)
    .\Install-PatchAgent.ps1 -OU "OU=Servers,DC=qb-energy,DC=com" -WhatIf

.NOTES
    Version: 2.0
    Author: QB Energy IT Infrastructure
    Date: February 2026
    
    Requires: 
    - ActiveDirectory PowerShell module (for OU deployment)
    - Admin rights on target computers
    - Network access to targets
#>

[CmdletBinding(DefaultParameterSetName='ComputerName')]
param(
    [Parameter(ParameterSetName='ComputerName', Mandatory=$false, ValueFromPipeline=$true)]
    [string[]]$ComputerName,
    
    [Parameter(ParameterSetName='OU', Mandatory=$true)]
    [string]$OU,
    
    [Parameter(ParameterSetName='OU')]
    [switch]$OURecurse = $true,
    
    [Parameter(ParameterSetName='OU')]
    [switch]$ServerOnly,
    
    [Parameter(ParameterSetName='InputFile', Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter()]
    [PSCredential]$Credential,
    
    [Parameter()]
    [string]$AgentSource = "",
    
    [Parameter()]
    [string]$TelemetryShare = "\\qbe-den-qnap\File4\Inventory\Logs\PatchTelemetry",
    
    [Parameter()]
    [string]$JobQueueShare = "\\qbe-den-qnap\File4\Inventory\Logs\PatchJobs",
    
    [Parameter()]
    [switch]$Uninstall,
    
    [Parameter()]
    [switch]$TriggerNow,
    
    [Parameter()]
    [switch]$WhatIf,
    
    [Parameter()]
    [int]$ThrottleLimit = 10
)

# ============================================================
# CONFIGURATION
# ============================================================

$Script:TaskName = "QB Energy - Patch Management Agent"
$Script:RemoteAgentPath = "C:\PatchManagement\Agent"
$Script:AgentScriptName = "PatchAgent.ps1"

# Find agent source if not specified
if (-not $AgentSource) {
    $AgentSource = Join-Path $PSScriptRoot $Script:AgentScriptName
    if (-not (Test-Path $AgentSource)) {
        $AgentSource = Join-Path "C:\PatchManagement\Scripts" $Script:AgentScriptName
    }
}

# ============================================================
# FUNCTIONS
# ============================================================

function Get-ComputersFromOU {
    <#
    .SYNOPSIS
        Get computer objects from Active Directory OU
    #>
    param(
        [string]$SearchBase,
        [switch]$Recurse,
        [switch]$ServersOnly
    )
    
    Write-Host "Querying Active Directory..." -ForegroundColor Cyan
    Write-Host "  OU: $SearchBase"
    Write-Host "  Recurse: $Recurse"
    Write-Host "  Servers Only: $ServersOnly"
    
    # Check if AD module is available
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ERROR: ActiveDirectory PowerShell module not found." -ForegroundColor Red
        Write-Host "Install with: Install-WindowsFeature RSAT-AD-PowerShell" -ForegroundColor Yellow
        return @()
    }
    
    Import-Module ActiveDirectory -ErrorAction Stop
    
    $SearchScope = if ($Recurse) { "Subtree" } else { "OneLevel" }
    
    try {
        # Get all computers in OU
        $ADParams = @{
            SearchBase = $SearchBase
            SearchScope = $SearchScope
            Filter = "Enabled -eq 'True'"
            Properties = @("Name", "OperatingSystem", "OperatingSystemVersion", "DNSHostName", "Description", "LastLogonDate")
        }
        
        $Computers = Get-ADComputer @ADParams
        
        Write-Host "  Found $($Computers.Count) enabled computer(s) in OU" -ForegroundColor Green
        
        # Filter for servers only if requested
        if ($ServersOnly) {
            $Computers = $Computers | Where-Object { 
                $_.OperatingSystem -match "Server" 
            }
            Write-Host "  Filtered to $($Computers.Count) server(s)" -ForegroundColor Green
        }
        
        # Filter out stale computers (no logon in 30 days)
        $StaleDate = (Get-Date).AddDays(-30)
        $ActiveComputers = $Computers | Where-Object {
            $_.LastLogonDate -gt $StaleDate -or $null -eq $_.LastLogonDate
        }
        
        $StaleCount = $Computers.Count - $ActiveComputers.Count
        if ($StaleCount -gt 0) {
            Write-Host "  Excluded $StaleCount stale computer(s) (no logon in 30+ days)" -ForegroundColor Yellow
        }
        
        return $ActiveComputers
        
    } catch {
        Write-Host "ERROR: Failed to query AD - $_" -ForegroundColor Red
        return @()
    }
}

function Get-ComputersFromFile {
    <#
    .SYNOPSIS
        Get computer names from text file
    #>
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ERROR: Input file not found: $FilePath" -ForegroundColor Red
        return @()
    }
    
    $Names = Get-Content $FilePath | Where-Object { $_.Trim() -and $_ -notmatch '^\s*#' } | ForEach-Object { $_.Trim() }
    Write-Host "Loaded $($Names.Count) computer name(s) from file" -ForegroundColor Green
    
    return $Names
}

function Test-ComputerOnline {
    <#
    .SYNOPSIS
        Quick check if computer is reachable
    #>
    param([string]$Computer)
    
    $Result = Test-Connection -ComputerName $Computer -Count 1 -Quiet -ErrorAction SilentlyContinue
    return $Result
}

function Install-AgentOnServer {
    param(
        [string]$Server,
        [PSCredential]$Cred,
        [switch]$WhatIfMode
    )
    
    if ($WhatIfMode) {
        Write-Host "  [WhatIf] Would install agent on: $Server" -ForegroundColor Cyan
        return @{ Success = $true; WhatIf = $true }
    }
    
    Write-Host "[$Server] Installing Patch Agent..." -ForegroundColor Cyan
    
    $SessionParams = @{ ComputerName = $Server }
    if ($Cred) { $SessionParams.Credential = $Cred }
    
    try {
        # Test connectivity
        if (-not (Test-ComputerOnline -Computer $Server)) {
            Write-Host "[$Server] Not reachable (offline or firewall)" -ForegroundColor Red
            return @{ Success = $false; Error = "Not reachable" }
        }
        
        # Create remote session
        $Session = New-PSSession @SessionParams -ErrorAction Stop
        
        # Create remote directory
        Invoke-Command -Session $Session -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
            }
            # Also create logs directory
            $LogPath = "C:\PatchManagement\Logs\Agent"
            if (-not (Test-Path $LogPath)) {
                New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
            }
        } -ArgumentList $Script:RemoteAgentPath
        
        # Copy agent script
        $RemoteScriptPath = Join-Path $Script:RemoteAgentPath $Script:AgentScriptName
        Copy-Item -Path $AgentSource -Destination $RemoteScriptPath -ToSession $Session -Force
        
        Write-Host "[$Server] Agent script copied" -ForegroundColor Green
        
        # Create scheduled task
        $TaskCreated = Invoke-Command -Session $Session -ScriptBlock {
            param($TaskName, $ScriptPath, $TelemetryShare, $JobQueueShare)
            
            # Build the action
            $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -TelemetryShare `"$TelemetryShare`" -JobQueueShare `"$JobQueueShare`""
            
            # Trigger every 5 minutes
            $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 9999)
            
            # Also trigger at startup
            $TriggerStartup = New-ScheduledTaskTrigger -AtStartup
            
            # Run as SYSTEM
            $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            
            # Settings
            $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew `
                -ExecutionTimeLimit (New-TimeSpan -Hours 2)
            
            # Remove existing task if present
            $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($Existing) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            }
            
            # Register the task
            Register-ScheduledTask -TaskName $TaskName `
                -Action $Action `
                -Trigger $Trigger, $TriggerStartup `
                -Principal $Principal `
                -Settings $Settings `
                -Description "QB Energy Patch Management Agent - Checks for and installs Windows updates" | Out-Null
            
            return $true
            
        } -ArgumentList $Script:TaskName, $RemoteScriptPath, $TelemetryShare, $JobQueueShare
        
        if ($TaskCreated) {
            Write-Host "[$Server] Scheduled task created" -ForegroundColor Green
        }
        
        # Trigger immediate run if requested
        if ($TriggerNow) {
            Write-Host "[$Server] Triggering immediate agent run..." -ForegroundColor Yellow
            Invoke-Command -Session $Session -ScriptBlock {
                param($TaskName)
                Start-ScheduledTask -TaskName $TaskName
            } -ArgumentList $Script:TaskName
        }
        
        Remove-PSSession $Session
        
        Write-Host "[$Server] Agent installed successfully" -ForegroundColor Green
        return @{ Success = $true }
        
    } catch {
        Write-Host "[$Server] Installation failed: $_" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Uninstall-AgentFromServer {
    param(
        [string]$Server,
        [PSCredential]$Cred,
        [switch]$WhatIfMode
    )
    
    if ($WhatIfMode) {
        Write-Host "  [WhatIf] Would uninstall agent from: $Server" -ForegroundColor Yellow
        return @{ Success = $true; WhatIf = $true }
    }
    
    Write-Host "[$Server] Uninstalling Patch Agent..." -ForegroundColor Yellow
    
    $SessionParams = @{ ComputerName = $Server }
    if ($Cred) { $SessionParams.Credential = $Cred }
    
    try {
        $Session = New-PSSession @SessionParams -ErrorAction Stop
        
        Invoke-Command -Session $Session -ScriptBlock {
            param($TaskName, $AgentPath)
            
            # Remove scheduled task
            $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($Task) {
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Host "Scheduled task removed"
            }
            
            # Remove agent files (but keep logs)
            if (Test-Path $AgentPath) {
                Remove-Item -Path "$AgentPath\*.ps1" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$AgentPath\Status.json" -Force -ErrorAction SilentlyContinue
                Write-Host "Agent files removed"
            }
            
        } -ArgumentList $Script:TaskName, $Script:RemoteAgentPath
        
        Remove-PSSession $Session
        
        Write-Host "[$Server] Agent uninstalled" -ForegroundColor Green
        return @{ Success = $true }
        
    } catch {
        Write-Host "[$Server] Uninstall failed: $_" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host ""
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "¦       QB Energy Patch Management Agent Installer v2.0        ¦" -ForegroundColor Cyan
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# Determine target computers based on parameter set
$TargetComputers = @()

switch ($PSCmdlet.ParameterSetName) {
    'OU' {
        Write-Host "Mode: Deploy to Active Directory OU" -ForegroundColor Cyan
        $ADComputers = Get-ComputersFromOU -SearchBase $OU -Recurse:$OURecurse -ServersOnly:$ServerOnly
        $TargetComputers = $ADComputers | ForEach-Object { $_.Name }
    }
    'InputFile' {
        Write-Host "Mode: Deploy from input file" -ForegroundColor Cyan
        $TargetComputers = Get-ComputersFromFile -FilePath $InputFile
    }
    'ComputerName' {
        if ($ComputerName) {
            Write-Host "Mode: Deploy to specified computers" -ForegroundColor Cyan
            $TargetComputers = $ComputerName
        } else {
            Write-Host "ERROR: No targets specified." -ForegroundColor Red
            Write-Host "Use -ComputerName, -OU, or -InputFile parameter" -ForegroundColor Red
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Yellow
            Write-Host "  .\Install-PatchAgent.ps1 -ComputerName 'SERVER01','SERVER02'"
            Write-Host "  .\Install-PatchAgent.ps1 -OU 'OU=Servers,DC=qb-energy,DC=com'"
            Write-Host "  .\Install-PatchAgent.ps1 -OU 'OU=Denver,DC=qb-energy,DC=com' -ServerOnly"
            Write-Host "  .\Install-PatchAgent.ps1 -InputFile 'C:\Temp\servers.txt'"
            exit 1
        }
    }
}

if ($TargetComputers.Count -eq 0) {
    Write-Host "No target computers found." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
if ($Uninstall) {
    Write-Host "Action: UNINSTALL" -ForegroundColor Yellow
} else {
    Write-Host "Action: INSTALL" -ForegroundColor Green
    
    # Verify agent source exists
    if (-not (Test-Path $AgentSource)) {
        Write-Host "ERROR: Agent source not found: $AgentSource" -ForegroundColor Red
        Write-Host "Please specify -AgentSource parameter" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Agent Source: $AgentSource"
}

Write-Host "Telemetry Share: $TelemetryShare"
Write-Host "Job Queue Share: $JobQueueShare"
Write-Host "Target Computers: $($TargetComputers.Count)"
Write-Host "Throttle Limit: $ThrottleLimit parallel"
if ($WhatIf) {
    Write-Host "WhatIf Mode: ON (no changes will be made)" -ForegroundColor Magenta
}
Write-Host ""

# Display target list
Write-Host "Target Computers:" -ForegroundColor White
$TargetComputers | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
Write-Host ""

# Confirm if many targets
if ($TargetComputers.Count -gt 10 -and -not $WhatIf) {
    $Confirm = Read-Host "Deploy to $($TargetComputers.Count) computers? (yes/no)"
    if ($Confirm -notmatch '^y(es)?$') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Ensure shares exist (unless WhatIf)
if (-not $Uninstall -and -not $WhatIf) {
    foreach ($Share in @($TelemetryShare, $JobQueueShare)) {
        if (-not (Test-Path $Share -ErrorAction SilentlyContinue)) {
            Write-Host "Creating share: $Share" -ForegroundColor Yellow
            try {
                New-Item -Path $Share -ItemType Directory -Force | Out-Null
            } catch {
                Write-Host "WARNING: Could not create $Share - $_" -ForegroundColor Yellow
            }
        }
    }
    
    # Create subdirectories
    @("History", "Completed") | ForEach-Object {
        $SubDir = if ($_ -eq "History") { Join-Path $TelemetryShare $_ } else { Join-Path $JobQueueShare $_ }
        if (-not (Test-Path $SubDir -ErrorAction SilentlyContinue)) {
            try {
                New-Item -Path $SubDir -ItemType Directory -Force | Out-Null
            } catch { }
        }
    }
}

# Process targets
$Results = @{
    Success = @()
    Failed = @()
    Skipped = @()
}

$StartTime = Get-Date
$Processed = 0

foreach ($Target in $TargetComputers) {
    $Processed++
    $StatusMsg = "$Target - $Processed of $($TargetComputers.Count)"
    $PctComplete = [int](($Processed / $TargetComputers.Count) * 100)
    Write-Progress -Activity "Deploying Patch Agent" -Status $StatusMsg -PercentComplete $PctComplete
    
    if ($Uninstall) {
        $Result = Uninstall-AgentFromServer -Server $Target -Cred $Credential -WhatIfMode:$WhatIf
    } else {
        $Result = Install-AgentOnServer -Server $Target -Cred $Credential -WhatIfMode:$WhatIf
    }
    
    if ($Result.Success) {
        $Results.Success += $Target
    } else {
        $Results.Failed += @{ Computer = $Target; Error = $Result.Error }
    }
}

Write-Progress -Activity "Deploying Patch Agent" -Completed

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).TotalMinutes

# Summary
Write-Host ""
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
$DurationMin = [math]::Round($Duration, 1)
Write-Host "  Duration: $DurationMin minutes"
Write-Host "  Successful: $($Results.Success.Count)" -ForegroundColor Green
$FailColor = if ($Results.Failed.Count -gt 0) { "Red" } else { "Green" }
Write-Host "  Failed: $($Results.Failed.Count)" -ForegroundColor $FailColor
Write-Host ""

if ($Results.Failed.Count -gt 0) {
    Write-Host "Failed Computers:" -ForegroundColor Red
    foreach ($Failure in $Results.Failed) {
        $FailMsg = "  - " + $Failure.Computer + ": " + $Failure.Error
        Write-Host $FailMsg -ForegroundColor Red
    }
    Write-Host ""
}

if (-not $Uninstall -and $Results.Success.Count -gt 0 -and -not $WhatIf) {
    $SuccessMsg = "Agent is now running on " + $Results.Success.Count + " computer(s)."
    Write-Host $SuccessMsg
    Write-Host "Telemetry will appear in: $TelemetryShare"
    Write-Host ""
    Write-Host "To dispatch a job, use the Patch Management GUI with Agent Mode enabled."
}

# Return results object for pipeline
return [PSCustomObject]@{
    TotalTargets = $TargetComputers.Count
    Successful = $Results.Success
    Failed = $Results.Failed
    Duration = $Duration
}