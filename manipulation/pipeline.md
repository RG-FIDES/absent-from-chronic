# Data Pipeline: absent-from-chronic

Execution guide for the CCHS work-absenteeism data pipeline.

---

## Overview

```
CCHS .sav files (data-private/raw/)
         │
         ▼  1-ferry.R   ← zero semantic transformation
  cchs-1.sqlite + cchs-1-raw/*.parquet   (staging)
         │
         ▼  2-ellis.R   ← white-list + harmonize + recode
  cchs-2.sqlite + cchs-2-tables/*.parquet   (analysis-ready)
         │
         ▼  2-test-ellis-cache.R   ← alignment verification
  console report (pass/fail)
```

---

## Scripts

| # | File | Pattern | Output |
|---|------|---------|--------|
| 1 | `manipulation/1-ferry.R` | Ferry | `data-private/derived/cchs-1.sqlite` + Parquet backup |
| 2 | `manipulation/2-ellis.R` | Ellis | `data-private/derived/cchs-2.sqlite` + `cchs-2-tables/` Parquet |
| 3 | `manipulation/2-test-ellis-cache.R` | Test | Console test report |

---

## Running the Pipeline

### Option A: Full pipeline via flow.R
```r
source("flow.R")
```
Runs ferry → ellis → all downstream analyses in sequence.

### Option B: Individual scripts
```r
source("manipulation/1-ferry.R")   # ~2–5 min depending on file size
source("manipulation/2-ellis.R")   # ~1–2 min
source("manipulation/2-test-ellis-cache.R")   # <30 sec
```

### Option C: VS Code Tasks
Use the tasks defined in `.vscode/tasks.json`:
- **Run Ferry Lane 1** — `Rscript manipulation/1-ferry.R`
- **Run Ellis Lane 2** — `Rscript manipulation/2-ellis.R`
- **Test Ellis ↔ CACHE-Manifest Alignment** — `Rscript manipulation/2-test-ellis-cache.R`

---

## Inputs

| File | Location | Cycle |
|------|----------|-------|
| `CCHS2010_LOP.sav` | `data-private/raw/2026-02-19/` | 2010–2011 |
| `CCHS_2014_EN_PUMF.sav` | `data-private/raw/2026-02-19/` | 2013–2014 |

Paths are configured in `config.yml` under `raw_data`.

---

## Outputs

### Ferry outputs (staging — not for analysis)

| Artifact | Location | Description |
|----------|----------|-------------|
| `cchs-1.sqlite` | `data-private/derived/` | Raw tables: `cchs_2010_raw`, `cchs_2014_raw` |
| `cchs-1-raw/*.parquet` | `data-private/derived/cchs-1-raw/` | Parquet backups of raw tables |

### Ellis outputs (analysis-ready)

| Artifact | Location | Format | Description |
|----------|----------|--------|-------------|
| `cchs_analytical.parquet` | `data-private/derived/cchs-2-tables/` | Parquet | Main analysis dataset (~64k rows) |
| `sample_flow.parquet` | `data-private/derived/cchs-2-tables/` | Parquet | Exclusion audit trail (5 rows) |
| `cchs-2.sqlite` | `data-private/derived/` | SQLite | Same tables as Parquet (factors as character) |

**Parquet is the primary format** — it preserves R factor types and level ordering, which
matters for downstream models and plots. SQLite is a secondary convenience format.

---

## White-List Design

Ellis uses a **two-tier white-list** to select only variables needed for the analysis.
This keeps the analysis-ready dataset focused and avoids processing ~1,400 irrelevant columns.

### Tier 1: CONFIRMED (hard error if missing)
13 variables verified against PDF data dictionaries. If any are absent, Ellis fails loudly.
See `vars_confirmed` in `2-ellis.R` → `declare-globals` section.

### Tier 2: INFERRED (graceful warning if missing)
~60 variables inferred from standard CCHS PUMF naming conventions. If any are absent,
Ellis logs a warning with a list of missing names and drops them. Analysis continues.

**To update the white-list:**
1. Open `manipulation/2-ellis.R`
2. Navigate to `# ---- declare-globals`
3. Modify `vars_confirmed` or the relevant `vars_inferred_*` vector
4. Re-run Ellis and the test script

---

## Exclusion Criteria (sample_flow)

| Step | Criterion | Expected % retained |
|------|-----------|---------------------|
| 1 | Raw CCHS stacked sample | 100% |
| 2 | Age 15–75 (`dhhgage %in% 2:15`) | ~85% |
| 3 | Currently employed (`lop_015 == 1`) | ~55% |
| 4 | Non-proxy respondent (`adm_prx != 1`) | ~99% of step 3 |
| 5 | Complete outcome (any LOP var non-missing) | ~95% of step 4 |

Reference final sample: **~64,141** respondents.

---

## Survey Weight Pooling

Two CCHS cycles are pooled into a single dataset. Per Statistics Canada guidelines:

```
wts_m_pooled = wts_m / 2     # for each respondent
bsw001_pooled = bsw001 / 2   # same for all 500 bootstrap weights
```

`wts_m_original` is kept alongside `wts_m_pooled` for verification.

---

## Diagnostic Checkpoints

After running `2-ellis.R`, verify these values match expectations:

| Diagnostic | Reference |
|------------|-----------|
| Final sample size | ~64,141 |
| Weighted mean `days_absent_total` | ≈ 1.35 |
| % zeros in `days_absent_total` | ≈ 70.6% |
| Variance of `days_absent_total` | ≈ 17.7 |
| White-list misses (INFERRED tier) | 0 ideally; warn if >5 |

---

## Troubleshooting

**"Variable X not found" (confirmed tier)**  
→ The variable was renamed in this cycle's PUMF. Check the PDF data dictionary and add
  a harmonization step in `2-ellis.R` under `# ---- SECTION 1 / harmonize`.

**White-list inferred warnings**  
→ Some CCHS predictor variables may have slightly different names (e.g., `GEN_02` vs
  `GEN_02A`). Open the data dictionary for that module and update `vars_inferred_*` in
  `2-ellis.R` → `declare-globals`.

**DHHGAGE codes outside 2–15 seen in data**  
→ Verify age category coding against the PDF data dictionary for each cycle.
  Adjust `dhhgage %in% 2:15` in `tweak-data-2-exclusions` accordingly.

**SQLite and Parquet row counts don't match**  
→ Run `manipulation/2-test-ellis-cache.R` — it will identify the parity failure specifically.
  Re-run `2-ellis.R` to regenerate both outputs atomically.

---

## Data Documentation

| File | Contents |
|------|----------|
| `data-public/metadata/INPUT-manifest.md` | Raw source file descriptions |
| `data-public/metadata/CACHE-manifest.md` | Analysis-ready dataset descriptions (auto-updated by Ellis) |
| `manipulation/pipeline.md` | This file |

---

*Last updated: 2026-02-19*
