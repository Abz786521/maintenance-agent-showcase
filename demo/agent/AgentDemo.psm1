#Requires -Version 5.1
<#
  AgentDemo.psm1
  ---------------------------------------------------------------------------
  CLEAN-ROOM DEMONSTRATION MODULE   |   (c) 2026 Abdul Talib. All Rights Reserved.

  An ILLUSTRATIVE, self-contained re-implementation of the decision logic at
  the heart of the Autonomous Property-Maintenance Agent. It runs on synthetic
  data only, performs NO network/disk I/O, and talks to NO external system
  (no Freshdesk, no Arthur, no WhatsApp). It exists purely to demonstrate the
  engineering approach and the domain knowledge encoded into the real system.

  It is NOT the production system. The production code, prompts, integrations
  and data are private and proprietary and are not contained in this repository.
  ---------------------------------------------------------------------------
#>

Set-StrictMode -Version Latest

# ===========================================================================
#  DOMAIN KNOWLEDGE
#  These tables encode generic, publicly-known maintenance domain rules:
#  how to read a tenant's words, what trade fixes it, and the statutory
#  windows a social landlord must work to (Awaab's Law-style timescales).
# ===========================================================================

# Issue-classification rules, evaluated by keyword hit-count (highest wins,
# ties broken by the order below). Order puts the most specific signals first.
$script:ClassRules = @(
    [pscustomobject]@{ Category = 'pest';             Trade = 'Pest control';     Keywords = @('mice','mouse','rat','rats','rodent','infestation','cockroach','wasp','wasps','bees','ants','bed bug','bedbug','fleas','pest') }
    [pscustomobject]@{ Category = 'mould';            Trade = 'Mould specialist'; Keywords = @('mould','mold','mildew','black spot','black spots','fungus','spores','damp and mould') }
    [pscustomobject]@{ Category = 'roof';             Trade = 'Roofer';           Keywords = @('roof','tiles','slate','slates','gutter','guttering','chimney','loft','ceiling coming','water through ceiling','flashing') }
    [pscustomobject]@{ Category = 'leak';             Trade = 'Plumber';          Keywords = @('leak','leaking','dripping','burst','pipe','overflow','under sink','cistern','waste pipe','soil pipe','tap ','toilet running') }
    [pscustomobject]@{ Category = 'rising-damp';      Trade = 'Damp specialist';  Keywords = @('rising damp','tide mark','tidemark','skirting','salts','up the wall','ground floor damp','wet at the bottom') }
    [pscustomobject]@{ Category = 'penetrating-damp'; Trade = 'Damp specialist';  Keywords = @('penetrating','penetrative','damp patch','patch on the wall','after rain','when it rains','external wall','spreading patch','high on the wall','bridged') }
    [pscustomobject]@{ Category = 'condensation';     Trade = 'Damp specialist';  Keywords = @('condensation','steam','window','windows','behind furniture','behind the wardrobe','ventilation','extractor','misted','sweating walls') }
    [pscustomobject]@{ Category = 'electrical';       Trade = 'Electrician';      Keywords = @('socket','sockets','fuse','trip','tripping','electric','electrical','wiring','consumer unit','light not working','no power to') }
    [pscustomobject]@{ Category = 'heating';          Trade = 'Gas engineer';     Keywords = @('boiler','radiator','radiators','heating','thermostat','hot water','immersion','combi') }
)

# Emergency triggers - independent of category; force a 24h response window.
$script:EmergencyKeywords = @(
    'no heating','no heat','no hot water','no water','gas leak','smell of gas','carbon monoxide',
    'sewage','flooding','flood','electric shock','exposed wire','exposed wires','sparking','dangerous','collapse','collapsed','can''t get in'
)

# Complaint / legal language - these are held for a human, never auto-actioned.
$script:HumanOnlyKeywords = @(
    'complaint','complain','solicitor','ombudsman','legal','disrepair','compensation','claim',
    'environmental health','council took','my mp','councillor','threaten','unsafe for my child'
)

