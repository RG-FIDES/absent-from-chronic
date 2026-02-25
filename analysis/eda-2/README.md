# EDA-2 — Distribution of Absence Days Among Employed Canadians

**Status**: Complete — g1–g7 graph families rendered; Quarto report produced.

## Purpose

Explore how work absence days (`absence_days_total`) are distributed among employed Canadian respondents in the CCHS 2010-11 and 2013-14 survey cycles. This is a descriptive EDA; no modelling is attempted here.

**Research question**: How many absence days do employed Canadians report, and how does that distribution vary by sex, age, survey cycle, education, marital status, and immigration status?

## Data Source

| Item | Value |
|------|-------|
| Table | `cchs_employed` in `data-private/derived/cchs-3.sqlite` |
| Rows | 64,248 employed respondents (one row each) |
| Key variable | `absence_days_total` — total work days missed due to any health reason (integer) |
| Survey cycles | CCHS 2010-11 and CCHS 2013-14 |

## Data Pipeline

```
ds0   64,248 rows — raw cchs_employed load; absence_days_total coerced to integer;
      has_any_absence derived flag.

ds1   Filtered from ds0: exclude absence_days_total == 0 and IS NULL.
      Working dataset for all graph families (respondents with 1+ absence days).

ds5   ds1 minus respondents with NA education_level  — used in g5 only
ds6   ds1 minus respondents with NA marital_status_label — used in g6 only
ds7   ds1 minus respondents with NA immigration_status_label — used in g7 only

absence_ratio_tbl   overall zero vs. 1+ vs. not-reported proportions (from ds0)
sex_ratio_tbl       per-sex zero vs. 1+ proportions (from ds0, answered only)
```

Per-variable NA exclusion is deliberate: each family uses only the filter relevant to its variable, maximising n and avoiding an NA facet panel.

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
- **Graph dimensions**: single-panel 8.5 × 5.5 in; two-panel 11 × 5.5 in; three-panel 13 × 5.5 or 13 × 6.5 in; all at 300 DPI.

## Files

| File | Role |
|------|------|
| `eda-2.R` | Development script — all code, `# ---- chunk-name ----` sections |
| `eda-2.qmd` | Publication layer — calls `read_chunk("analysis/eda-2/eda-2.R")`, no code duplication |
| `data-local/` | Intermediate outputs, e.g. `g3_stats_age.csv` (git-ignored; reproduced by script) |
| `prints/` | High-resolution PNG exports via `ggsave()` (git-ignored by pattern) |
| `figure-png-iso/` | Quarto chunk figure cache |

## Quick Start

Run the full R script from the repo root:

```r
source("analysis/eda-2/eda-2.R")
```

Render the Quarto report:

```powershell
quarto render analysis/eda-2/eda-2.qmd
```

Or use the VS Code task **Render EDA-2 Quarto Report** if configured in `.vscode/tasks.json`.

## Interactive Plotting (VS Code)

The script auto-starts `httpgd` when it detects an interactive session. Install it once if needed:

```powershell
Rscript -e "install.packages('httpgd', repos='https://cran.rstudio.com')"
```
