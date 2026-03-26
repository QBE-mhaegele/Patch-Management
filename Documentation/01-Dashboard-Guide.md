# Dashboard Tab Guide
## QB Energy Patch Management System v3.0

---

## Overview

The Dashboard is your primary interface for collecting machine inventory and analyzing patch compliance across the organization.

---

## Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│ System Status                                                │
│   Last Collection: 2026-02-02 13:34    Machines: 498        │
│   Last Analysis: 2026-02-02 14:15      KB Warnings: 12      │
├─────────────────────────────────────────────────────────────┤
│ Quick Actions                                                │
│  [Run Collection] [Run Analysis] [Previous Reports]          │
│  [View HTML Report] [KB Warnings] [Stop Task]               │
├─────────────────────────────────────────────────────────────┤
│ Output                                                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Progress bar and status messages                     │    │
│  │ Real-time collection/analysis output                 │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Actions

### 🔄 Run Collection

Gathers inventory from all computers in Active Directory.

**What it collects:**
- Hardware information (CPU, RAM, disk, TPM)
- Operating system version and build
- Installed Windows updates (hotfixes)
- User logon information
- BitLocker status
- Pending reboot status

**Process:**
1. Downloads current month's Microsoft CVE data
2. Queries Active Directory for computer objects
3. Connects to each online machine via WinRM
4. Saves inventory JSON files to network share

**Output locations:**
- `\\QBE-DEN-FILE4\inventory\[OU-Name]\[ComputerName]_YYYYMMDD-HHmmss.json`

**Timing:**
- Typical collection: 20-45 minutes for ~500 machines
- Per-machine timeout: 2 minutes (prevents hanging)

### 📊 Run Analysis

Analyzes collected inventory against current CVE data.

**What it calculates:**
- Risk score (0-100) per machine
- Days since last patch
- Missing critical updates
- Hardware compatibility issues
- Pending reboot warnings

**Risk Score Factors:**
| Factor | Points |
|--------|--------|
| Days since patch (30+) | +10 to +50 |
| Critical CVEs missing | +20 per CVE |
| Pending reboot | +10 |
| Unsupported OS | +30 |
| TPM issues | +5 |

**Output:**
- HTML report: `C:\PatchManagement\Analysis\RiskAnalysis_YYYYMMDD_HHmmss.html`
- JSON data: `C:\PatchManagement\Analysis\RiskAnalysis_YYYYMMDD_HHmmss.json`

### 📋 Previous Reports

Opens a dialog to browse and open historical analysis reports.

**Features:**
- Lists all reports by date
- Shows machine counts
- Double-click to open in browser

### 🌐 View HTML Report

Opens the most recent analysis report in your default web browser.

**Report Features:**
- Filter by risk level (Critical, High, Medium, Low)
- Search across all columns
- Click machine for detailed view
- Sort by any column
- Export to CSV

### ⚠️ KB Warnings

Quick link to the KB Warnings tab for viewing problematic updates.

### ⏹️ Stop Task

Cancels the current collection or analysis operation.

---

## Pre-Patch Tuesday Mode

When running before Microsoft's Patch Tuesday (2nd Tuesday of month), the system automatically:

1. Detects the upcoming Patch Tuesday date
2. Uses **previous month's CVE data** for compliance checking
3. Shows a clear header indicating pre-Patch Tuesday mode
4. Verifies machines are compliant with last month's patches

**Display:**
```
========================================
PRE-PATCH TUESDAY COMPLIANCE CHECK
========================================
Patch Tuesday: February 11, 2026
Using 2026-Jan CVE data to verify compliance
========================================
```

---

## Understanding the Output

### Collection Status Messages

| Message | Meaning |
|---------|---------|
| `Collecting from [PC]...` | Currently querying machine |
| `✓ Success` | Inventory collected and saved |
| `⚠ Warning: Offline` | Machine not responding to ping |
| `⏱️ Timeout` | Machine took >2 minutes to respond |
| `❌ Error: [message]` | Collection failed with error |
| `Skipped: Recent inventory exists` | Using cached data (<24 hours old) |

### Analysis Status Messages

| Message | Meaning |
|---------|---------|
| `Loading inventory files...` | Reading JSON inventory data |
| `Analyzing [PC]...` | Calculating risk score |
| `Generating HTML report...` | Creating output file |
| `Analysis complete!` | Report ready to view |

---

## Log Files

All output is automatically logged to:
```
C:\PatchManagement\Logs\YYYY-MM-DD_HH-mm-ss_Collection.log
C:\PatchManagement\Logs\YYYY-MM-DD_HH-mm-ss_Analysis.log
```

**Log format:**
```
================================================================================
QB Energy Patch Management System - Log File
================================================================================
Tab: Collection
Started: 2026-02-02 14:30:45
User: mhaegele.admin
Computer: QBE-DEN-YOURPC
================================================================================

[14:30:45] ========================================
[14:30:45] Patch Collection Process
[14:30:46] Collecting from DEN-SERVER01...
[14:30:48] ✓ Success: Saved to Denver-Servers
...
```

---

## Best Practices

### Collection Frequency
- **Weekly**: Normal operations
- **Daily**: During active patching periods
- **Before/After Patch Tuesday**: Compliance verification

### Analysis Timing
- Run after collection completes
- Run after Windows updates are installed
- Run before generating reports for management

### Performance Tips
- Run during off-peak hours for large environments
- Machines must have WinRM enabled
- Ensure firewall allows WinRM (port 5985)

---

## Troubleshooting

### Collection Hangs
**Symptom**: Progress stops on specific machine

**Solution**: 
- Machine has 2-minute timeout, will auto-skip
- Check if machine has WinRM/firewall issues
- Add problematic machines to exclusion list

### "No inventory files found"
**Symptom**: Analysis shows no machines

**Solution**:
1. Verify network share is accessible
2. Check `\\QBE-DEN-FILE4\inventory` has JSON files
3. Run Collection first

### Machines Show as Offline
**Symptom**: Many machines marked offline

**Solution**:
1. Verify network connectivity
2. Check WinRM is enabled: `Enable-PSRemoting -Force`
3. Verify firewall rules allow WinRM

### Risk Scores Seem Wrong
**Symptom**: Scores don't match expectations

**Solution**:
1. Re-run Collection for fresh data
2. Verify CVE data downloaded correctly
3. Check machine's actual patch status

---

## Related Documentation

- [KB Warnings Guide](02-KB-Warnings-Guide.md) - Managing problematic updates
- [Settings Guide](05-Settings-Guide.md) - Configuring paths and options
- [Troubleshooting](07-Troubleshooting.md) - Additional help

---

**Document Version**: 3.0  
**Last Updated**: February 2026
