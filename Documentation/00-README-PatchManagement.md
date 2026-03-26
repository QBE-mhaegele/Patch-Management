# QB Energy Automated Patch Management System
**Complete Setup Guide and Documentation**

---

## 📋 System Overview

This automated patch management system provides end-to-end workflow for:
- Monthly Microsoft security patch data collection
- Automated inventory gathering from all domain computers
- AI-powered risk analysis and compatibility checking
- Prioritized, phased deployment planning
- Comprehensive reporting and monitoring

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Central Management Server                 │
│                    (Windows Server 2022)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Collect    │  │   Analyze    │  │    Deploy    │      │
│  │              │  │              │  │              │      │
│  │ - MS CVE     │  │ - Risk Score │  │ - Phased     │      │
│  │ - Inventory  │  │ - Claude AI  │  │ - Rollback   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│              Network File Share (\\QBE-DEN-FILE4)            │
│                   Inventory Repository                        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Machines                            │
│  - Denver Office  - Paris Office  - Test Systems             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Package Contents

### Core Scripts
1. **Master-Orchestrator.ps1** - Main automation engine
2. **Get-MicrosoftPatches.ps1** - Microsoft CVE data collector
3. **Get-ClientInventory.ps1** - Client machine inventory collector
4. **Invoke-RiskAnalysis.ps1** - Risk scoring and analysis engine
5. **Deploy-Patches.ps1** - Patch deployment automation
6. **Setup-ScheduledTasks.ps1** - Automated task scheduling

### Documentation
- **00-README-PatchManagement.md** - This file
- **01-Installation-Guide.md** - Step-by-step setup instructions
- **02-Operations-Manual.md** - Day-to-day usage guide
- **03-Troubleshooting-Guide.md** - Common issues and solutions

---

## ⚙️ Prerequisites

### Management Server Requirements
- **OS:** Windows Server 2022 (or 2019)
- **PowerShell:** 5.1 or later
- **RAM:** 8 GB minimum, 16 GB recommended
- **Disk:** 100 GB minimum for data storage
- **Network:** Access to all domain computers

### Required PowerShell Modules
- ActiveDirectory (for computer discovery)
- PSWindowsUpdate (for patch deployment)

### External Services
- **Anthropic API Key** (for AI-powered analysis)
  - Get from: https://console.anthropic.com
  - Estimated cost: $2-5/month
  - Optional but highly recommended

### Network Requirements
- File share: `\\QBE-DEN-FILE4\inventory`
- SMTP server for email reports (optional)
- Firewall rules: WinRM (5985/5986) to all target machines

---

## 📁 Directory Structure

```
C:\PatchManagement\
├── Scripts\
│   ├── Master-Orchestrator.ps1
│   ├── Get-MicrosoftPatches.ps1
│   ├── Get-ClientInventory.ps1
│   ├── Invoke-RiskAnalysis.ps1
│   ├── Deploy-Patches.ps1
│   └── Setup-ScheduledTasks.ps1
│
├── MicrosoftData\          # Monthly Microsoft patch data
│   ├── 2026-Jan-Parsed.json
│   ├── 2026-Jan-CVESummary.csv
│   └── 2026-Jan-Raw.json
│
├── Inventory\              # Local inventory cache (optional)
│   └── (or use \\QBE-DEN-FILE4\inventory)
│
├── Analysis\               # Risk analysis results
│   ├── DeploymentPlan_2026-Jan.json
│   ├── RiskScores_2026-Jan.json
│   └── RiskAnalysis_2026-Jan.html
│
├── Reports\                # Executive reports
│   └── MonthlyPatchReport_YYYYMMDD-HHMMSS.html
│
├── Logs\                   # Operation logs
│   └── PatchOrchestrator_YYYYMMDD-HHMMSS.log
│
└── Config\                 # Configuration files
    └── api-key.enc         # Encrypted API key
```

---

## 🚀 Quick Start (Manual First Run)

### 1. Initial Setup
```powershell
# Create directory structure
New-Item -Path "C:\PatchManagement\Scripts" -ItemType Directory -Force

# Copy all .ps1 scripts to C:\PatchManagement\Scripts\

# Set up API key
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'your-api-key', 'User')
```

### 2. Test Individual Components
```powershell
# Test Microsoft data collection
cd C:\PatchManagement\Scripts
.\Get-MicrosoftPatches.ps1 -OutputPath "C:\PatchManagement\MicrosoftData"

# Test inventory collection on one machine
.\Get-ClientInventory.ps1 -CentralServer "\\QBE-DEN-FILE4\inventory"

# Test risk analysis
.\Invoke-RiskAnalysis.ps1 -PatchDataPath "C:\PatchManagement\MicrosoftData\2026-Jan-Parsed.json" -InventoryPath "\\QBE-DEN-FILE4\inventory" -OutputPath "C:\PatchManagement\Analysis"
```

### 3. Full Workflow Test (Dry Run)
```powershell
.\Master-Orchestrator.ps1 -Phase All -DryRun
```

### 4. Review Results
```powershell
# View deployment plan
Get-Content "C:\PatchManagement\Analysis\DeploymentPlan_2026-Jan.json" | ConvertFrom-Json

# Open HTML report
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"
```

### 5. Deploy (When Ready)
```powershell
# Deploy to pilot phase only
.\Master-Orchestrator.ps1 -Phase Deploy

# Or deploy everything (remove -DryRun from step 3)
.\Master-Orchestrator.ps1 -Phase All
```

---

## 📅 Automated Monthly Schedule

### Setup Automation
```powershell
.\Setup-ScheduledTasks.ps1
```

This creates:
- **Task 1:** Collect (Wednesday after Patch Tuesday, 6 AM)
- **Task 2:** Analyze (Thursday after Patch Tuesday, 7 AM)
- **Manual:** Deploy (after reviewing deployment plan)

