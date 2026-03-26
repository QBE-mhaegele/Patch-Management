<#
.SYNOPSIS
    QB Energy Patch Management Agent
    
.DESCRIPTION
    Lightweight agent that runs on target servers to:
    - Check for pending patch jobs from central queue
    - Execute update installations independently
    - Report real-time telemetry to central share
    - Handle reboots gracefully
    
    Runs as a scheduled task every 5 minutes and on-demand.
    
.NOTES
    Version: 1.0
    Author: QB Energy IT Infrastructure
    Date: February 2026
    
    Telemetry Path: \\qbe-den-file4\Inventory\Logs\PatchTelemetry\
    Job Queue Path: \\qbe-den-file4\Inventory\Logs\PatchJobs\
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TelemetryShare = "\\qbe-den-file4\Inventory\Logs\PatchTelemetry",
    
    [Parameter()]
    [string]$JobQueueShare = "\\qbe-den-file4\Inventory\Logs\PatchJobs",
    
    [Parameter()]
    [switch]$RunOnce,
    
    [Parameter()]
    [switch]$ForceCheck
)

# ============================================================
# CONFIGURATION
# ============================================================

$Script:AgentVersion = "1.0"
$Script:ComputerName = $env:COMPUTERNAME
$Script:LocalLogPath = "C:\PatchManagement\Logs\Agent"
$Script:LocalStatusFile = "C:\PatchManagement\Agent\Status.json"
$Script:TelemetryInterval = 30  # Seconds between telemetry updates during install
$Script:HeartbeatInterval = 300 # Seconds between heartbeats when idle (5 min)

# Ensure local directories exist
@($Script:LocalLogPath, "C:\PatchManagement\Agent") | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory -Force | Out-Null }
}

# ============================================================
# LOGGING FUNCTIONS
# ============================================================

function Write-AgentLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Telemetry")]
        [string]$Level = "Info"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogFile = Join-Path $Script:LocalLogPath "Agent_$(Get-Date -Format 'yyyyMMdd').log"
    
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    
    # Also write to console if running interactively
    if ($Host.Name -eq "ConsoleHost") {
        $Color = switch ($Level) {
            "Success"   { "Green" }
            "Warning"   { "Yellow" }
            "Error"     { "Red" }
            "Telemetry" { "Cyan" }
            default     { "White" }
        }
        Write-Host $LogEntry -ForegroundColor $Color
    }
}

# ============================================================
# TELEMETRY FUNCTIONS
# ============================================================

function Send-Telemetry {
    <#
    .SYNOPSIS
        Send telemetry update to central share
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Idle", "CheckingJobs", "DownloadingUpdate", "InstallingUpdate", 
                     "WaitingForReboot", "Rebooting", "PostRebootCheck", "Complete", 
                     "Failed", "Offline")]
        [string]$Status,
        
        [Parameter()]
        [string]$JobId = "",
        
        [Parameter()]
        [string]$CurrentKB = "",
        
        [Parameter()]
        [string]$CurrentStep = "",
        
        [Parameter()]
        [int]$Progress = 0,
        
        [Parameter()]
        [string]$Message = "",
        
        [Parameter()]
        [string]$Error = "",
        
        [Parameter()]
        [hashtable]$AdditionalData = @{}
    )
    
    $Telemetry = @{
        ComputerName = $Script:ComputerName
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        TimestampUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        AgentVersion = $Script:AgentVersion
        Status = $Status
        JobId = $JobId
        CurrentKB = $CurrentKB
        CurrentStep = $CurrentStep
        Progress = $Progress
        Message = $Message
        Error = $Error
        OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
        LastBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
        PendingReboot = (Test-PendingReboot)
        UptimeMinutes = [math]::Round(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalMinutes, 1)
    }
    
    # Add any additional data
    foreach ($Key in $AdditionalData.Keys) {
        $Telemetry[$Key] = $AdditionalData[$Key]
    }
    
    # Save locally first
    $Telemetry | ConvertTo-Json -Depth 5 | Out-File $Script:LocalStatusFile -Encoding UTF8 -Force
    
    # Try to send to central share
    try {
        if (Test-Path $TelemetryShare -ErrorAction SilentlyContinue) {
            $RemoteFile = Join-Path $TelemetryShare "$($Script:ComputerName).json"
            $Telemetry | ConvertTo-Json -Depth 5 | Out-File $RemoteFile -Encoding UTF8 -Force
            
            # Also append to history log
            $HistoryDir = Join-Path $TelemetryShare "History\$($Script:ComputerName)"
            if (-not (Test-Path $HistoryDir)) {
                New-Item -Path $HistoryDir -ItemType Directory -Force | Out-Null
            }
            $HistoryFile = Join-Path $HistoryDir "$(Get-Date -Format 'yyyyMMdd').jsonl"
            ($Telemetry | ConvertTo-Json -Compress) | Add-Content -Path $HistoryFile -Encoding UTF8
            
            Write-AgentLog "Telemetry sent: $Status $(if ($CurrentKB) { "- $CurrentKB" }) $(if ($Message) { "- $Message" })" -Level Telemetry
            return $true
        } else {
            Write-AgentLog "Telemetry share not accessible: $TelemetryShare" -Level Warning
            return $false
        }
    } catch {
        Write-AgentLog "Failed to send telemetry: $_" -Level Error
        return $false
    }
}