# Statutory / policy response windows, in WORKING days, by category.
$script:SlaPolicy = @{
    'emergency'        = [pscustomobject]@{ WindowDays = 1;  Basis = 'Emergency - make safe within 24h' }
    'mould'            = [pscustomobject]@{ WindowDays = 10; Basis = 'Damp & mould - statutory investigation window' }
    'rising-damp'      = [pscustomobject]@{ WindowDays = 10; Basis = 'Damp & mould - statutory investigation window' }
    'penetrating-damp' = [pscustomobject]@{ WindowDays = 10; Basis = 'Damp & mould - statutory investigation window' }
    'condensation'     = [pscustomobject]@{ WindowDays = 10; Basis = 'Damp & mould - statutory investigation window' }
    'roof'             = [pscustomobject]@{ WindowDays = 10; Basis = 'Weather-tightness - routine repair window' }
    'leak'             = [pscustomobject]@{ WindowDays = 5;  Basis = 'Active leak - prompt repair window' }
    'pest'             = [pscustomobject]@{ WindowDays = 5;  Basis = 'Pest treatment - prompt repair window' }
    'electrical'       = [pscustomobject]@{ WindowDays = 5;  Basis = 'Electrical fault - prompt repair window' }
    'heating'          = [pscustomobject]@{ WindowDays = 5;  Basis = 'Heating fault - prompt repair window' }
    'general'          = [pscustomobject]@{ WindowDays = 20; Basis = 'Routine repair window' }
}

# Postcode-area -> region map (synthetic areas used by the demo data).
$script:RegionMap = @{
    'NW' = @('SA','TF','EX','TB')
    'NE' = @('DE','DC')
}

# "Issue families" used by the duplicate-guard so that, e.g., a fresh
# condensation report does not raise a second job when a damp job is already live.
$script:IssueFamily = @{
    'mould'            = 'damp-mould'
    'rising-damp'      = 'damp-mould'
    'penetrating-damp' = 'damp-mould'
    'condensation'     = 'damp-mould'
    'roof'             = 'roof'
    'leak'             = 'plumbing'
    'heating'          = 'plumbing'
    'pest'             = 'pest'
    'electrical'       = 'electrical'
    'general'          = 'general'
}

# Human-readable damp sub-type for the observation note.
$script:DampType = @{
    'mould'            = 'Mould growth'
    'rising-damp'      = 'Rising damp'
    'penetrating-damp' = 'Penetrating damp'
    'condensation'     = 'Condensation'
}

# ===========================================================================
#  PURE FUNCTIONS  (deterministic, no side-effects - easy to unit-test)
# ===========================================================================

function Resolve-IssueCategory {
<#
.SYNOPSIS
    Classifies free-text tenant issue wording into a maintenance category,
    the trade that fixes it, and whether it reads as an emergency.
.OUTPUTS
    PSCustomObject: Category, Trade, DampType, IsEmergency, IsHumanOnly,
                    Confidence, MatchedKeywords
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $t = ($Text + '').ToLowerInvariant()

    $isEmergency = $false
    foreach ($k in $script:EmergencyKeywords) { if ($t.Contains($k)) { $isEmergency = $true; break } }

    $isHumanOnly = $false
    foreach ($k in $script:HumanOnlyKeywords) { if ($t.Contains($k)) { $isHumanOnly = $true; break } }

    $best = $null; $bestHits = 0; $matched = @()
    foreach ($rule in $script:ClassRules) {
        $hits = @($rule.Keywords | Where-Object { $t.Contains($_) })
        if ($hits.Count -gt $bestHits) { $bestHits = $hits.Count; $best = $rule; $matched = $hits }
    }

    if ($null -eq $best) {
        $category = 'general'; $trade = 'General maintenance'; $confidence = 'Low'
    } else {
        $category = $best.Category; $trade = $best.Trade
        $confidence = if ($bestHits -ge 2) { 'High' } else { 'Medium' }
    }

    $damp = $null
    if ($script:DampType.ContainsKey($category)) { $damp = $script:DampType[$category] }

    [pscustomobject]@{
        Category        = $category
        Trade           = $trade
        DampType        = $damp
        IsEmergency     = $isEmergency
        IsHumanOnly     = $isHumanOnly
        Confidence      = $confidence
        MatchedKeywords = $matched
    }
}

function Get-SlaPolicy {
<#
.SYNOPSIS  Returns the response-window policy for a category (or emergency).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Category,
        [switch]$IsEmergency
    )
    if ($IsEmergency) { return $script:SlaPolicy['emergency'] }
    if ($script:SlaPolicy.ContainsKey($Category)) { return $script:SlaPolicy[$Category] }
    return $script:SlaPolicy['general']
}

function Get-WorkingDaysElapsed {
<#
.SYNOPSIS  Counts working days (Mon-Fri) between two dates, inclusive of neither end's weekend.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime]$From,
        [datetime]$To = (Get-Date)
    )
    if ($To -lt $From) { return 0 }
    $days = 0
    $cursor = $From.Date
    while ($cursor -lt $To.Date) {
        $cursor = $cursor.AddDays(1)
        if ($cursor.DayOfWeek -ne 'Saturday' -and $cursor.DayOfWeek -ne 'Sunday') { $days++ }
    }
    return $days
}

