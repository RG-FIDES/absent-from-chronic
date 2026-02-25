# Session Log: EDA-2 — Distribution of Absence Days

**Date**: 2026-02-23
**Persona**: Grapher
**Project**: absent-from-chronic

---

## Session Objective

Build `analysis/eda-2/eda-2.R` and `analysis/eda-2/eda-2.qmd` from scratch: explore the distribution of `absence_days_total` among employed Canadians from `cchs_employed` (Lane 3 output), produce graph families g1–g7 faceted by demographic/socioeconomic variables, and document findings in the paired Quarto report.

---

## Data Source

- **Table**: `cchs_employed` in `data-private/derived/cchs-3.sqlite`
- **Rows**: 64,248 employed respondents (one row each)
- **Key column**: `absence_days_total` — total work days missed due to any health reason (integer)
- **Survey cycles**: CCHS 2010-11 and CCHS 2013-14

---

## Data Pipeline Decisions

### ds0 — raw load
All 64,248 `cchs_employed` rows; `absence_days_total` coerced to integer; `has_any_absence` derived.

### ds1 — working dataset
Filtered from ds0: exclude `absence_days_total IS NULL` and `= 0`. Respondents with one or more absence days only. Used as the base for all graph families.

**Rationale**: The research question targets the *amount* of absence, not *whether* absence occurs. Zero-day and NA respondents are still counted in the overall ratio analytic (`absence_ratio_tbl`) for context.

### ds5 / ds6 / ds7 — per-variable NA exclusions
Because `education_level`, `marital_status_label`, and `immigration_status_label` have non-trivial NA counts, individual filtered subsets were created to avoid an NA facet panel:
- `ds5 <- ds1 |> filter(!is.na(education_level))`
- `ds6 <- ds1 |> filter(!is.na(marital_status_label))`
- `ds7 <- ds1 |> filter(!is.na(immigration_status_label))`

Each subset's excluded count is logged at runtime. Graph subtitles declare which exclusions apply.

---

## Graph Families Built

All graphs share:
- `coord_cartesian(xlim = c(1, 40))` — zoom without dropping tail data from bin calculations
- `binwidth = 5`, breaks at `c(1, seq(5, 40, by = 5))`
- Median: dashed firebrick `geom_vline` + white-background bold label
- Mean: dotted darkorange `geom_vline` + white-background bold label
- For faceted graphs: `geom_label(data = stats_df, ..., inherit.aes = FALSE)` — required because `annotate()` ignores facets

| Family | Variable | Dataset | Palette | Width × Height |
|--------|----------|---------|---------|----------------|
| g1 | overall | ds1 | steelblue (fixed) | 8.5 × 5.5 |
| g2 | sex_label | ds1 | Manual (steelblue / tomato) | 11 × 5.5 |
| g3 | age_group_3 | ds1 | Set2 | 13 × 5.5 |
| g4 | survey_cycle_label | ds1 | Set1 | 11 × 5.5 |
| g5 | education_level | ds5 | Set3 | 13 × 6.5 |
| g6 | marital_status_label | ds6 | Paired | 13 × 6.5 |
| g7 | immigration_status_label | ds7 | Dark2 | 13 × 6.5 |

g1 produces both a **scatter** (unique day-value × respondent count) and a **histogram**.
g4 also produces both a scatter and a histogram (cycle-level replication of g1).
g2–g3 and g5–g7 produce histograms only.

g3_stats saved to `analysis/eda-2/data-local/g3_stats_age.csv` for downstream reference.

---

## Analytics (non-graph)

### analytic-absence-ratio
`absence_ratio_tbl`: overall count and percentage of zero-absence vs. 1+ vs. not-reported respondents (from ds0). Gives the reader the majority-pattern context before the graphs.

### analytic-sex-ratio
`sex_ratio_tbl`: per-sex count and percentage of zero-absence vs. 1+ respondents (from ds0, answered only). Placed in the g2 section to contextualize the within-sex histograms.

---

## Key Design Decisions

1. **R + Quarto dual-file pattern**: All code lives in `eda-2.R` with `# ---- chunk-name ----` headers. `eda-2.qmd` calls `read_chunk("analysis/eda-2/eda-2.R")` and references chunks by label — no code duplication.
2. **coord_cartesian over filter**: Data beyond x = 40 is retained in histogram bins; only the viewport is clipped. This preserves honest bin heights at the boundary.
3. **annotate vs. geom_label**: Single-panel graphs use `annotate("label", ...)`. Faceted graphs use `geom_label(data = stats_df, ..., inherit.aes = FALSE)` so each facet panel gets its correctly matched label.
4. **Per-variable NA datasets (ds5/ds6/ds7)**: Rather than dropping all rows with any NA across grouping variables, each family uses only the NA filter relevant to its variable. This maximizes n and avoids cascading exclusions.

---

## Files Produced / Modified

| File | Action |
|------|--------|
| `analysis/eda-2/eda-2.R` | Written from scratch; complete g1–g7 |
| `analysis/eda-2/eda-2.qmd` | Written from scratch; mirrors R chunks |
| `analysis/eda-2/data-local/g3_stats_age.csv` | Created at runtime |
| `analysis/eda-2/prints/g1_scatter.png` | Created at runtime |
| `analysis/eda-2/prints/g1_hist.png` | Created at runtime |
| `analysis/eda-2/prints/g2_hist_sex.png` | Created at runtime |
| `analysis/eda-2/prints/g3_hist_age.png` | Created at runtime |
| `analysis/eda-2/prints/g4_scatter_cycle.png` | Created at runtime |
| `analysis/eda-2/prints/g4_hist_cycle.png` | Created at runtime |
| `analysis/eda-2/prints/g5_hist_edu.png` | Created at runtime |
| `analysis/eda-2/prints/g6_hist_marital.png` | Created at runtime |
| `analysis/eda-2/prints/g7_hist_immigration.png` | Created at runtime |

---

## Next Steps

- Run the full script to confirm all graphs render without errors
- Review g5 / g6 / g7 panel counts — verify all expected factor levels appear
- Consider adding analytic tables for g3, g5, g6, g7 (similar to analytic-sex-ratio) in a future session
- Begin modelling (regression) in a subsequent EDA or a dedicated analysis lane
