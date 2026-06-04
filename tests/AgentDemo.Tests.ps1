#Requires -Version 5.1
<#
  AgentDemo.Tests.ps1 - Pester v5 unit + integration tests for the demo agent.
  Run:  Invoke-Pester -Path ./tests
  (c) 2026 Abdul Talib. All Rights Reserved.
#>

BeforeAll {
    $module = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'demo/agent/AgentDemo.psm1'
    Import-Module $module -Force
}

Describe 'Resolve-IssueCategory' {

    It 'classifies clear mould wording as mould -> Mould specialist' {
        $r = Resolve-IssueCategory -Text 'black mould and mildew on the bedroom wall'
        $r.Category | Should -Be 'mould'
        $r.Trade    | Should -Be 'Mould specialist'
        $r.DampType | Should -Be 'Mould growth'
    }

    It 'distinguishes rising damp from other damp types' {
        (Resolve-IssueCategory -Text 'tide mark above the skirting, rising damp').Category | Should -Be 'rising-damp'
    }

    It 'distinguishes penetrating damp' {
        (Resolve-IssueCategory -Text 'damp patch high on the wall, worse when it rains').Category | Should -Be 'penetrating-damp'
    }

    It 'lets condensation outscore a single mould keyword when more signals point to condensation' {
        # "black spots" (1 mould hit) vs condensation + windows + behind the wardrobe (3 hits)
        (Resolve-IssueCategory -Text 'condensation on the windows and black spots behind the wardrobe').Category | Should -Be 'condensation'
    }

    It 'routes a leak to the plumber' {
        $r = Resolve-IssueCategory -Text 'water dripping from a pipe under the sink'
        $r.Category | Should -Be 'leak'
        $r.Trade    | Should -Be 'Plumber'
    }

    It 'routes roof wording to the roofer' {
        (Resolve-IssueCategory -Text 'slipped tiles and water through the ceiling').Trade | Should -Be 'Roofer'
    }

    It 'classifies pests' {
        (Resolve-IssueCategory -Text 'mice and droppings in the kitchen').Category | Should -Be 'pest'
    }

    It 'classifies electrical faults' {
        (Resolve-IssueCategory -Text 'sockets keep tripping the fuse').Category | Should -Be 'electrical'
    }

    It 'falls back to general with Low confidence when nothing matches' {
        $r = Resolve-IssueCategory -Text 'the garden gate latch is a bit stiff'
        $r.Category   | Should -Be 'general'
        $r.Confidence | Should -Be 'Low'
    }

    It 'flags emergencies independently of category' {
        (Resolve-IssueCategory -Text 'no heating and no hot water, freezing').IsEmergency | Should -BeTrue
        (Resolve-IssueCategory -Text 'black mould on the wall').IsEmergency             | Should -BeFalse
    }

    It 'flags complaint / legal language for human-only handling' {
        (Resolve-IssueCategory -Text 'I am taking this to the ombudsman').IsHumanOnly | Should -BeTrue
        (Resolve-IssueCategory -Text 'damp patch on the wall').IsHumanOnly            | Should -BeFalse
    }

    It 'returns the keywords it matched (explainability)' {
        (Resolve-IssueCategory -Text 'mould and mildew').MatchedKeywords | Should -Contain 'mould'
    }
}

Describe 'Get-SlaPolicy' {
    It 'gives damp & mould a 10 working-day window' {
        (Get-SlaPolicy -Category 'mould').WindowDays | Should -Be 10
    }
    It 'gives an active leak a 5 working-day window' {
        (Get-SlaPolicy -Category 'leak').WindowDays | Should -Be 5
    }
    It 'collapses to a 1-day window for emergencies' {
        (Get-SlaPolicy -Category 'leak' -IsEmergency).WindowDays | Should -Be 1
    }
    It 'uses the 20-day routine window for unknown categories' {
        (Get-SlaPolicy -Category 'something-odd').WindowDays | Should -Be 20
    }
}

