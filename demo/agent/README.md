# Clean-Room Agent Demo

This folder contains the original, synthetic-data decision demo for the property-maintenance agent. It is not the production system.

## Files

| File | Purpose |
|---|---|
| `AgentDemo.psm1` | Pure PowerShell functions for classification, SLA scoring, region routing, duplicate detection and observation-note generation. |
| `Run-Demo.ps1` | A no-install dry run over fictional tickets and fictional work orders. |

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\demo\agent\Run-Demo.ps1
```

## Decision flow

1. Read the tenant wording.
2. Score keyword evidence for the most likely maintenance category.
3. Detect emergency and human-only language independently of the category.
4. Calculate working-day SLA status from the synthetic opened date.
5. Map the postcode area to a synthetic operating region.
6. Check for active work orders in the same issue family.
7. Emit one next action and an internal observation note.

## What this deliberately avoids

- No Freshdesk, Arthur, WhatsApp, email or spreadsheet access.
- No real tenants, properties, contractors, company names or addresses.
- No disk writes, network calls or live work-order creation.
- No production source code or proprietary integration details.