function Test-PendingReboot {
    <#
    .SYNOPSIS
        Check if system has pending reboot
    #>
    $Pending = $false
    
    # Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $Pending = $true
    }
    
    # Component Based Servicing
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $Pending = $true
    }
    
    # Pending file rename
    $PFR = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($PFR) { $Pending = $true }
    
    return $Pending
}

# ============================================================
# JOB QUEUE FUNCTIONS
# ============================================================

function Get-PendingJob {
    <#
    .SYNOPSIS
        Check for pending jobs for this computer
    #>
    
    try {
        if (-not (Test-Path $JobQueueShare -ErrorAction SilentlyContinue)) {
            Write-AgentLog "Job queue share not accessible: $JobQueueShare" -Level Warning
            return $null
        }
        
        # Look for job files for this computer
        # Format: {ComputerName}_{JobId}.job.json
        $JobFiles = Get-ChildItem -Path $JobQueueShare -Filter "$($Script:ComputerName)_*.job.json" -ErrorAction SilentlyContinue
        
        if ($JobFiles.Count -eq 0) {
            return $null
        }
        
        # Get the oldest job (FIFO)
        $JobFile = $JobFiles | Sort-Object CreationTime | Select-Object -First 1
        
        Write-AgentLog "Found pending job: $($JobFile.Name)"
        
        $Job = Get-Content $JobFile.FullName -Raw | ConvertFrom-Json
        $Job | Add-Member -NotePropertyName "JobFilePath" -NotePropertyValue $JobFile.FullName -Force
        
        return $Job
        
    } catch {
        Write-AgentLog "Error checking job queue: $_" -Level Error
        return $null
    }
}

function Complete-Job {
    <#
    .SYNOPSIS
        Mark a job as complete and archive it
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Job,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Success", "Failed", "PartialSuccess")]
        [string]$Result,
        
        [Parameter()]
        [string]$Message = "",
        
        [Parameter()]
        [array]$InstalledKBs = @(),
        
        [Parameter()]
        [array]$FailedKBs = @()
    )
    
    try {
        # Update job with results
        $Job | Add-Member -NotePropertyName "CompletedTime" -NotePropertyValue (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") -Force
        $Job | Add-Member -NotePropertyName "Result" -NotePropertyValue $Result -Force
        $Job | Add-Member -NotePropertyName "ResultMessage" -NotePropertyValue $Message -Force
        $Job | Add-Member -NotePropertyName "InstalledKBs" -NotePropertyValue $InstalledKBs -Force
        $Job | Add-Member -NotePropertyName "FailedKBs" -NotePropertyValue $FailedKBs -Force
        
        # Move to completed folder
        $CompletedDir = Join-Path $JobQueueShare "Completed\$(Get-Date -Format 'yyyy-MM')"
        if (-not (Test-Path $CompletedDir)) {
            New-Item -Path $CompletedDir -ItemType Directory -Force | Out-Null
        }
        
        $CompletedFile = Join-Path $CompletedDir "$($Script:ComputerName)_$($Job.JobId)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $Job | ConvertTo-Json -Depth 10 | Out-File $CompletedFile -Encoding UTF8
        
        # Remove the original job file
        if ($Job.JobFilePath -and (Test-Path $Job.JobFilePath)) {
            Remove-Item $Job.JobFilePath -Force
        }
        
        Write-AgentLog "Job $($Job.JobId) completed: $Result" -Level $(if ($Result -eq "Success") { "Success" } else { "Warning" })
        
    } catch {
        Write-AgentLog "Error completing job: $_" -Level Error
    }
}