### Monthly Timeline
```
Week 2 (Patch Tuesday Week):
  Tuesday:    Microsoft releases patches
  Wednesday:  AUTO - Collect CVE data + Inventory
  Thursday:   AUTO - Risk analysis + Deployment plan generated
  Friday:     MANUAL - Review deployment plan
  
Week 3:
  Monday:     MANUAL - Deploy Phase 1 (Pilot - 2 machines)
  Wednesday:  MANUAL - Deploy Phase 2 (Medium risk)
  Friday:     MANUAL - Deploy Phase 3 (High risk - after remediation)
  
Week 4:
  As needed:  MANUAL - Critical systems (may require rebuild)
```

---

## 🎯 Risk Scoring System

### Factors and Weights
| Factor | Weight | Description |
|--------|--------|-------------|
| Patch Age | 0-40 pts | Days since last update |
| Security Config | 0-30 pts | SMB1, Secure Boot, BitLocker, AV |
| OS Support | 0-50 pts | Windows version support status |
| Pending Reboot | 0-10 pts | Incomplete patch installations |
| Hardware Risk | 0-20 pts | Intel RST, old BIOS, VirtIO drivers |

### Priority Levels
- **CRITICAL (80+):** Manual intervention required, likely needs rebuild
- **HIGH (50-79):** Patch after remediation (update drivers, fix configs)
- **MEDIUM (25-49):** Standard deployment schedule
- **LOW (0-24):** Perfect for pilot testing

---

## 📊 Sample Output

### Deployment Plan Example
```json
{
  "GeneratedDate": "2026-01-20 08:00:00",
  "PatchCycle": "2026-Jan",
  "TotalMachines": 45,
  "Phases": [
    {
      "Number": 1,
      "Name": "Pilot Testing",
      "Description": "Low-risk test machines",
      "Machines": [
        {
          "ComputerName": "QBE-DEN-TEST",
          "RiskScore": 15,
          "Priority": "LOW"
        }
      ],
      "WaitHours": 4,
      "WaitBeforeNext": 48
    }
  ]
}
```

---

## 🔧 Configuration Options

### Master-Orchestrator.ps1 Parameters
```powershell
-BaseDirectory      # Base path for all data (default: C:\PatchManagement)
-InventoryShare     # Network share for inventory (default: \\QBE-DEN-FILE4\inventory)
-ApiKey            # Anthropic API key (or use $env:ANTHROPIC_API_KEY)
-Phase             # Collect, Analyze, Deploy, or All
-DryRun            # Test mode - don't actually patch
-EmailRecipients   # Email addresses for reports
```

### Customization Points
- **OUs to scan:** Edit `Master-Orchestrator.ps1` line ~150
- **Risk thresholds:** Edit `Invoke-RiskAnalysis.ps1` line ~90
- **Deployment timing:** Edit `Setup-ScheduledTasks.ps1` line ~15
- **Email settings:** Edit `Master-Orchestrator.ps1` line ~450

---

## 🚨 Important Notes

### Before Production Use
1. ✅ Test on 2-3 machines manually first
2. ✅ Verify file share permissions
3. ✅ Test WinRM connectivity to all machines
4. ✅ Review and approve first deployment plan manually
5. ✅ Set up email notifications
6. ✅ Document rollback procedures
7. ✅ Train team on the system

### Security Considerations
- API key is sensitive - store encrypted
- File share should be restricted (Domain Computers: Modify, Admins: Full)
- Scripts run as SYSTEM - ensure they're protected
- Review logs regularly for failed machines
- Maintain offline backups of critical systems

### Paris Office Special Note
The Paris machine (QBE-PAR-CNRPT1) requires immediate attention:
- Windows 10 1607 (out of support since 2018)
- No patches since September 2022
- SMB1 enabled
- This machine should be rebuilt BEFORE any patching

---

## 📞 Support Resources

### Internal
- IT Team: it-team@qbenergy.com
- Documentation: C:\PatchManagement\Docs\
- Logs: C:\PatchManagement\Logs\

### External
- Microsoft Security Updates: https://msrc.microsoft.com/
- Anthropic API: https://docs.anthropic.com/
- PSWindowsUpdate: https://www.powershellgallery.com/packages/PSWindowsUpdate

---

## 📝 Change Log

### Version 1.0 (January 2026)
- Initial system design
- Core automation scripts
- Risk analysis engine
- AI integration (Claude API)
- Phased deployment planning

### Planned Enhancements
- [ ] Integration with existing WSUS/SCCM
- [ ] Slack/Teams notifications
- [ ] Advanced Proxmox snapshot management
- [ ] Compliance reporting (PCI, SOX, GDPR)
- [ ] Multi-site deployment coordination

---

## ✅ Installation Checklist

When you build the new server, use this checklist:

- [ ] Install Windows Server 2022
- [ ] Join to QB-ENERGY domain
- [ ] Create C:\PatchManagement folder structure
- [ ] Copy all scripts to C:\PatchManagement\Scripts\
- [ ] Install ActiveDirectory PowerShell module
- [ ] Install PSWindowsUpdate module
- [ ] Configure file share access to \\QBE-DEN-FILE4\inventory
- [ ] Set up Anthropic API key
- [ ] Test WinRM connectivity to target machines
- [ ] Configure email relay (if using email reports)
- [ ] Run manual test workflow
- [ ] Set up scheduled tasks
- [ ] Document server in infrastructure inventory
- [ ] Create admin documentation for team

---

**System designed by:** QB Energy IT Infrastructure Team  
**Powered by:** Anthropic Claude AI  
**Date:** January 2026  
**Version:** 1.0
