# Server Updates Tab Guide

## Overview

The Server Updates tab provides a powerful interface for managing Windows Updates across multiple servers simultaneously. It supports both Windows Update (online) and Local Files (MSU/CAB) deployment modes, with parallel processing of up to 5 servers at a time.

## Key Features

- **Parallel Processing**: Update up to 5 servers simultaneously
- **Two Update Sources**: Windows Update API or Local MSU/CAB files
- **Poll Updates**: Query servers for available updates with detailed KB information
- **Driver Separation**: Automatically separates drivers (no KB) from Windows updates
- **KB Exclusions**: Skip specific KBs during check/install operations
- **Configurable Timeout**: Set operation timeout from 30 seconds to 1 hour
- **Service Account Support**: Use alternate credentials for remote operations
- **Centralized Logging**: All operations logged to network share

## Interface Layout

### Target Servers Panel (Left)
Enter server names, one per line. You can:
- **Type manually**: Enter server names directly
- **Load File**: Import from a text file (one server per line)
- **From AD**: Query Active Directory for computer objects
- **Clear**: Clear the server list

The panel shows:
- Server count
- Processing status (parallel indicator)

### Update Options Panel (Center)
- **Update Source**: 
  - `Windows Update` - Uses PSWindowsUpdate module to query/install from Microsoft
  - `Local Files (MSU/CAB)` - Deploy specific update files from a network share
- **Update Type**: Filter by Security Only, Critical Only, Definition Updates, or All Updates
- **No restart after installation**: Suppress automatic reboots
- **Accept all updates automatically**: Auto-approve updates during install
- **File Path**: Path to MSU/CAB files (for Local Files mode)
- **Exclude KBs**: Comma-separated list of KB numbers to skip (e.g., `KB5034441,KB5021233`)
- **Timeout**: Operation timeout in seconds (default: 300)

### Actions Panel (Right)

