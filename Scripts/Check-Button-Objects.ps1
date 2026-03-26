# Check-Button-Objects.ps1
# Verifies which buttons exist and which have handlers

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Button Object Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$GUIPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"
$Content = Get-Content $GUIPath -Raw

Write-Host "[1] Checking button creation..." -ForegroundColor Yellow
Write-Host ""

# Find all button creations with "Refresh" in name
$RefreshButtons = [regex]::Matches($Content, '\$(\w*[Rr]efresh\w*[Bb]utton\w*)\s*=\s*New-Object') | ForEach-Object {
    [PSCustomObject]@{
        Variable = $_.Groups[1].Value
        Line = ($Content.Substring(0, $_.Index) -split "`n").Count
    }
}

Write-Host "Found these Refresh buttons:" -ForegroundColor Cyan
foreach ($Btn in $RefreshButtons) {
    Write-Host "  Line $($Btn.Line): `$$($Btn.Variable)" -ForegroundColor Gray
    
    # Check if this button is added to FileBasedGroupBox
    $AddedToFileBasedGroupBox = $Content -match "\`$FileBasedGroupBox\.Controls\.Add\(\`$$($Btn.Variable)\)"
    Write-Host "    Added to FileBasedGroupBox: $(if($AddedToFileBasedGroupBox){'YES'}else{'NO'})" -ForegroundColor $(if($AddedToFileBasedGroupBox){'Green'}else{'Red'})
    
    # Check if this button has event handler
    $HasHandler = $Content -match "\`$$($Btn.Variable)\.Add_Click"
    Write-Host "    Has Add_Click handler: $(if($HasHandler){'YES'}else{'NO'})" -ForegroundColor $(if($HasHandler){'Green'}else{'Red'})
    Write-Host ""
}

Write-Host "`n[2] Analyzing the problem..." -ForegroundColor Yellow
Write-Host ""

# Find which button is added to FileBasedGroupBox
$FileBasedButtonMatch = [regex]::Match($Content, '\$FileBasedGroupBox\.Controls\.Add\(\$(\w*[Rr]efresh\w*[Bb]utton\w*)\)')
if ($FileBasedButtonMatch.Success) {
    $ButtonOnForm = $FileBasedButtonMatch.Groups[1].Value
    Write-Host "Button added to FileBasedGroupBox: `$$ButtonOnForm" -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find which refresh button is added to FileBasedGroupBox!" -ForegroundColor Red
    $ButtonOnForm = $null
}

# Find which button has the handler
$HandlerButtonMatch = [regex]::Match($Content, '\$(\w*[Rr]efresh\w*[Bb]utton\w*)\.Add_Click\(\{[^\}]*Load-RepositoryUpdates')
if ($HandlerButtonMatch.Success) {
    $ButtonWithHandler = $HandlerButtonMatch.Groups[1].Value
    Write-Host "Button with handler attached: `$$ButtonWithHandler" -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find which refresh button has the handler!" -ForegroundColor Red
    $ButtonWithHandler = $null
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSIS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($ButtonOnForm -and $ButtonWithHandler) {
    if ($ButtonOnForm -eq $ButtonWithHandler) {
        Write-Host "RESULT: Same button!" -ForegroundColor Green
        Write-Host "  The button on the form (`$$ButtonOnForm) has the handler attached." -ForegroundColor White
        Write-Host "  This should work...`n" -ForegroundColor White
        
        Write-Host "POSSIBLE CAUSES:" -ForegroundColor Yellow
        Write-Host "  1. Handler code has silent error" -ForegroundColor White
        Write-Host "  2. Controls referenced in handler are null" -ForegroundColor White
        Write-Host "  3. Handler is being overridden somewhere else" -ForegroundColor White
        Write-Host ""
        Write-Host "NEXT STEP:" -ForegroundColor Yellow
        Write-Host "  Check if `$RepoPathTextBox and `$OSFilterComboBox exist" -ForegroundColor White
        
    } else {
        Write-Host "RESULT: DIFFERENT BUTTONS!" -ForegroundColor Red
        Write-Host "  Button on form: `$$ButtonOnForm" -ForegroundColor Yellow
        Write-Host "  Button with handler: `$$ButtonWithHandler" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "THIS IS THE PROBLEM!" -ForegroundColor Red
        Write-Host "  You're clicking `$$ButtonOnForm but the handler is on `$$ButtonWithHandler" -ForegroundColor Red
        Write-Host "  They're two different button objects!" -ForegroundColor Red
        Write-Host ""
        Write-Host "SOLUTION:" -ForegroundColor Yellow
        Write-Host "  The handler needs to be attached to `$$ButtonOnForm instead!" -ForegroundColor White
    }
} else {
    Write-Host "ERROR: Could not identify buttons" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Detailed Handler Location" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Show the exact handler code
$Lines = $Content -split "`n"
for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '\$(\w*[Rr]efresh\w*[Bb]utton\w*)\.Add_Click') {
        $VarName = $Matches[1]
        Write-Host "Handler at line $($i+1) for: `$$VarName" -ForegroundColor Cyan
        Write-Host ""
        # Show a few lines
        for ($j = $i; $j -lt [Math]::Min($i+5, $Lines.Count); $j++) {
            Write-Host "  $($j+1): $($Lines[$j])" -ForegroundColor Gray
        }
        Write-Host ""
    }
}
