---
description: >
  Phase 3 of the Pipeline Orchestra. Generates CACHE-manifest from actual Ellis output,
  scaffolds the test script, and updates pipeline.md. Ensures three-way alignment between
  code, disk artifacts, and documentation.
agent: Pipeline Engineer
---

# Pipeline Validate — Documentation + Testing

Generate validation tests and documentation from stable Ellis output. This is Phase 3 of the
Pipeline Orchestra.

## When to Use

- Ellis produces stable output and needs documentation
- CACHE-manifest needs to be created or regenerated after Ellis changes
- Test script needs to be created or updated
- `pipeline.md` needs updating with current diagnostic checkpoints

## Prerequisites

- `manipulation/2-ellis.R` has been run successfully and output is stable
- Output artifacts exist on disk (Parquet files, SQLite database)

## Process

### Step 1: Read Context

1. Read `.github/pipeline-orchestra-1.md` for system architecture
2. Read `manipulation/2-ellis.R` to understand transformation logic
3. Read existing `data-public/metadata/CACHE-manifest.md` if it exists
4. Read existing `manipulation/3-test-ellis-cache.R` if it exists
5. Read `manipulation/pipeline.md` if it exists

### Step 2: Inspect Ellis Output

Read the actual output artifacts — do NOT rely solely on code inspection:

1. **Parquet files**: Use `arrow::read_parquet()` to get schema, row counts, column names,
   factor levels
2. **SQLite tables**: Use `DBI::dbListTables()`, `DBI::dbGetQuery()` for row counts and
   column types
3. **Sample flow table**: Read the exclusion audit trail
4. **Cross-format parity**: Verify Parquet and SQLite contain the same data

### Step 3: Generate CACHE-Manifest

Create or update `data-public/metadata/CACHE-manifest.md` with content organized by:

1. **Overview**: Dataset names, paths, formats, row/column counts, run mode
2. **Reference diagnostics**: Sample size, weighted means, dispersion, zero proportion
3. **Variable inventory** (by analytical category):
   - Outcome variables
   - Chronic condition variables (binary factors)
   - Demographic/predisposing factors
   - Health-system/facilitating factors
   - Health status/needs factors
   - Survey design variables
   - Sample construction variables
4. **Sample flow table**: Step-by-step exclusion audit
5. **Missing value handling**: Special code mappings
6. **Variable harmonization**: Cross-cycle alias table
7. **Notes and limitations**: Absent variables, known issues

### Step 4: Scaffold Test Script

Create or update `manipulation/3-test-ellis-cache.R` with four assertion sections:

1. **Artifact existence**: SQLite file, Parquet directory, individual Parquet files
2. **Cross-format parity**: Row counts and column counts match between SQLite and Parquet
3. **Data quality — analytical table**: Sample size, outcome range, factor level validity,
   weight adjustment verification, no duplicate rows
4. **Data quality — sample flow**: Correct number of steps, monotonic exclusion counts,
   percentages sum correctly

Use `stopifnot()` or `checkmate` assertions. The test script should be runnable standalone
and also via `run_r_soft()` in `flow.R` (non-blocking).

### Step 5: Update Pipeline Documentation

Update `manipulation/pipeline.md` with:

- Current script inventory (paths, purposes)
- Diagnostic checkpoint values from the actual run
- Any changes to the pipeline architecture diagram

### Step 6: Run Validation

Tell the human to run `Rscript manipulation/3-test-ellis-cache.R` and report results.
All assertions should pass. If any fail, diagnose the cause and recommend fixes.
