---
description: >
  Structural and semantic rules for pipeline scripts in the manipulation/ directory.
  Covers Ferry Pattern constraints, Ellis Pattern requirements, test script conventions,
  metadata extraction patterns, and the relationship between scripts and companion documents.
applyTo: "manipulation/**"
---

# Pipeline Script Rules

These rules supplement `r-scripts.instructions.md` with pipeline-specific conventions.

## Script Numbering

Pipeline scripts are numbered 0–3 for execution order:

- `0-extract-metadata.R` — Discovery (metadata harvesting)
- `1-ferry.R` — Transport (zero-transformation import)
- `2-ellis.R` — Transformation (white-list, recode, validate)
- `3-test-ellis-cache.R` — Validation (three-way alignment test)

## Ferry Pattern Constraints

Scripts following the Ferry Pattern (`1-ferry.R`):

- **Allowed**: `haven::read_sav()`, `haven::zap_labels()`, `janitor::clean_names()`,
  `DBI::dbWriteTable()`, `arrow::write_parquet()`
- **Forbidden**: Column selection, variable renaming (beyond `clean_names()`), factor
  recoding, row filtering, derived variables, business logic
- **Configuration**: All file paths sourced from `config.yml`, never hardcoded
- **Validation**: Confirm expected variables are present after import (do not filter them)

## Ellis Pattern Requirements

Scripts following the Ellis Pattern (`2-ellis.R`):

- **White-list tiers**: Two-tier variable selection required
  - CONFIRMED (Tier 1): Missing = `stop()` with informative message
  - INFERRED (Tier 2): Missing = `warning()`, graceful drop
- **Factor recoding**: Every categorical variable must have explicit level definitions.
  Never rely on implicit ordering from the source data.
- **CCHS special codes**: Map 6, 7, 8, 9, 96, 97, 98, 99 to `NA` for all factor variables.
- **Outcome construction**: Document the formula, range validation, and NA handling strategy.
- **Sample exclusion**: Track each exclusion step in a `sample_flow` table with columns:
  `step`, `description`, `n_remaining`, `n_excluded`, `pct_remaining`.
- **Inline documentation**: Every transformation decision must have a comment explaining
  the rationale, referencing PUMF codebook codes where applicable.
- **Cross-cycle harmonization**: Use an alias resolution block when pooling multiple survey
  cycles with different variable names.

## Test Script Conventions

The test script (`3-test-ellis-cache.R`):

- **Four assertion sections**:
  1. Artifact existence (files and directories)
  2. Cross-format parity (SQLite ↔ Parquet row/column counts)
  3. Data quality checks (ranges, factor levels, weights)
  4. Sample flow validation (step count, monotonicity)
- **Non-blocking in flow.R**: Always registered with `run_r_soft()` so failures warn but
  do not halt the pipeline.
- **Standalone executable**: Must also run correctly via `Rscript manipulation/3-test-ellis-cache.R`.

## Metadata Extraction Conventions

The metadata extraction script (`0-extract-metadata.R`):

- Read raw files with labels preserved (`haven::read_sav(path, user_na = TRUE)`)
- Extract both variable labels and value labels
- Write codebook CSVs to `data-public/derived/` (not `data-private/`)
- Compare label sets across sources to detect cross-cycle discrepancies

## Companion Documents

Pipeline scripts have three companion markdown documents that must stay synchronized:

- `data-public/metadata/INPUT-manifest.md` — documents what goes IN to the pipeline
- `data-public/metadata/CACHE-manifest.md` — documents what comes OUT of Ellis
- `manipulation/pipeline.md` — documents HOW to run the pipeline

When modifying any pipeline script, consider whether the companion documents need updating.

## Registration in flow.R

All pipeline scripts must be registered in the `ds_rail` tibble in `flow.R`:

- Phase 0 (metadata): `"run_r"` or `"run_r_soft"`
- Phase 1 (ferry): `"run_r"`
- Phase 2 (ellis): `"run_r"`
- Phase 3 (test): `"run_r_soft"` (non-blocking)
