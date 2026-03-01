# EDA-3 — Distribution of Chronic Absence Days Among Employed Canadians

**Status**: In progress — scripts ready to run; Quarto report not yet rendered.

## Purpose

Explore how **chronic** work absence days (`absence_days_chronic`) are distributed among employed Canadian respondents in the CCHS 2010-11 and 2013-14 survey cycles. This EDA replicates the EDA-2 analytical structure and graph families using the chronic-condition sub-measure (`absence_days_chronic`) in place of total absence (`absence_days_total`). No modelling is attempted here.

**Research question**: How many absence days attributable to a chronic health condition do employed Canadians report, and how does that distribution vary by sex, age, survey cycle, education, marital status, and immigration status?

## Relationship to EDA-2

| Dimension | EDA-2 | EDA-3 |
|-----------|-------|-------|
| Key variable | `absence_days_total` | `absence_days_chronic` |
| Source table | `cchs_employed` | `cchs_employed` |
| Source file | `cchs-3.sqlite` | `cchs-3.sqlite` |
| Graph families | g1–g7 | g1–g7 (identical structure) |
| Demographic breakdowns | sex, age, cycle, education, marital, immigration | sex, age, cycle, education, marital, immigration |

## Data Source

| Item | Value |
|------|-------|
| Table | `cchs_employed` in `data-private/derived/cchs-3.sqlite` |
| Rows | 64,248 employed respondents (one row each) |
| Key variable | `absence_days_chronic` — work days missed due to a chronic health condition (integer) |
| Survey cycles | CCHS 2010-11 and CCHS 2013-14 |

## Data Pipeline

```
ds0   64,248 rows — raw cchs_employed load; absence_days_chronic coerced to integer;
      has_any_chronic derived flag.

ds1   Filtered from ds0: exclude absence_days_chronic == 0 and IS NULL.
      Working dataset for all graph families (respondents with 1+ chronic absence days).

ds5   ds1 minus respondents with NA education_level       — used in g5 only
ds6   ds1 minus respondents with NA marital_status_label  — used in g6 only
ds7   ds1 minus respondents with NA immigration_status_label — used in g7 only

chronic_ratio_tbl   overall zero vs. 1+ vs. not-reported proportions (from ds0)
sex_ratio_tbl       per-sex zero vs. 1+ chronic absence proportions (from ds0, answered only)
```

Per-variable NA exclusion is deliberate: each family uses only the filter relevant to its variable, maximising n and avoiding blank facet panels.

## Graph Families

| Family | Variable | Dataset | Palette | Output file(s) |
|--------|----------|---------|---------|----------------|
| g1 | overall | ds1 | steelblue (fixed) | `g1_scatter.png`, `g1_hist.png` |
| g2 | `sex_label` | ds1 | manual steelblue/tomato | `g2_hist_sex.png` |
| g3 | `age_group_3` | ds1 | Set2 | `g3_hist_age.png` |
| g4 | `survey_cycle_label` | ds1 | Set1 | `g4_scatter_cycle.png`, `g4_hist_cycle.png` |
| g5 | `education_level` | ds5 | Set3 | `g5_hist_edu.png` |
| g6 | `marital_status_label` | ds6 | Paired | `g6_hist_marital.png` |
| g7 | `immigration_status_label` | ds7 | Dark2 | `g7_hist_immigration.png` |

All outputs saved to `prints/`.

## Conventions

- **X-axis zoom**: `coord_cartesian(xlim = c(1, 40))` on all graphs — tail data beyond 40 is retained in bin calculations but not shown in the viewport.
- **Bins**: `binwidth = 5`, breaks at `c(1, seq(5, 40, by = 5))`.
- **Median line**: dashed firebrick `geom_vline` + white-background bold label.
- **Mean line**: dotted darkorange `geom_vline` + white-background bold label.
- **Faceted graphs**: `geom_label(data = stats_df, ..., inherit.aes = FALSE)` for per-panel labels (`annotate()` ignores facets).
- **Graph dimensions**: single-panel 8.5 x 5.5 in; two-panel 11 x 5.5 in; three-panel 13 x 5.5 or 13 x 6.5 in; all at 300 DPI.

## Files

| File | Role |
|------|------|
| `eda-3.R` | Development script — all code, `# ---- chunk-name ----` sections |
| `eda-3.qmd` | Publication layer — calls `read_chunk("analysis/eda-3/eda-3.R")`, no code duplication |
| `data-local/` | Intermediate outputs, e.g. `g3_stats_age.csv` (git-ignored; reproduced by script) |
| `prints/` | High-resolution PNG exports via `ggsave()` (git-ignored by pattern) |
| `figure-png-iso/` | Quarto chunk figure cache |

## Quick Start

Run the full R script from the repo root:

```r
source("analysis/eda-3/eda-3.R")
```

Render the Quarto report:

```bash
quarto render analysis/eda-3/eda-3.qmd
```
