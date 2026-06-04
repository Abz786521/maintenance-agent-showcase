#Requires -Version 5.1
<#
  Run-Demo.ps1
  ---------------------------------------------------------------------------
  Live, no-install demonstration of the Autonomous Property-Maintenance Agent's
  decision pipeline, running entirely on SYNTHETIC data.

      pwsh ./demo/agent/Run-Demo.ps1      # PowerShell 7 (Win/macOS/Linux)
      powershell ./demo/agent/Run-Demo.ps1  # Windows PowerShell 5.1

  Nothing here touches Freshdesk, Arthur, WhatsApp, email, disk or network.
  Every tenant, address and ticket below is entirely fictional.
  (c) 2026 Abdul Talib. All Rights Reserved.
  ---------------------------------------------------------------------------
#>
[CmdletBinding()]
param()

Import-Module (Join-Path $PSScriptRoot 'AgentDemo.psm1') -Force

$AsOf = Get-Date

# --- Synthetic tickets (fictional) -----------------------------------------
# Postcode doubles as the property key in this demo.
$tickets = @(
    [pscustomobject]@{ Id=10421; Address='12 Example Terrace, Demoville, DE1 2AB'; Postcode='DE1 2AB'; OpenedDate=$AsOf.AddDays(-71)
        Body='Black mould spots keep coming back on the bedroom wall and ceiling, mildew smell. Reported a while ago.' }
    [pscustomobject]@{ Id=10455; Address='4 Sample Street, Testfield, TF3 4CD'; Postcode='TF3 4CD'; OpenedDate=$AsOf.AddDays(-68)
        Body='Rising damp with a tide mark above the skirting board in the lounge, plaster is wet at the bottom.' }
    [pscustomobject]@{ Id=10472; Address='9 Mock Avenue, Sampleton, SA5 6EF'; Postcode='SA5 6EF'; OpenedDate=$AsOf.AddDays(-1)
        Body='Burst pipe under the kitchen sink, water is flooding the floor, I have turned the stopcock off.' }
    [pscustomobject]@{ Id=10486; Address='21 Placeholder Road, Demo City, DC7 8GH'; Postcode='DC7 8GH'; OpenedDate=$AsOf.AddDays(-6)
        Body='Black mould keeps coming back in the bedroom. This is my third report and I am going to the ombudsman if it is not sorted.' }
    [pscustomobject]@{ Id=10488; Address='2 Fictional Close, Testburgh, TB9 0JK'; Postcode='TB9 0JK'; OpenedDate=$AsOf.AddDays(0)
        Body='There are mice again in the kitchen, can see droppings under the units.' }
    [pscustomobject]@{ Id=10490; Address='7 Imaginary Lane, Exampleford, EX2 3LM'; Postcode='EX2 3LM'; OpenedDate=$AsOf.AddDays(-3)
        Body='Black mould around the bathroom window and sealant.' }
    [pscustomobject]@{ Id=10491; Address='15 Specimen Way, Mockton, EX2 7NP'; Postcode='EX2 7NP'; OpenedDate=$AsOf.AddDays(-2)
        Body='Lots of condensation on the windows every morning and black spots appearing behind the wardrobe.' }
    [pscustomobject]@{ Id=10492; Address='33 Dummy Drive, Testfield, TF3 9QR'; Postcode='TF3 9QR'; OpenedDate=$AsOf.AddDays(-4)
        Body='A damp patch high on the wall in the back bedroom that gets noticeably worse when it rains.' }
    [pscustomobject]@{ Id=10493; Address='5 Placeholder Place, Demoville, DE1 5ST'; Postcode='DE1 5ST'; OpenedDate=$AsOf.AddDays(-1)
        Body='Water is coming through the ceiling in the landing, looks like slipped tiles on the roof.' }
    [pscustomobject]@{ Id=10494; Address='8 Sample Square, Sampleton, SA5 2UV'; Postcode='SA5 2UV'; OpenedDate=$AsOf.AddDays(-2)
        Body='The sockets in the living room keep tripping the fuse, no power to that side of the room.' }
)

