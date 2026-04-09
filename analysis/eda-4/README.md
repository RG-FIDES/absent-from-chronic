# EDA-4: Missing Data Analysis and Descriptive Statistics

## Overview

**EDA-4** investigates questions **5.1** and **5.2** from `stats_instructions_v3.md`:

- **Q5.1 — Handling Missing Data**: Apply Little's MCAR test, document proportion of missing values per variable, and visualize missingness patterns using `naniar` package functions.
- **Q5.2 — Descriptive Statistics (Table 1)**: Produce comprehensive descriptive statistics for the overall pooled sample and stratified by CCHS cycle (2011 vs. 2014), with both unweighted and weighted frequencies, proportions, and outcome variable means/SDs.

## Directory Structure

```
eda-4/
├── report-contract.prompt.md    # Structured brief for this analysis
├── eda-4.R                      # Analytical laboratory (exploration, wrangling, visualization)
├── eda-4.qmd                    # Publication layer (narrative, code sourcing, results)
├── data-local/                  # Intermediate processing files and cached objects
├── prints/                      # High-resolution plot exports (8.5×5.5 in, 300 DPI)
├── figure-png-iso/              # Quarto-generated figures (auto-populated on render)
└── README.md                    # This file
```

## Key Concepts

### Missing Data Analysis (Q5.1)

Investigates whether the CCHS data satisfy the **Missing Completely At Random (MCAR)** assumption using:

- **Little's MCAR Test** (via `mice::mcar()` or equivalent) to formally test MCAR hypothesis
- **Visualizations** using `naniar::vis_miss()`, `naniar::gg_miss_var()`, `naniar::gg_miss_upset()` to show patterns
- **Summary statistics** documenting proportion missing per variable and co-occurrence patterns

**Decision rule**: If <5% missing and MCAR assumption holds → treat as separate category or use listwise deletion. Otherwise → consider multiple imputation.

### Descriptive Statistics (Q5.2)

Produces **Table 1** according to statistical guidelines:

- **Study population**: Overall pooled sample (N across both cycles)
- **Stratification**: Separate columns for each CCHS cycle (2011, 2014)
- **Categorical variables**: Unweighted and weighted frequencies, proportions (%)
- **Continuous variables**: Weighted mean, standard deviation (accounting for survey design)
- **Outcome variables**: Days absent (total and chronic) with weighted descriptive statistics

**Survey design**: Uses `survey` package to properly account for complex sampling design with probability weights (`wts_m_pooled`).

## Data Sources

- **Primary**: `data-private/derived/cchs-2-tables/cchs_analytical.parquet` (Ellis output)
- **Reference**: `analysis/data-primer-1/` for comprehensive variable documentation
- **Requirements**: `data-private/raw/2026-02-19/stats_instructions_v3.md`

## Execution

### Initial Setup

1. Open `eda-4.R` and run the data-loading sections to confirm:
   - Analytical data loads without errors
   - Key variables are present and correctly typed
   - Unit of analysis (person-level, person-cycle, other) is confirmed

2. Run companion `.qmd` file to generate HTML report:
   ```bash
   quarto render analysis/eda-4/eda-4.qmd
   ```

### Development Workflow (Dual-File Pattern)

- **`.R` script**: All exploration, data wrangling, graph family development, and model fitting happens here. Use `ggsave()` to export plots.
- **`.qmd` document**: Source chunks from `.R` via `read_chunk()`. Use `print(plot_object)` for HTML display. Provide narrative context.

**Chunk naming convention**:
- `g1`, `g2`, `g3`… — Individual graphs or graph families
- `g21`, `g22`… — Members of family g2 (e.g., alternative views, subsets)
- `t1`, `t2`… — Summary tables and statsiscal analyses
- `m1`, `m2`… — Statistical models

## Tasks (Draft → Active)

- [ ] Confirm Ellis parquet loads and contains required variables
- [ ] Implement g1 (missing data heatmap using `naniar`)
- [ ] Implement g2/g21/g22 (missing data visualizations and distributions)
- [ ] Implement t3 (Little's MCAR test and missing data summary)
- [ ] Implement t1 (Table 1 — descriptive statistics stratified by cycle)
- [ ] Implement t2 (Outcome variable statistics with survey weighting)
- [ ] Validate all frequencies, means, and SDs against raw data
- [ ] Generate final `.html` report via `quarto render`
- [ ] Update `report-contract.prompt.md` Status to `active`, then `complete`

## Key Packages

| Package | Purpose |
|---------|---------|
| `dplyr` | Data wrangling |
| `tidyr` | Data reshaping |
| `survey` | Complex survey design analysis |
| `naniar` | Missing data visualization |
| `mice` | Little's MCAR test and missing data diagnostics |
| `ggplot2` | Visualization |
| `arrow` | Parquet I/O |

## References

- **CCHS Documentation**: `data-public/metadata/CACHE-manifest.md`
- **Data Primer**: `analysis/data-primer-1/data-primer-1.html`
- **Style Guide**: `analysis/eda-1/eda-style-guide.md`
- **Composing Orchestra**: `.github/composing-orchestra-1.md`
- **Survey Methods**: Lumley, T. (2011). *Complex Surveys: A Guide to Analysis Using R*.

---

**Status**: Draft  
**Last Updated**: 2026-03-24
