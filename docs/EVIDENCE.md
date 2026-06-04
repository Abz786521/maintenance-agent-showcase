# Evidence Map

This repository is a showcase for Abdul Talib's private property-maintenance operations agent. It does not publish the production source code, prompts, credentials, integrations, tenant data, contractor data, or company records.

What it does publish is a clean-room proof of the operating logic on fictional tickets.

## What is proven here

| Evidence | File | What it shows |
|---|---|---|
| Browser dashboard demo | `demo/demo.html` and `docs/index.html` | The operator view: risk tiles, SLA badges, agent activity, ticket cards and synthetic work-order states. |
| PowerShell decision module | `demo/agent/AgentDemo.psm1` | Deterministic triage logic: issue classification, SLA windows, postcode-region routing, title formatting and duplicate prevention. |
| Runnable dry-run | `demo/agent/Run-Demo.ps1` | A complete synthetic run across overdue damp, emergency leak, complaint-language hold, pest advice, duplicate guard and routine repairs. |
| Pester tests | `tests/*.Tests.ps1` | Unit and integration coverage for the logic that matters. |
| GitHub Actions CI | `.github/workflows/ci.yml` | Cross-platform proof on Windows and Ubuntu. |

## Synthetic cases covered

| Ticket | Scenario | Expected decision |
|---|---|---|
| `#10421` | Long-open mould report in Demoville | Overdue damp/mould work order, allocate regional mould specialist. |
| `#10472` | Burst pipe and flooding in Sampleton | Emergency route, make-safe response within 24 hours. |
| `#10486` | Mould report with ombudsman language | Correctly classify the issue, but hold for human review. |
| `#10488` | Routine pest report in Testburgh | Send standard council pest advice and raise pest treatment job. |
| `#10490` | Mould where an active work order already exists | Prevent duplicate raise and link to the live work order. |
| `#10491` | Condensation wording with one mould-like signal | Resolve as condensation because the stronger signal set wins. |

## Safety rails demonstrated

- Human-only stop for complaint, legal and escalation wording.
- Emergency override independent of the base category.
- Duplicate guard across related issue families at the same property.
- Role-based contractor labels in the public demo, never real contractor identities.
- Synthetic postcode and address data only.
- No network, disk, email, ticketing, property-platform or messaging side effects in the demo logic.

## Run locally

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\demo\agent\Run-Demo.ps1
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester -Path .\tests -Output Detailed
```

## Production boundary

The production system is private. The showcase intentionally avoids real data, real integrations and operational secrets while still proving the engineering shape: repeatable logic, test coverage, CI, audit-friendly decisions and a dashboard a non-technical operator can understand.