# ============================================================
# UPDATE INSTALLATION FUNCTIONS
# ============================================================

function Install-WindowsUpdates {
    <#
    .SYNOPSIS
        Install Windows Updates with real-time telemetry
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Job
    )
    
    $JobId = $Job.JobId
    $Updates = $Job.Updates
    $AutoReboot = $Job.AutoReboot
    $RebootDelay = if ($Job.RebootDelay) { $Job.RebootDelay } else { 60 }
    
    Write-AgentLog "Starting update installation for job $JobId"
    Write-AgentLog "Updates to install: $($Updates.Count)"
    Write-AgentLog "Auto reboot: $AutoReboot (delay: $RebootDelay seconds)"
    
    $InstalledKBs = @()
    $FailedKBs = @()
    $TotalUpdates = $Updates.Count
    $CurrentIndex = 0
    
    # Create Windows Update session
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $UpdateDownloader = $UpdateSession.CreateUpdateDownloader()
        $UpdateInstaller = $UpdateSession.CreateUpdateInstaller()
    } catch {
        Send-Telemetry -Status "Failed" -JobId $JobId -Error "Failed to create Windows Update session: $_"
        return @{ Success = $false; Installed = @(); Failed = @($Updates | ForEach-Object { $_.KB }) }
    }
    
    foreach ($Update in $Updates) {
        $CurrentIndex++
        $KB = $Update.KB
        $ProgressPercent = [math]::Round(($CurrentIndex / $TotalUpdates) * 100)
        
        Write-AgentLog "Processing update $CurrentIndex of $TotalUpdates : $KB"
        
        # Send telemetry - searching
        Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
            -CurrentStep "Searching for $KB" -Progress $ProgressPercent `
            -Message "Update $CurrentIndex of $TotalUpdates"
        
        try {
            # Search for the specific update
            $SearchCriteria = "IsInstalled=0 and IsHidden=0"
            $SearchResult = $UpdateSearcher.Search($SearchCriteria)
            
            $TargetUpdate = $null
            foreach ($FoundUpdate in $SearchResult.Updates) {
                if ($FoundUpdate.Title -match $KB -or 
                    ($FoundUpdate.KBArticleIDs | Where-Object { "KB$_" -eq $KB })) {
                    $TargetUpdate = $FoundUpdate
                    break
                }
            }
            
            if (-not $TargetUpdate) {
                # Check if already installed
                $InstalledSearch = $UpdateSearcher.Search("IsInstalled=1")
                $AlreadyInstalled = $InstalledSearch.Updates | Where-Object { 
                    $_.Title -match $KB -or ($_.KBArticleIDs | Where-Object { "KB$_" -eq $KB })
                }
                
                if ($AlreadyInstalled) {
                    Write-AgentLog "$KB is already installed" -Level Success
                    $InstalledKBs += $KB
                    Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                        -CurrentStep "Already installed" -Progress $ProgressPercent -Message "Skipped - already installed"
                    continue
                } else {
                    Write-AgentLog "$KB not found in Windows Update" -Level Warning
                    $FailedKBs += @{ KB = $KB; Error = "Update not found" }
                    continue
                }
            }
            
            # Download if needed
            if (-not $TargetUpdate.IsDownloaded) {
                Send-Telemetry -Status "DownloadingUpdate" -JobId $JobId -CurrentKB $KB `
                    -CurrentStep "Downloading" -Progress $ProgressPercent `
                    -Message "Downloading $KB ($([math]::Round($TargetUpdate.MaxDownloadSize/1MB, 1)) MB)"
                
                Write-AgentLog "Downloading $KB..."
                
                $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
                $UpdatesToDownload.Add($TargetUpdate) | Out-Null
                $UpdateDownloader.Updates = $UpdatesToDownload
                
                $DownloadResult = $UpdateDownloader.Download()
                
                if ($DownloadResult.ResultCode -ne 2) {
                    throw "Download failed with result code: $($DownloadResult.ResultCode)"
                }
                
                Write-AgentLog "Download complete for $KB" -Level Success
            }
            
            # Install the update
            Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                -CurrentStep "Installing" -Progress $ProgressPercent `
                -Message "Installing $KB - this may take several minutes"
            
            Write-AgentLog "Installing $KB..."
            
            $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            $UpdatesToInstall.Add($TargetUpdate) | Out-Null
            $UpdateInstaller.Updates = $UpdatesToInstall
            
            # Create a runspace for heartbeat (stays in same process, has access to credentials)
            $HeartbeatRunspace = [runspacefactory]::CreateRunspace()
            $HeartbeatRunspace.Open()
            $HeartbeatPipeline = $HeartbeatRunspace.CreatePipeline()
            $HeartbeatPipeline.Commands.AddScript(@"
                param(`$TelemetryShare, `$ComputerName, `$JobId, `$KB, `$Progress)
                while (`$true) {
                    Start-Sleep -Seconds 30
                    `$Heartbeat = @{
                        ComputerName = `$ComputerName
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
                        Status = "InstallingUpdate"
                        JobId = `$JobId
                        CurrentKB = `$KB
                        CurrentStep = "Installing (in progress)"
                        Progress = `$Progress
                        Message = "Installation in progress - heartbeat"
                    }
                    `$RemoteFile = Join-Path `$TelemetryShare "`$ComputerName.json"
                    try {
                        `$Heartbeat | ConvertTo-Json | Out-File `$RemoteFile -Encoding UTF8 -Force
                    } catch { }
                }
"@)
            $HeartbeatPipeline.Commands[0].Parameters.Add("TelemetryShare", $TelemetryShare)
            $HeartbeatPipeline.Commands[0].Parameters.Add("ComputerName", $Script:ComputerName)
            $HeartbeatPipeline.Commands[0].Parameters.Add("JobId", $JobId)
            $HeartbeatPipeline.Commands[0].Parameters.Add("KB", $KB)
            $HeartbeatPipeline.Commands[0].Parameters.Add("Progress", $ProgressPercent)
            
            $HeartbeatAsync = $HeartbeatPipeline.InvokeAsync()
            
            try {
                $InstallResult = $UpdateInstaller.Install()
            } finally {
                # Stop heartbeat
                $HeartbeatPipeline.Stop()
                $HeartbeatRunspace.Close()
                $HeartbeatRunspace.Dispose()
            }
            
            # Check result
            $ResultCode = $InstallResult.GetUpdateResult(0).ResultCode
            $HResult = $InstallResult.GetUpdateResult(0).HResult
            
            # ResultCode: 2 = Succeeded, 3 = Succeeded with errors, 4 = Failed, 5 = Aborted
            if ($ResultCode -eq 2 -or $ResultCode -eq 3) {
                Write-AgentLog "$KB installed successfully (ResultCode: $ResultCode)" -Level Success
                $InstalledKBs += $KB
                
                Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                    -CurrentStep "Installed" -Progress $ProgressPercent -Message "Successfully installed"
            } else {
                $ErrorMsg = "Install failed - ResultCode: $ResultCode, HResult: $HResult"
                Write-AgentLog "$KB $ErrorMsg" -Level Error
                $FailedKBs += @{ KB = $KB; Error = $ErrorMsg; HResult = $HResult }
                
                Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                    -CurrentStep "Failed" -Progress $ProgressPercent -Error $ErrorMsg
            }
            
        } catch {
            Write-AgentLog "Error installing $KB : $_" -Level Error
            $FailedKBs += @{ KB = $KB; Error = $_.Exception.Message }
            
            Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                -CurrentStep "Error" -Progress $ProgressPercent -Error $_.Exception.Message
        }
    }
    
    # Determine overall result
    $OverallResult = if ($FailedKBs.Count -eq 0) { "Success" }
                     elseif ($InstalledKBs.Count -gt 0) { "PartialSuccess" }
                     else { "Failed" }
    
    Write-AgentLog "Installation complete: $($InstalledKBs.Count) succeeded, $($FailedKBs.Count) failed" -Level $(if ($OverallResult -eq "Success") { "Success" } else { "Warning" })
    
    # Check if reboot is needed
    $RebootRequired = Test-PendingReboot
    
    if ($RebootRequired -and $AutoReboot -and $InstalledKBs.Count -gt 0) {
        Send-Telemetry -Status "WaitingForReboot" -JobId $JobId `
            -Message "Reboot scheduled in $RebootDelay seconds" `
            -AdditionalData @{ InstalledKBs = $InstalledKBs; FailedKBs = $FailedKBs; RebootScheduled = $true }
        
        Write-AgentLog "Scheduling reboot in $RebootDelay seconds..."
        Write-AgentLog "Initiating RESTART (not shutdown)..." -Level Warning
        
        # Schedule the reboot using explicit /r (restart) flag
        $RebootTime = (Get-Date).AddSeconds($RebootDelay).ToString("HH:mm")
        $ShutdownCmd = "shutdown.exe /r /t $RebootDelay /c `"QB Energy Patch Management - Scheduled RESTART after installing updates: $($InstalledKBs -join ', ')`""
        Write-AgentLog "Executing: $ShutdownCmd" -Level Info
        
        $ShutdownResult = & cmd.exe /c $ShutdownCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-AgentLog "Shutdown command returned exit code: $LASTEXITCODE - Output: $ShutdownResult" -Level Warning
            try {
                Write-AgentLog "Attempting fallback: Restart-Computer -Force" -Level Warning
                Restart-Computer -Force -ErrorAction Stop
            } catch {
                Write-AgentLog "Restart-Computer also failed: $_" -Level Error
            }
        } else {
            Write-AgentLog "Restart command accepted successfully" -Level Success
        }
        
        # Complete the job before reboot
        Complete-Job -Job $Job -Result $OverallResult `
            -Message "Reboot scheduled for $RebootTime" `
            -InstalledKBs $InstalledKBs -FailedKBs $FailedKBs
        
    } else {
        $Message = if ($RebootRequired) { "Reboot required but not scheduled (AutoReboot=$AutoReboot)" } else { "No reboot required" }
        
        Send-Telemetry -Status "Complete" -JobId $JobId `
            -Message $Message `
            -AdditionalData @{ InstalledKBs = $InstalledKBs; FailedKBs = $FailedKBs; RebootRequired = $RebootRequired }
        
        Complete-Job -Job $Job -Result $OverallResult `
            -Message $Message `
            -InstalledKBs $InstalledKBs -FailedKBs $FailedKBs
    }
    
    return @{
        Success = ($OverallResult -ne "Failed")
        Installed = $InstalledKBs
        Failed = $FailedKBs
        RebootRequired = $RebootRequired
    }
}

function Install-MSUUpdates {
    <#
    .SYNOPSIS
        Install MSU/CAB files from network share with telemetry
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Job
    )
    
    $JobId = $Job.JobId
    $UpdateFiles = $Job.UpdateFiles
    $AutoReboot = $Job.AutoReboot
    $RebootDelay = if ($Job.RebootDelay) { $Job.RebootDelay } else { 60 }
    
    Write-AgentLog "Starting MSU installation for job $JobId"
    Write-AgentLog "Files to install: $($UpdateFiles.Count)"
    
    $InstalledKBs = @()
    $FailedKBs = @()
    $TotalFiles = $UpdateFiles.Count
    $CurrentIndex = 0
    
    foreach ($UpdateFile in $UpdateFiles) {
        $CurrentIndex++
        $FilePath = $UpdateFile.Path
        $KB = $UpdateFile.KB
        $FileName = [System.IO.Path]::GetFileName($FilePath)
        $ProgressPercent = [math]::Round(($CurrentIndex / $TotalFiles) * 100)
        
        Write-AgentLog "Processing file $CurrentIndex of $TotalFiles : $FileName"
        
        # Verify file exists
        if (-not (Test-Path $FilePath -ErrorAction SilentlyContinue)) {
            Write-AgentLog "File not found: $FilePath" -Level Error
            $FailedKBs += @{ KB = $KB; Error = "File not found: $FilePath" }
            continue
        }
        
        Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
            -CurrentStep "Installing MSU" -Progress $ProgressPercent `
            -Message "Installing $FileName"
        
        try {
            # Copy to local temp if on network share
            $LocalFile = $FilePath
            if ($FilePath -like "\\*") {
                $LocalFile = Join-Path $env:TEMP $FileName
                Write-AgentLog "Copying to local: $LocalFile"
                Copy-Item -Path $FilePath -Destination $LocalFile -Force
            }
            
            # Send initial telemetry before starting install
            Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                -CurrentStep "Installing $FileName" -Progress $ProgressPercent `
                -Message "Starting MSU installation"
            
            # Install the MSU (use async approach for heartbeat)
            $Extension = [System.IO.Path]::GetExtension($LocalFile).ToLower()
            
            # Start the process async so we can send heartbeats
            if ($Extension -eq ".msu") {
                $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                $ProcessInfo.FileName = "wusa.exe"
                $ProcessInfo.Arguments = "`"$LocalFile`" /quiet /norestart"
                $ProcessInfo.UseShellExecute = $false
                $ProcessInfo.CreateNoWindow = $true
            } elseif ($Extension -eq ".cab") {
                $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                $ProcessInfo.FileName = "dism.exe"
                $ProcessInfo.Arguments = "/Online /Add-Package /PackagePath:`"$LocalFile`" /Quiet /NoRestart"
                $ProcessInfo.UseShellExecute = $false
                $ProcessInfo.CreateNoWindow = $true
            } else {
                throw "Unsupported file type: $Extension"
            }
            
            $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
            $LastHeartbeat = Get-Date
            
            # Wait for process with heartbeats every 30 seconds
            while (-not $Process.HasExited) {
                Start-Sleep -Milliseconds 500
                
                # Send heartbeat every 30 seconds
                if (((Get-Date) - $LastHeartbeat).TotalSeconds -ge 30) {
                    Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                        -CurrentStep "Installing $FileName (in progress)" -Progress $ProgressPercent `
                        -Message "MSU installation in progress - heartbeat"
                    $LastHeartbeat = Get-Date
                }
            }
            
            $ExitCode = $Process.ExitCode
            
            # Clean up temp file
            if ($LocalFile -ne $FilePath -and (Test-Path $LocalFile)) {
                Remove-Item $LocalFile -Force -ErrorAction SilentlyContinue
            }
            
            # Check exit code
            # 0 = Success, 3010 = Success (reboot required), 2359302 = Already installed
            if ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq 2359302) {
                $Status = if ($ExitCode -eq 2359302) { "Already installed" } 
                          elseif ($ExitCode -eq 3010) { "Installed (reboot required)" }
                          else { "Installed" }
                
                Write-AgentLog "$KB : $Status (ExitCode: $ExitCode)" -Level Success
                $InstalledKBs += $KB
                
                Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                    -CurrentStep $Status -Progress $ProgressPercent
            } else {
                $ErrorMsg = "Installation failed with exit code: $ExitCode"
                Write-AgentLog "$KB : $ErrorMsg" -Level Error
                $FailedKBs += @{ KB = $KB; Error = $ErrorMsg; ExitCode = $ExitCode }
                
                Send-Telemetry -Status "InstallingUpdate" -JobId $JobId -CurrentKB $KB `
                    -CurrentStep "Failed" -Progress $ProgressPercent -Error $ErrorMsg
            }
            
        } catch {
            Write-AgentLog "Error installing $KB : $_" -Level Error
            $FailedKBs += @{ KB = $KB; Error = $_.Exception.Message }
        }
    }
    
    # Determine overall result
    $OverallResult = if ($FailedKBs.Count -eq 0) { "Success" }
                     elseif ($InstalledKBs.Count -gt 0) { "PartialSuccess" }
                     else { "Failed" }
    
    # Check if reboot is needed
    $RebootRequired = Test-PendingReboot
    
    if ($RebootRequired -and $AutoReboot -and $InstalledKBs.Count -gt 0) {
        Send-Telemetry -Status "WaitingForReboot" -JobId $JobId `
            -Message "Reboot scheduled in $RebootDelay seconds" `
            -AdditionalData @{ InstalledKBs = $InstalledKBs; FailedKBs = $FailedKBs }
        
        Write-AgentLog "Initiating RESTART (not shutdown) in $RebootDelay seconds..." -Level Warning
        
        # Use shutdown.exe with explicit /r (restart) flag - NOT /s (shutdown)
        # /r = restart, /t = time delay, /c = comment, /d = reason code
        $ShutdownCmd = "shutdown.exe /r /t $RebootDelay /c `"QB Energy Patch Management - Scheduled RESTART after updates`""
        Write-AgentLog "Executing: $ShutdownCmd" -Level Info
        
        $ShutdownResult = & cmd.exe /c $ShutdownCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-AgentLog "Shutdown command returned exit code: $LASTEXITCODE - Output: $ShutdownResult" -Level Warning
            # Fallback to Restart-Computer if shutdown.exe fails
            try {
                Write-AgentLog "Attempting fallback: Restart-Computer -Force" -Level Warning
                Restart-Computer -Force -ErrorAction Stop
            } catch {
                Write-AgentLog "Restart-Computer also failed: $_" -Level Error
            }
        } else {
            Write-AgentLog "Restart command accepted successfully" -Level Success
        }
        
        Complete-Job -Job $Job -Result $OverallResult `
            -Message "Reboot scheduled" `
            -InstalledKBs $InstalledKBs -FailedKBs $FailedKBs
    } else {
        Send-Telemetry -Status "Complete" -JobId $JobId `
            -Message "Installation complete" `
            -AdditionalData @{ InstalledKBs = $InstalledKBs; FailedKBs = $FailedKBs; RebootRequired = $RebootRequired }
        
        Complete-Job -Job $Job -Result $OverallResult `
            -InstalledKBs $InstalledKBs -FailedKBs $FailedKBs
    }
    
    return @{
        Success = ($OverallResult -ne "Failed")
        Installed = $InstalledKBs
        Failed = $FailedKBs
        RebootRequired = $RebootRequired
    }
}

# ============================================================
# MAIN AGENT LOOP
# ============================================================

function Start-AgentCycle {
    <#
    .SYNOPSIS
        Run one cycle of the agent
    #>
    
    Write-AgentLog "Agent cycle starting (v$($Script:AgentVersion))"
    
    # Send initial telemetry
    Send-Telemetry -Status "CheckingJobs" -Message "Checking for pending jobs"
    
    # Check for pending job
    $Job = Get-PendingJob
    
    if (-not $Job) {
        Send-Telemetry -Status "Idle" -Message "No pending jobs"
        Write-AgentLog "No pending jobs found"
        return
    }
    
    Write-AgentLog "Processing job: $($Job.JobId)"
    Write-AgentLog "Job type: $($Job.JobType)"
    
    # Process based on job type
    switch ($Job.JobType) {
        "WindowsUpdate" {
            $Result = Install-WindowsUpdates -Job $Job
        }
        "MSUInstall" {
            $Result = Install-MSUUpdates -Job $Job
        }
        default {
            Write-AgentLog "Unknown job type: $($Job.JobType)" -Level Error
            Send-Telemetry -Status "Failed" -JobId $Job.JobId -Error "Unknown job type: $($Job.JobType)"
            Complete-Job -Job $Job -Result "Failed" -Message "Unknown job type"
        }
    }
    
    Write-AgentLog "Agent cycle complete"
}

# ============================================================
# UPTIME AND REBOOT FAILURE DETECTION
# ============================================================

function Get-SystemUptime {
    <#
    .SYNOPSIS
        Get system uptime as a TimeSpan
    #>
    try {
        $OS = Get-CimInstance Win32_OperatingSystem
        $Uptime = (Get-Date) - $OS.LastBootUpTime
        return $Uptime
    } catch {
        Write-AgentLog "Failed to get uptime: $_" -Level Warning
        return [TimeSpan]::FromDays(999)  # Return large value on error
    }
}

function Check-RebootFailures {
    <#
    .SYNOPSIS
        Check for jobs that requested reboot but system uptime > 24 hours
    #>
    param([TimeSpan]$Uptime)
    
    $CompletedDir = Join-Path $JobQueueShare "Completed"
    if (-not (Test-Path $CompletedDir -ErrorAction SilentlyContinue)) { return }
    
    # Only check if uptime is more than 24 hours (system should have rebooted by now)
    if ($Uptime.TotalHours -lt 24) { return }
    
    # Look for completed jobs for this computer
    $MyCompletedJobs = Get-ChildItem -Path $CompletedDir -Filter "$($Script:ComputerName)_*.json" -Recurse -ErrorAction SilentlyContinue
    
    foreach ($JobFile in $MyCompletedJobs) {
        # Skip already-marked failures
        if ($JobFile.Name -like "*REBOOT_FAILED*") { continue }
        
        try {
            $Job = Get-Content $JobFile.FullName -Raw | ConvertFrom-Json
            
            # Check if this job requested a reboot
            if ($Job.AutoReboot -eq $true -or $Job.RebootScheduled -eq $true) {
                $JobTime = [DateTime]::Parse($Job.CreatedTime)
                $HoursSinceJob = ((Get-Date) - $JobTime).TotalHours
                
                # If job was created more than 1 hour ago but less than 48 hours, and uptime > 24 hours
                # This means reboot was requested but never happened
                if ($HoursSinceJob -gt 1 -and $HoursSinceJob -lt 48) {
                    $UptimeHours = [int]$Uptime.TotalHours
                    
                    Write-AgentLog "REBOOT FAILURE DETECTED: Job $($JobFile.Name) requested reboot at $($Job.CreatedTime) but system uptime is $UptimeHours hours" -Level Error
                    
                    Send-Telemetry -Status "RebootFailed" `
                        -JobId $Job.JobId `
                        -CurrentStep "REBOOT FAILED - Uptime: ${UptimeHours}h, Job requested reboot at $($Job.CreatedTime)" `
                        -Error "Reboot was requested but system has been up for $UptimeHours hours"
                    
                    # Move to a Failed folder to prevent repeated alerts
                    $FailedDir = Join-Path $JobQueueShare "Failed"
                    if (-not (Test-Path $FailedDir)) { 
                        New-Item -Path $FailedDir -ItemType Directory -Force | Out-Null 
                    }
                    
                    # Rename with failure indication
                    $FailedName = $JobFile.Name -replace '\.json$', '.REBOOT_FAILED.json'
                    Move-Item -Path $JobFile.FullName -Destination (Join-Path $FailedDir $FailedName) -Force -ErrorAction SilentlyContinue
                    Write-AgentLog "Moved failed job to: $FailedDir\$FailedName"
                }
            }
        } catch {
            Write-AgentLog "Error checking completed job $($JobFile.Name): $_" -Level Warning
        }
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

