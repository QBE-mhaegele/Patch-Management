# QB Energy Patch Management System
## Quick Deployment Checklist

**Server Name:** _______________  
**Deployment Date:** _______________  
**Deployed By:** _______________

---

## Pre-Deployment

- [ ] Windows Server 2022 installed
- [ ] Server joined to QB-ENERGY domain
- [ ] Server name documented: _______________
- [ ] IP Address documented: _______________
- [ ] Administrator password secured in vault
- [ ] All Windows updates applied
- [ ] Server backed up / snapshot created

---

## File Share Setup

**On QBE-DEN-FILE4:**

- [ ] Available drive identified: _______________
- [ ] Directory created: `[Drive]:\Shares\inventory`
- [ ] SMB share created: `\\QBE-DEN-FILE4\inventory`
- [ ] Domain Admins: Full Control permission set
- [ ] Domain Computers: Modify permission set
- [ ] Share tested from management server

---

## Management Server Setup

### PowerShell Configuration
- [ ] Execution policy set to RemoteSigned
- [ ] ActiveDirectory module verified
- [ ] PSWindowsUpdate module installed

### Directory Structure
- [ ] `C:\PatchManagement` created
- [ ] `C:\PatchManagement\Scripts` created
- [ ] `C:\PatchManagement\MicrosoftData` created
- [ ] `C:\PatchManagement\Inventory` created
- [ ] `C:\PatchManagement\Analysis` created
- [ ] `C:\PatchManagement\Reports` created
- [ ] `C:\PatchManagement\Logs` created
- [ ] `C:\PatchManagement\Config` created

### Scripts Deployment
- [ ] Master-Orchestrator.ps1 copied
- [ ] Get-MicrosoftPatches.ps1 copied
- [ ] Get-ClientInventory.ps1 copied
- [ ] Invoke-RiskAnalysis.ps1 copied
- [ ] Deploy-Patches.ps1 copied
- [ ] Setup-ScheduledTasks.ps1 copied

---

## API Configuration

- [ ] Anthropic account created: https://console.anthropic.com
- [ ] API key generated
- [ ] API key stored in environment variable OR
- [ ] API key encrypted to `C:\PatchManagement\Config\api-key.enc`
- [ ] API key tested successfully
- [ ] Billing/budget limit set: $_____ /month

---

## Network Configuration

### WinRM Testing
- [ ] WinRM tested on test machine: _______________
- [ ] Remote command execution verified
- [ ] Firewall rules confirmed (ports 5985/5986)

### File Share Access
- [ ] Management server can write to `\\QBE-DEN-FILE4\inventory`
- [ ] Test client can write to `\\QBE-DEN-FILE4\inventory`
- [ ] Permissions verified

---

## Component Testing

### Test 1: Microsoft Data Collection
- [ ] Script executed: `.\Get-MicrosoftPatches.ps1`
- [ ] JSON files created in MicrosoftData folder
- [ ] CSV summary file created
- [ ] No errors in output

### Test 2: Single Machine Inventory
- [ ] Local inventory collection successful
- [ ] Remote inventory collection successful
- [ ] JSON file saved to inventory share
- [ ] File contains expected data

### Test 3: Risk Analysis
- [ ] Invoke-RiskAnalysis.ps1 loaded successfully
- [ ] Analysis completed on test data
- [ ] DeploymentPlan JSON created
- [ ] RiskScores JSON created
- [ ] HTML report created and viewable

### Test 4: Full Workflow (Dry Run)
- [ ] Master-Orchestrator.ps1 executed with -DryRun
- [ ] All phases completed
- [ ] No critical errors in log
- [ ] HTML report generated
- [ ] Report reviewed and looks correct

---

## Automation Setup

### Scheduled Tasks
- [ ] Setup-ScheduledTasks.ps1 executed
- [ ] Task created: QB-PatchManagement-Collect
- [ ] Task created: QB-PatchManagement-Analyze
- [ ] Tasks visible in Task Scheduler
- [ ] Tasks configured to run as SYSTEM
- [ ] Task triggers verified (4th Wed/Thu of month)

### Email Notifications (Optional)
- [ ] SMTP server configured: _______________
- [ ] Email recipients configured: _______________
- [ ] Test email sent successfully

---

## Documentation

- [ ] Installation documented in server inventory
- [ ] Admin team briefed on system
- [ ] Deployment plan review process documented
- [ ] Rollback procedures documented
- [ ] Emergency contacts listed
- [ ] Documentation saved to shared location: _______________

---

## First Production Run Preparation

- [ ] Team calendar updated with review meetings
- [ ] First Patch Tuesday identified: _______________
- [ ] Backup/snapshot schedule confirmed
- [ ] Rollback plan tested
- [ ] Communication plan for users established

---

## Critical Machines Noted

**Machines requiring special attention:**

1. Machine: _______________  
   Issue: _______________  
   Action Required: _______________

2. Machine: _______________  
   Issue: _______________  
   Action Required: _______________

3. Machine: _______________  
   Issue: _______________  
   Action Required: _______________

---

## Paris Office Note

- [ ] QBE-PAR-CNRPT1 status verified
- [ ] Rebuild scheduled: _______________
- [ ] Business impact assessed
- [ ] Downtime window approved
- [ ] User notification sent

---

## Sign-Off

### Installation Complete

**Installed by:**  
Name: _______________  
Date: _______________  
Signature: _______________

### Testing Complete

**Tested by:**  
Name: _______________  
Date: _______________  
Signature: _______________

### Production Approval

**Approved by:**  
Name: _______________  
Title: _______________  
Date: _______________  
Signature: _______________

---

## Notes / Issues Encountered

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________

---

## Next Steps

- [ ] Monitor first automated collection (Week 2 Wednesday)
- [ ] Monitor first automated analysis (Week 2 Thursday)
- [ ] Review first deployment plan (Week 2 Friday)
- [ ] Execute first pilot deployment (Week 3 Monday)
- [ ] Document lessons learned after first month
- [ ] Adjust schedules/thresholds as needed

---

**System Status:** ⬜ Planning  ⬜ Installing  ⬜ Testing  ⬜ Production

---

*QB Energy IT Infrastructure Team*  
*Patch Management System Deployment*  
*Version 1.0 - January 2026*
