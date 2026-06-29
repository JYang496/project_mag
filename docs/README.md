# Documentation Layout

This folder keeps long-lived project documentation separate from generated or operational artifacts.

- `design/`: durable design contracts, implementation plans, and system decisions.
- `audits/`: code, UX, content, and workflow audit findings.
- `reports/`: generated or snapshot reports, including HTML review artifacts.
- `reports/dps/`: DPS benchmark outputs and related combat measurement reports.
- `prompt/`: worker, integrator, and handoff prompt artifacts.

Keep new docs in the most specific folder that matches their purpose. Generated reports should not be treated as source-of-truth design docs unless they are manually promoted into `design/` or `audits/`.