# Get system uptime
$Uptime = Get-SystemUptime
$UptimeStr = "{0}d {1}h {2}m" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes
$UptimeHours = [int]$Uptime.TotalHours

# Startup banner
Write-AgentLog "=========================================="
Write-AgentLog "QB Energy Patch Management Agent v$($Script:AgentVersion)"
Write-AgentLog "Computer: $($Script:ComputerName)"
Write-AgentLog "Uptime: $UptimeStr"
Write-AgentLog "Telemetry: $TelemetryShare"
Write-AgentLog "Job Queue: $JobQueueShare"
Write-AgentLog "=========================================="

# Check for reboot failures first (uptime > 24 hours but reboot was requested)
Check-RebootFailures -Uptime $Uptime

# If system just rebooted (less than 5 minutes uptime), report post-reboot status
if ($Uptime.TotalMinutes -lt 5) {
    Write-AgentLog "System recently rebooted - reporting post-reboot status" -Level Success
    Send-Telemetry -Status "PostReboot" `
        -CurrentStep "System rebooted successfully" `
        -Message "Uptime: $UptimeStr" `
        -AdditionalData @{ UptimeMinutes = [int]$Uptime.TotalMinutes }
    Start-Sleep -Seconds 5  # Brief pause to let telemetry be seen
}

# Run agent cycle
Start-AgentCycle

Write-AgentLog "Agent execution complete"
