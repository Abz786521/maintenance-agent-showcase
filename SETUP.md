# Setup & Demo

> This repository is a **showcase**. The real system is private and proprietary (© Abdul Talib).
> What you can run here is a **self-contained demo** of the operations dashboard, powered by
> **synthetic sample data** — no server, no install, no real data of any kind.

## ▶️ Run the demo (10 seconds, runs anywhere)

1. Download or clone this repository.
2. Open **`demo/demo.html`** in any modern web browser (double-click it).

That's it. The demo loads built-in sample tickets and renders the live operations dashboard exactly as it looks in production — metric tiles, priority/SLA badges, the agent-activity panel, and ticket cards — using made-up tenants and addresses.

No internet connection, no Node, no PowerShell, and no configuration are required. Everything the demo needs is embedded in the single HTML file.

## What you're looking at

| In the demo | What it represents in production |
|---|---|
| **Metric tiles** (Overdue damp, Awaiting reply, Urgent…) | Live risk summary across all open tickets |
| **Red "OVERDUE" / amber badges** | Damp/mould jobs scored against statutory response windows |
| **REPEAT / NO REPLY badges** | Duplicate-tenant detection + acknowledgement tracking |
| **Agent activity panel** | What the autonomous agent is doing now + next, with countdowns |
| **Ticket cards** | Each tenant issue, auto-titled and auto-triaged to the right trade |

All names, addresses and tickets shown are **fictional**.

## How the real system runs (overview only)

The production system is **not** in this repository. At a high level it consists of:

- a lightweight automation **server** + **live dashboard**,
- background **work-runners** (acknowledge, title, triage, pest, sign-off),
- secure local **browser bridges** to the property-management and messaging platforms,
- a supervising **watchdog** that keeps everything alive 24/7 and self-heals on failure.

It binds to **loopback only** (no inbound network exposure), keeps all credentials in a local config that is **never** committed, and writes a full **audit log** of every action. None of that code, configuration, or data is included here.

## License

© 2026 **Abdul Talib** — All Rights Reserved. See [`LICENSE.txt`](LICENSE.txt). You may view this showcase; you may not copy, reuse, or build from it.