Describe 'Get-WorkingDaysElapsed' {
    It 'counts Mon..Fri as 4 working days elapsed' {
        Get-WorkingDaysElapsed -From '2024-01-01' -To '2024-01-05' | Should -Be 4   # Mon -> Fri
    }
    It 'returns 0 for the same day' {
        Get-WorkingDaysElapsed -From '2024-01-01' -To '2024-01-01' | Should -Be 0
    }
    It 'skips the weekend (Mon -> next Mon = 5)' {
        Get-WorkingDaysElapsed -From '2024-01-01' -To '2024-01-08' | Should -Be 5
    }
    It 'counts only the Monday across a Fri -> Mon gap' {
        Get-WorkingDaysElapsed -From '2024-01-05' -To '2024-01-08' | Should -Be 1
    }
}

Describe 'Get-SlaStatus' {
    It 'is ON TRACK well inside the window' {
        (Get-SlaStatus -Category 'mould' -WorkingDaysOpen 5).Status | Should -Be 'ON TRACK'
    }
    It 'is DUE SOON within two days of the deadline' {
        (Get-SlaStatus -Category 'mould' -WorkingDaysOpen 8).Status | Should -Be 'DUE SOON'
    }
    It 'is OVERDUE past the window' {
        (Get-SlaStatus -Category 'mould' -WorkingDaysOpen 11).Status | Should -Be 'OVERDUE'
    }
    It 'computes days remaining' {
        (Get-SlaStatus -Category 'mould' -WorkingDaysOpen 3).DaysRemaining | Should -Be 7
    }
}

Describe 'Get-Region' {
    It 'maps NW postcode areas' {
        Get-Region -Postcode 'TF3 4CD' | Should -Be 'NW'
        Get-Region -Postcode 'SA5 6EF' | Should -Be 'NW'
    }
    It 'maps NE postcode areas' {
        Get-Region -Postcode 'DE1 2AB' | Should -Be 'NE'
    }
    It 'returns Unknown for unmapped areas' {
        Get-Region -Postcode 'ZZ9 9ZZ' | Should -Be 'Unknown'
    }
}

Describe 'Get-RegionalContractor' {
    It 'returns role labels, never personal names' {
        Get-RegionalContractor -Region 'NW' -Trade 'Mould specialist' | Should -Be 'NW Mould Specialist'
        Get-RegionalContractor -Region 'NE' -Trade 'Roofer'           | Should -Be 'NE Roofing Team'
    }
    It 'omits the region prefix when region is Unknown' {
        Get-RegionalContractor -Region 'Unknown' -Trade 'Plumber' | Should -Be 'Plumber'
    }
}

Describe 'Format-TicketTitle' {
    It 'produces [address] // issue' {
        Format-TicketTitle -Address '12 Example Terrace, Demoville, DE1 2AB' -Issue 'Mould Growth' |
            Should -Be '12 Example Terrace, Demoville, DE1 2AB // mould growth'
    }
    It 'collapses whitespace and trims trailing commas' {
        Format-TicketTitle -Address "  4 Sample   Street,  " -Issue '  Damp ' | Should -Be '4 Sample Street // damp'
    }
}

Describe 'Test-DuplicateWorkOrder (no-duplicate guard)' {
    BeforeAll {
        $wos = @(
            [pscustomobject]@{ WorkOrderId='WO-1'; PropertyId='EX2 3LM'; Category='mould'; Status='Active' }
            [pscustomobject]@{ WorkOrderId='WO-2'; PropertyId='DE1 2AB'; Category='leak';  Status='Closed' }
        )
    }
    It 'flags a duplicate when an ACTIVE WO covers the same issue-family at the property' {
        # condensation shares the damp-mould family with the active mould WO
        $d = Test-DuplicateWorkOrder -PropertyId 'EX2 3LM' -Category 'condensation' -ExistingWorkOrders $wos
        $d.IsDuplicate | Should -BeTrue
        $d.MatchedWorkOrder.WorkOrderId | Should -Be 'WO-1'
    }
    It 'does NOT flag when the only matching WO is Closed' {
        (Test-DuplicateWorkOrder -PropertyId 'DE1 2AB' -Category 'leak' -ExistingWorkOrders $wos).IsDuplicate | Should -BeFalse
    }
    It 'does NOT flag a different issue-family at the same property' {
        (Test-DuplicateWorkOrder -PropertyId 'EX2 3LM' -Category 'electrical' -ExistingWorkOrders $wos).IsDuplicate | Should -BeFalse
    }
    It 'does NOT flag a different property' {
        (Test-DuplicateWorkOrder -PropertyId 'TF3 4CD' -Category 'mould' -ExistingWorkOrders $wos).IsDuplicate | Should -BeFalse
    }
}

