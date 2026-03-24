# Report Contract: eda-4

## Type
EDA

## Date
2026-03-24 | Last updated: 2026-03-24

## Status
complete

## Mission
This EDA addresses questions **5.1** and **5.2** from `stats_instructions_v3.md`. It investigates missing data patterns across predictor variables using Little's MCAR test and visualization techniques, and produces comprehensive descriptive statistics (Table 1) stratified by CCHS cycle (2011 vs. 2014) with proper survey weighting applied.

## Data Sources

### Primary
- `data-private/derived/cchs-2-tables/cchs_analytical.parquet` — Analysis-ready person-level CCHS data with survey weights and outcome variables
- `data-private/derived/cchs-2-tables/sample_flow.parquet` — Sample flow documentation (optional reference)

### Supporting
- `data-private/raw/2026-02-19/stats_instructions_v3.md` — Statistical analysis requirements
- `data-public/metadata/CACHE-manifest.md` — Variable definitions and data dictionary
- `analysis/data-primer-1/data-primer-1.html` — Comprehensive data documentation
- `ai/project/glossary.md` — Domain terminology

## Research Questions
1. What is the pattern of missingness across predictor variables, and does the data satisfy the Missing Completely At Random (MCAR) assumption?
2. What are the proportions of missing values per variable, and should they be imputed or handled as a separate category?
3. What are the unweighted and weighted descriptive statistics for all key variables, stratified by CCHS cycle?
4. How do outcome variables (days absent) differ across cycles and demographic strata when accounting for survey design?

## Target Graph Families
- g1: Missing data pattern visualization — heatmap, upset plot, and missing indicator var distributions
- g2: Missing data by variable — bar chart and density comparisons
- t1: Descriptive Statistics (Table 1) — categorical variables (unweighted and weighted) stratified by CCHS cycle
- t2: Outcome descriptive statistics — weighted means, SDs, and distributions by cycle
- t3: Results of Little's MCAR test and missing data summary

## Output Format
HTML (interactive, code-fold)

## Scope Boundaries

### Included
- Little's MCAR test using `naniar` package
- Missingness visualization: heatmap, upset plot, and distribution comparisons
- Comprehensive descriptive statistics (Table 1) for all categorical predictors
- Weighted and unweighted statistics
- Stratification by CCHS cycle (2011 vs. 2014)
- Proper survey design handling using `survey` package
- Outcome variable descriptive statistics

### Excluded
- Multiple imputation (flagged for potential future analysis)
- Predictive modeling or inferential tests
- Sensitivity analyses beyond MCAR assessment

## Notes
Initial scaffold. Analysis chunks are stubs to be completed during Phase 2 development. Focus on data structure validation first, then progressively implement missing data diagnostics and descriptive table generation.
