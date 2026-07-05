---
name: assemble-selected-sample
description: 'Assemble canonical selected-sample.csv for Ellis sample filtering by merging person_oid from auto-screened-clients.csv and handpicked-clients.csv. Runs auto-screen-clients.R first when auto-screened output is missing.'
argument-hint: 'Optional: ask to refresh auto-screened outputs before merge, or only assemble from existing files.'
user-invocable: false
---

# Assemble Selected Sample

Creates the canonical representative sample include-list at:
`data-private/derived/manipulation/selected-sample.csv`.

## When To Use

- Before running `manipulation/1-ellis-event.R` with sample filter enabled
- After changing `data-public/raw/manipulation/handpicked-clients.csv`
- After rerunning `manipulation/nonflow/auto-screen-clients/auto-screen-clients.R`
- When selected-sample paths were moved or refreshed

## Inputs

| Input | Source | Required |
|-------|--------|----------|
| Auto-screened clients | `data-public/derived/manipulation/auto-screen-clients/auto-screened-clients.csv` | Yes (auto-generated if missing) |
| Handpicked clients | `data-public/raw/manipulation/handpicked-clients.csv` | Yes |
| Path config | `config.yml` -> `representative_sample` | Yes |

## Procedure

### Step 1 - Assemble Canonical Sample

Run:

```r
source("manipulation/nonflow/auto-screen-clients/assemble-selected-sample.R")
```

Behavior:

- If auto-screened output is missing, the script runs
  `manipulation/nonflow/auto-screen-clients/auto-screen-clients.R` first.
- It then merges `person_oid` from handpicked and auto-screened sources.
- It writes a de-duplicated canonical include-list to
  `data-private/derived/manipulation/selected-sample.csv`.

### Step 2 - Validate Output

Confirm the output exists and contains expected `person_oid` count.
If needed, run `manipulation/1-ellis-event.R` and verify sample size in logs.

## Related Files

| File | Role |
|------|------|
| `manipulation/nonflow/auto-screen-clients/assemble-selected-sample.R` | Canonical sample assembler |
| `manipulation/nonflow/auto-screen-clients/auto-screen-clients.R` | Auto-screen process |
| `data-public/raw/manipulation/handpicked-clients.csv` | Manual input list |
| `data-private/derived/manipulation/selected-sample.csv` | Canonical output consumed by Ellis |
