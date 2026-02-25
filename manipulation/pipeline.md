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
    ▼  3-ellis.R   ← clarity layer + split analyst tables
  cchs-3.sqlite + cchs-3-tables/*.parquet + 3-ellis.html
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
| 3 | `manipulation/3-ellis.R` | Ellis | `data-private/derived/cchs-3.sqlite` + `cchs-3-tables/` + `manipulation/3-ellis.html` |
| 4 | `manipulation/2-test-ellis-cache.R` | Test | Console test report |

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
source("manipulation/3-ellis.R")   # ~1 min
source("manipulation/2-test-ellis-cache.R")   # <30 sec
```

### Option C: VS Code Tasks
Use the tasks defined in `.vscode/tasks.json`:
- **Run Ferry Lane 1** — `Rscript manipulation/1-ferry.R`
- **Run Ellis Lane 2** — `Rscript manipulation/2-ellis.R`
- **Run Ellis Lane 3** — `Rscript manipulation/3-ellis.R`
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
| `cchs_analytical.parquet` | `data-private/derived/cchs-2-tables/` | Parquet | Main analysis dataset (full pooled sample mode by default) |
| `sample_flow.parquet` | `data-private/derived/cchs-2-tables/` | Parquet | Exclusion audit trail (5 rows) |
| `cchs-2.sqlite` | `data-private/derived/` | SQLite | Same tables as Parquet (factors as character) |

### Ellis Lane 3 outputs (clarity + splits)

| Artifact | Location | Format | Description |
|----------|----------|--------|-------------|
| `cchs_analytical.parquet` | `data-private/derived/cchs-3-tables/` | Parquet | Renamed analysis table: keeps retained fields, excludes selected columns, applies clarity names |
| `cchs_employed.parquet` | `data-private/derived/cchs-3-tables/` | Parquet | Employed-only split (`employment_code == 1`) |
| `cchs_unemployed.parquet` | `data-private/derived/cchs-3-tables/` | Parquet | Not-employed remainder split (`employment_code != 1` or missing); complements `cchs_employed` |
| `sample_flow.parquet` | `data-private/derived/cchs-3-tables/` | Parquet | Lane 2 flow audit carried into Lane 3 |
| `data_dictionary.parquet` | `data-private/derived/cchs-3-tables/` | Parquet | Dictionary for excluded + renamed fields |
| `cchs-3.sqlite` | `data-private/derived/` | SQLite | Same Lane 3 tables for SQL exploration |
| `3-ellis.html` | `manipulation/` | HTML | Rendered report (or fallback HTML if Pandoc unavailable) |

Lane 3 exclusions currently applied:
- `adm_rno`
- `income_5cat`
- `employment_type`
- `work_schedule`
- `alcohol_type`
- `bmi_category`
- `dhhgage`

Lane 3 key renames currently applied:
- `cycle` → `survey_cycle_id`
- `lop_015` → `employment_code`
- `adm_prx` → `proxy_code`
- `days_absent_total` → `absence_days_total`
- `days_absent_chronic` → `absence_days_chronic`
- `wts_m_pooled` → `weight_pooled`
- `wts_m_original` → `weight_original`
- `geodpmf` → `geo_region_id`

Lane 3 additionally applies broad clarity renaming for remaining retained fields
(demographics, outcomes, and chronic-condition indicators). See:
- `data-private/derived/cchs-3-tables/data_dictionary.parquet`
- `data-public/metadata/cchs-3-column-dictionary-uk.md`

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

`2-ellis.R` now runs in **full pooled sample mode by default** (`apply_sample_exclusions = FALSE`).
Legacy exclusion filtering is still available when explicitly enabled (`apply_sample_exclusions = TRUE`).

| Step | Criterion | Expected % retained |
|------|-----------|---------------------|
| 1 | Raw CCHS stacked sample | 100% |
| 2 | Age 15–75 (`dhhgage %in% 2:15`) | ~85% |
| 3 | Currently employed (`lop_015 == 1`) | ~55% |
| 4 | Non-proxy respondent (`adm_prx != 1`) | ~99% of step 3 |
| 5 | Complete outcome (any LOP var non-missing) | ~95% of step 4 |

Reference final sample:
- **Default mode (`apply_sample_exclusions = FALSE`)**: `126,431`
- **Legacy exclusion mode (`apply_sample_exclusions = TRUE`)**: ~`64,141`

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
| Final sample size (default mode) | 126,431 |
| Final sample size (legacy exclusion mode) | ~64,141 |
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
| `data-public/metadata/cchs-3-column-dictionary-uk.md` | Lane 3 column dictionary (Ukrainian) |
| `manipulation/pipeline.md` | This file |

---

*Last updated: 2026-02-22*