function Get-SlaStatus {
<#
.SYNOPSIS
    Scores how a ticket sits against its statutory window.
.OUTPUTS
    PSCustomObject: WindowDays, Basis, WorkingDaysOpen, DaysRemaining, Status
    Status is one of: OVERDUE, DUE SOON, ON TRACK
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][int]$WorkingDaysOpen,
        [switch]$IsEmergency
    )
    $policy = Get-SlaPolicy -Category $Category -IsEmergency:$IsEmergency
    $remaining = $policy.WindowDays - $WorkingDaysOpen
    $status = if ($remaining -lt 0) { 'OVERDUE' } elseif ($remaining -le 2) { 'DUE SOON' } else { 'ON TRACK' }

    [pscustomobject]@{
        WindowDays      = $policy.WindowDays
        Basis           = $policy.Basis
        WorkingDaysOpen = $WorkingDaysOpen
        DaysRemaining   = $remaining
        Status          = $status
    }
}

function Get-Region {
<#
.SYNOPSIS  Maps a UK-style postcode to the operating region (NW / NE / Unknown).
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Postcode)

    $area = (($Postcode + '').Trim().ToUpperInvariant() -replace '[^A-Z].*$', '')
    foreach ($region in $script:RegionMap.Keys) {
        if ($script:RegionMap[$region] -contains $area) { return $region }
    }
    return 'Unknown'
}

function Get-RegionalContractor {
<#
.SYNOPSIS
    Resolves the generic regional contractor role for a region + trade.
    NOTE: deliberately returns ROLE labels, never real contractor identities.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Region,
        [Parameter(Mandatory)][string]$Trade
    )
    $r = if ($Region -eq 'Unknown') { '' } else { "$Region " }
    switch -Wildcard ($Trade) {
        'Mould specialist' { return "$($r)Mould Specialist" }
        'Damp specialist'  { return "$($r)Damp Specialist" }
        'Roofer'           { return "$($r)Roofing Team" }
        'Plumber'          { return "$($r)Plumber" }
        'Pest control'     { return "$($r)Pest Control" }
        'Electrician'      { return "$($r)Electrician" }
        'Gas engineer'     { return "$($r)Gas Engineer" }
        default            { return "$($r)Maintenance Operative" }
    }
}

function Format-TicketTitle {
<#
.SYNOPSIS  Normalises a ticket title to the strict  [full address] // issue  format.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][string]$Issue
    )
    $addr  = ($Address -replace '\s+', ' ').Trim().TrimEnd(',', ' ')
    $issue = ($Issue   -replace '\s+', ' ').Trim().ToLowerInvariant()
    return ('{0} // {1}' -f $addr, $issue)
}

function Test-DuplicateWorkOrder {
<#
.SYNOPSIS
    The no-duplicate guard. Returns whether an ACTIVE work order already covers
    the same issue-family at the same property - so the agent never raises twice.
.OUTPUTS
    PSCustomObject: IsDuplicate, Reason, MatchedWorkOrder
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PropertyId,
        [Parameter(Mandatory)][string]$Category,
        [AllowNull()][object[]]$ExistingWorkOrders = @()
    )
    $family = if ($script:IssueFamily.ContainsKey($Category)) { $script:IssueFamily[$Category] } else { 'general' }

    foreach ($wo in $ExistingWorkOrders) {
        if ($null -eq $wo) { continue }
        $woFamily = if ($script:IssueFamily.ContainsKey($wo.Category)) { $script:IssueFamily[$wo.Category] } else { 'general' }
        if ($wo.PropertyId -eq $PropertyId -and $woFamily -eq $family -and $wo.Status -eq 'Active') {
            return [pscustomobject]@{
                IsDuplicate     = $true
                Reason          = ("Active WO {0} already covers '{1}' at this property" -f $wo.WorkOrderId, $family)
                MatchedWorkOrder = $wo
            }
        }
    }
    return [pscustomobject]@{ IsDuplicate = $false; Reason = "No active '$family' work order at this property"; MatchedWorkOrder = $null }
}

# ===========================================================================
#  ORCHESTRATION  (composes the pure functions into one agent decision)
# ===========================================================================