Describe 'Invoke-TicketPipeline (integration)' {
    BeforeAll {
        $asOf = [datetime]'2024-03-01'
        $activeWO = ,([pscustomobject]@{ WorkOrderId='WO-9'; PropertyId='EX2 3LM'; Category='mould'; Status='Active' })
    }

    It 'raises immediately for an overdue damp/mould ticket' {
        $t = [pscustomobject]@{ Id=1; Address='12 Example Terrace, Demoville, DE1 2AB'; Postcode='DE1 2AB'
            OpenedDate=[datetime]'2024-01-02'; Body='black mould spreading on the bedroom wall' }
        $r = Invoke-TicketPipeline -Ticket $t -AsOf $asOf
        $r.Sla.Status | Should -Be 'OVERDUE'
        $r.NextAction | Should -Match 'RAISE WORK ORDER NOW'
        $r.Contractor | Should -Be 'NE Mould Specialist'
    }

    It 'escalates an emergency regardless of age' {
        $t = [pscustomobject]@{ Id=2; Address='9 Mock Avenue, Sampleton, SA5 6EF'; Postcode='SA5 6EF'
            OpenedDate=$asOf; Body='burst pipe, water flooding the kitchen' }
        (Invoke-TicketPipeline -Ticket $t -AsOf $asOf).NextAction | Should -Match 'EMERGENCY'
    }

    It 'holds complaint/legal tickets for a human' {
        $t = [pscustomobject]@{ Id=3; Address='21 Placeholder Road, Demo City, DC7 8GH'; Postcode='DC7 8GH'
            OpenedDate=$asOf; Body='black mould again, I am going to the ombudsman' }
        (Invoke-TicketPipeline -Ticket $t -AsOf $asOf).NextAction | Should -Match 'HOLD for human'
    }

    It 'prevents a duplicate when an active WO already covers the property/family' {
        $t = [pscustomobject]@{ Id=4; Address='7 Imaginary Lane, Exampleford, EX2 3LM'; Postcode='EX2 3LM'
            OpenedDate=$asOf; Body='mould around the bathroom window' }
        (Invoke-TicketPipeline -Ticket $t -ExistingWorkOrders $activeWO -AsOf $asOf).NextAction | Should -Match 'Skip raising'
    }

    It 'sends automatic advice for routine pest tickets' {
        $t = [pscustomobject]@{ Id=5; Address='2 Fictional Close, Testburgh, TB9 0JK'; Postcode='TB9 0JK'
            OpenedDate=$asOf; Body='mice in the kitchen again' }
        (Invoke-TicketPipeline -Ticket $t -AsOf $asOf).NextAction | Should -Match 'pest advice'
    }

    It 'emits an observation note carrying the key decision fields' {
        $t = [pscustomobject]@{ Id=6; Address='33 Dummy Drive, Testfield, TF3 9QR'; Postcode='TF3 9QR'
            OpenedDate=$asOf; Body='damp patch high on the wall, worse after rain' }
        $note = (Invoke-TicketPipeline -Ticket $t -AsOf $asOf).ObservationNote
        $note | Should -Match 'OBSERVATION NOTE'
        $note | Should -Match 'Penetrating damp'
        $note | Should -Match 'NW Damp Specialist'
    }
}