# --- Existing work orders (so the duplicate-guard has something to catch) ---
$existingWOs = @(
    [pscustomobject]@{ WorkOrderId='WO-55012'; PropertyId='EX2 3LM'; Category='mould';            Status='Active' }
    [pscustomobject]@{ WorkOrderId='WO-54880'; PropertyId='DE1 2AB'; Category='roof';             Status='Closed' }
)

function Write-Field { param($Label,$Value,$Color='Gray')
    Write-Host ('  {0,-8}: ' -f $Label) -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor $Color
}
function SlaColor { param($s) switch ($s) { 'OVERDUE' {'Red'} 'DUE SOON' {'Yellow'} default {'Green'} } }

Write-Host ''
Write-Host '=== Autonomous Property-Maintenance Agent  -  DEMO (synthetic data) ===' -ForegroundColor Cyan
Write-Host ("As of {0:ddd dd MMM yyyy}  -  {1} tickets  -  no real data, no external systems contacted" -f $AsOf, $tickets.Count) -ForegroundColor DarkGray
Write-Host ''

$tally = [ordered]@{ Overdue=0; Emergency=0; HumanHold=0; Pest=0; Duplicate=0; Routine=0 }

foreach ($t in $tickets) {
    $r = Invoke-TicketPipeline -Ticket $t -ExistingWorkOrders $existingWOs -AsOf $AsOf

    if     ($r.IsHumanOnly)        { $tally.HumanHold++ }
    elseif ($r.IsEmergency)        { $tally.Emergency++ }
    elseif ($r.Category -eq 'pest'){ $tally.Pest++ }
    elseif ($r.Duplicate.IsDuplicate) { $tally.Duplicate++ }
    elseif ($r.Sla.Status -eq 'OVERDUE') { $tally.Overdue++ }
    else                           { $tally.Routine++ }

    $cls = if ($r.DampType) { $r.DampType } else { (Get-Culture).TextInfo.ToTitleCase($r.Category.Replace('-', ' ')) }

    Write-Host ("#{0}  {1}  [{2}]" -f $r.Id, $r.Address, $r.Region) -ForegroundColor White
    Write-Field 'Class'  ("{0}  ({1} confidence)" -f $cls, $r.Confidence)
    Write-Field 'SLA'    ("{0}  -  {1} working days open, {2} remaining (window {3})" -f $r.Sla.Status, $r.Sla.WorkingDaysOpen, $r.Sla.DaysRemaining, $r.Sla.WindowDays) (SlaColor $r.Sla.Status)
    Write-Field 'Route'  ("{0}  ->  {1}" -f $r.Trade, $r.Contractor) 'Cyan'
    Write-Field 'Title'  $r.Title 'Gray'
    Write-Field 'Action' $r.NextAction 'Yellow'
    Write-Host ''
}

Write-Host '--- Run summary ------------------------------------------------------' -ForegroundColor Cyan
Write-Host ("  Overdue (raise now)   : {0}" -f $tally.Overdue)   -ForegroundColor Red
Write-Host ("  Emergencies (24h)     : {0}" -f $tally.Emergency) -ForegroundColor Red
Write-Host ("  Held for human        : {0}" -f $tally.HumanHold) -ForegroundColor Magenta
Write-Host ("  Pest advice sent      : {0}" -f $tally.Pest)      -ForegroundColor Yellow
Write-Host ("  Duplicates prevented  : {0}" -f $tally.Duplicate) -ForegroundColor Green
Write-Host ("  Routine raises        : {0}" -f $tally.Routine)   -ForegroundColor Gray
Write-Host ''
Write-Host 'Every action above is a DRY-RUN decision on fictional data. The real' -ForegroundColor DarkGray
Write-Host 'agent performs these against live systems, fully audited and deduplicated.' -ForegroundColor DarkGray
Write-Host ''