function Invoke-TicketPipeline {
<#
.SYNOPSIS
    Runs a single synthetic ticket through the full agent pipeline and returns
    the decision the agent would take. Performs NO side-effects.
.PARAMETER Ticket
    PSCustomObject with: Id, Address, Postcode, Body, OpenedDate
.PARAMETER ExistingWorkOrders
    Array of existing WO objects (PropertyId, Category, Status, WorkOrderId).
.PARAMETER AsOf
    The "now" date used for SLA ageing (defaults to today). Injectable for tests.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Ticket,
        [AllowNull()][object[]]$ExistingWorkOrders = @(),
        [datetime]$AsOf = (Get-Date)
    )

    $class  = Resolve-IssueCategory -Text $Ticket.Body
    $region = Get-Region -Postcode $Ticket.Postcode
    $trade  = $class.Trade
    $crew   = Get-RegionalContractor -Region $region -Trade $trade

    $issueWord = if ($class.DampType) { $class.DampType.ToLowerInvariant() } else { $class.Category.Replace('-', ' ') }
    $title = Format-TicketTitle -Address $Ticket.Address -Issue $issueWord

    $wdOpen = Get-WorkingDaysElapsed -From $Ticket.OpenedDate -To $AsOf
    $sla    = Get-SlaStatus -Category $class.Category -WorkingDaysOpen $wdOpen -IsEmergency:$class.IsEmergency

    $propertyId = $Ticket.Postcode  # synthetic stand-in for the property key
    $dup = Test-DuplicateWorkOrder -PropertyId $propertyId -Category $class.Category -ExistingWorkOrders $ExistingWorkOrders

    # Decide the single next action, in priority order.
    if ($class.IsHumanOnly) {
        $next = 'HOLD for human - complaint / legal language detected'
    } elseif ($class.IsEmergency) {
        $next = 'EMERGENCY - make safe within 24h, dispatch now'
    } elseif ($class.Category -eq 'pest') {
        $next = 'Send standard council pest advice automatically; raise treatment WO'
    } elseif ($dup.IsDuplicate) {
        $next = ('Skip raising - {0}; link this ticket to it' -f $dup.Reason)
    } elseif ($sla.Status -eq 'OVERDUE') {
        $next = ('RAISE WORK ORDER NOW - {0} breach; allocate {1}' -f $class.Category, $crew)
    } else {
        $next = ('Raise work order; allocate {0}' -f $crew)
    }

    $result = [pscustomobject]@{
        Id              = $Ticket.Id
        Address         = $Ticket.Address
        Region          = $region
        Category        = $class.Category
        DampType        = $class.DampType
        Trade           = $trade
        Contractor      = $crew
        Confidence      = $class.Confidence
        IsEmergency     = $class.IsEmergency
        IsHumanOnly     = $class.IsHumanOnly
        Title           = $title
        Sla             = $sla
        Duplicate       = $dup
        NextAction      = $next
        MatchedKeywords = $class.MatchedKeywords
    }
    $result | Add-Member -MemberType ScriptProperty -Name ObservationNote -Value { New-ObservationNote -Result $this } -PassThru
}

function New-ObservationNote {
<#
.SYNOPSIS  Builds the internal observation note the agent posts to the ticket.
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Result)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("OBSERVATION NOTE  -  #$($Result.Id)")
    $lines.Add("Property      : $($Result.Address)  [$($Result.Region)]")
    $cls = if ($Result.DampType) { $Result.DampType } else { (Get-Culture).TextInfo.ToTitleCase($Result.Category.Replace('-', ' ')) }
    $lines.Add("Classification: $cls  (confidence: $($Result.Confidence))")
    $lines.Add("Statutory     : $($Result.Sla.WindowDays) working days - $($Result.Sla.Basis)")
    $lines.Add("SLA status    : $($Result.Sla.Status)  ($($Result.Sla.WorkingDaysOpen) open / $($Result.Sla.DaysRemaining) remaining)")
    $lines.Add("Recommended   : $($Result.Trade) - $($Result.Contractor)")
    $lines.Add("Actions taken : acknowledgement email sent; title set to '$($Result.Title)'")
    $lines.Add("Action needed : $($Result.NextAction)")
    return ($lines -join [Environment]::NewLine)
}

Export-ModuleMember -Function @(
    'Resolve-IssueCategory','Get-SlaPolicy','Get-WorkingDaysElapsed','Get-SlaStatus',
    'Get-Region','Get-RegionalContractor','Format-TicketTitle','Test-DuplicateWorkOrder',
    'Invoke-TicketPipeline','New-ObservationNote'
)