| Button | Description |
|--------|-------------|
| **🔍 Check for Updates** | Query target servers for available updates (count only) |
| **📊 Poll Available Updates** | Get detailed update list - polls one server per OS type |
| **🚀 Install Updates** | Install updates on all target servers |
| **⏹ Stop All** | Cancel running operations |
| **📋 View Log** | Open the CSV log file |
| **📁 Export** | Export results to CSV |
| **⬇ Download** | Download selected updates to `\\QBE-DEN-WINUP1\Updatefiles\%OS%\YYYY-MM\` |

### Available Updates List (Middle)
After polling, displays:
- **KB**: KB number or "(No KB)" for drivers
- **Title**: Update title/description
- **Size (MB)**: Download size
- **Type**: Classification or "Driver"
- **Server**: Source server

Color coding:
- **White background**: Windows Updates (have KB numbers)
- **Yellow background**: Drivers (no KB numbers)

Helper buttons:
- **Select All**: Check all items
- **Select None**: Uncheck all items
- **Copy KBs**: Copy selected KB numbers to clipboard
- **→ Exclude**: Add selected KBs to exclusion list

### Server Progress Panel (Bottom)
Shows real-time progress for up to 5 parallel operations:
- Server name
- Progress bar with percentage
- Current status
- Update count
- Result (Success/Failed/Timeout)

## Workflows

### Check Available Updates (Quick)
1. Enter server names in Target Servers
2. Click **🔍 Check for Updates**
3. View update counts in progress slots
4. Results logged to CSV

### Poll Detailed Update Information
1. Enter server names - the tool will detect unique OS versions
2. Click **📊 Poll Available Updates**
3. Tool queries one server per OS type (e.g., Windows 10, Server 2019, Server 2022)
4. Review combined updates in the list (duplicates are filtered)
5. Server column shows "SERVER (OS Type)" for reference
6. Select updates to exclude or download
7. Use helper buttons as needed

### Install Updates from Windows Update
1. Enter target servers
2. Set **Update Source** to `Windows Update`
3. Configure options (type, restart, exclusions)
4. Click **🚀 Install Updates**
5. Monitor progress in slots
6. Check results and logs

### Deploy Local MSU/CAB Files
1. Enter target servers
2. Set **Update Source** to `Local Files (MSU/CAB)`
3. Enter or browse to the **File Path** containing updates
4. Click **🚀 Install Updates**
5. Files are copied to each server and installed via WUSA/DISM

### Download Updates to Repository
1. Poll servers to get update list (grouped by OS type)
2. Check the updates you want to download
3. Click **⬇ Download**
4. Updates are downloaded to: `\\QBE-DEN-WINUP1\Updatefiles\<OS>\<YYYY-MM>\`
   - OS folder: Win10, Win11, Server2019, Server2022, etc.
   - Date folder: Current year-month (e.g., 2026-02)
5. Example paths:
   - `\\QBE-DEN-WINUP1\Updatefiles\Server2019\2026-02\`
   - `\\QBE-DEN-WINUP1\Updatefiles\Win11\2026-02\`

## Service Account Configuration

For servers that require different credentials:
1. Check **☑ Use Service Account**
2. Click any action button
3. Enter credentials when prompted
4. Credentials are cached for the session

Status shows: `Using: DOMAIN\username`

## Timeout Configuration

Set timeout based on expected operation duration:

| Scenario | Recommended Timeout |
|----------|---------------------|
| Quick checks | 120 seconds (2 min) |
| Normal patching | 600 seconds (10 min) - default |
| Large cumulative updates | 900 seconds (15 min) |
| Multiple large updates | 1800 seconds (30 min) |
| Very slow servers | 3600 seconds (60 min) |

## Understanding Results

### Progress Slot Colors
- **Green (Complete)**: Operation succeeded
- **Red (Failed)**: Operation failed - check error message
- **Orange (Timeout)**: Operation timed out - increase timeout setting

### Status Messages
- `Found X updates`: Check completed, X updates available
- `Installed X updates`: Installation completed
- `Installed X updates (Reboot Required)`: Updates installed, server needs restart
- `No updates to install`: Server is up to date
- `[Task]`: Operation used scheduled task method (for Access Denied workaround)

## Logging

All operations are logged to:
- **Network**: `\\QBE-DEN-FILE4\Inventory\PatchManagement\Logs\ServerUpdates_YYYY-MM-DD.csv`
- **Local Fallback**: `C:\PatchManagement\Logs\ServerUpdates_YYYY-MM-DD.csv`

Log columns:
| Column | Description |
|--------|-------------|
| Timestamp | When the log entry was created |
| Server | Target server name |
| Action | Check, Install, Download, or Poll |
| Status | Success, Failed, or Timeout |
| UpdateCount | Number of updates processed |
| Updates | List of KB numbers (semicolon-separated) |
| StartTime | When the operation started |
| EndTime | When the operation completed |
| Duration | Total time (HH:MM:SS format) |
| RebootRequired | Yes, No, or N/A |
| KBDetails | Detailed KB info with sizes |
| Message | Status message or error details |
| User | Username who ran the operation |

## Troubleshooting

### Access Denied (0x80070005)
The tool automatically falls back to a scheduled task method when Windows Update API access is denied. You'll see `[Task]` in the status when this occurs.

### WinRM Connection Failed
- Verify server is online: `Test-Connection SERVER`
- Check WinRM: `Test-WSMan SERVER`
- Verify firewall allows WinRM (TCP 5985/5986)
- Try using service account credentials

### PSWindowsUpdate Not Installing
The tool automatically installs PSWindowsUpdate on remote servers. If this fails:
- Check internet connectivity on target server
- Verify PowerShell Gallery access
- Manually install: `Install-Module PSWindowsUpdate -Force`

### Timeout Issues
- Increase timeout in Options panel
- Large cumulative updates may need 15-30 minutes
- Check server performance/load

## Best Practices

1. **Test on a few servers first** before deploying to many
2. **Use KB exclusions** for known problematic updates
3. **Poll before installing** to review what will be installed
4. **Schedule maintenance windows** for server reboots
5. **Monitor the log** for patterns of failures
6. **Use Local Files mode** for controlled deployments of specific updates
7. **Download updates to repo** for offline/controlled deployment later

## Keyboard Shortcuts

- **Ctrl+A** in Target Servers: Select all text
- **Enter** in Target Servers: Adds new line (not trigger action)

## Related Documentation

- [Dashboard Guide](01-Dashboard-Guide.md) - Main interface overview
- [MSU Updates Guide](04-MSU-Updates-Guide.md) - Workstation update deployment
- [Settings Guide](07-Settings-Guide.md) - Configuration options
