---
description: >
  Phase 2 of the Pipeline Orchestra. Guides iterative development of the Ellis transformation
  script from ferry staging output. Covers white-listing, factor recoding, outcome construction,
  sample exclusions, and survey weight handling.
agent: Pipeline Engineer
---

# Pipeline Ellis — Transformation Development

Develop or refine the Ellis transformation script. This is Phase 2 of the Pipeline Orchestra.

## When to Use

- Ferry output exists and you are ready to build transformation logic
- Research requirements have changed and Ellis needs updating
- New variables need to be added to the white-list
- Factor recoding or exclusion criteria need adjustment

## Prerequisites

- `manipulation/1-ferry.R` has been run successfully
- Staging database exists (e.g., `cchs-1.sqlite`)
- Codebook CSVs are available from `0-extract-metadata.R`

## Process

### Step 1: Read Context

1. Read `.github/pipeline-orchestra-1.md` for system architecture
2. Read `config.yml` for database paths
3. Read existing `manipulation/2-ellis.R` if it exists
4. Read `data-public/metadata/INPUT-manifest.md` for variable inventory
5. Read codebook CSVs in `data-public/derived/` for value label mappings
6. Read `scripts/templates/ellis-lane.R` and `scripts/templates/ellis.R` for templates

### Step 2: Interview

Ask adaptive questions based on what already exists:

**If starting from scratch**:

1. "What variables does the research require?" — Point to requirements document. Classify
   into CONFIRMED (essential, hard error if missing) and INFERRED (expected, graceful drop).
2. "What outcome variable(s) need construction?" — Row-wise sums, composites, range caps,
   NA handling strategy.
3. "What exclusion criteria define the analytical sample?" — Age range, employment status,
   proxy respondent filters, completeness requirements.
4. "What factor recoding is needed?" — Map numeric CCHS codes to meaningful factor levels.
   Reference codebook CSVs and PUMF documentation.
5. "Are survey weights involved?" — Pooling adjustment, bootstrap weights, strata identifiers.

**If refining existing Ellis**:

1. "What needs to change?" — New variables, different exclusion criteria, corrected recoding.
2. Read the existing script to understand current state.
3. Propose specific modifications with rationale.

### Step 3: Scaffold or Refine Ellis Script

Create or update `manipulation/2-ellis.R` with these required sections:

```text
# ---- setup -------------------------------------------------------------------
# ---- declare-globals ---------------------------------------------------------
#   - Pipeline flags (configurable behavior switches)
#   - White-list: CONFIRMED variables (hard error if missing)
#   - White-list: INFERRED variables (warning if missing)
#   - Cross-cycle alias resolution
# ---- load-data ---------------------------------------------------------------
#   - Connect to ferry staging database
#   - Load and pool cycles
#   - Apply white-list column selection
# ---- tweak-data --------------------------------------------------------------
#   - Outcome construction (row-wise operations, range validation)
#   - Sample exclusion pipeline (tracked in sample_flow table)
#   - Factor recoding (all variables, explicit level definitions)
#   - Survey weight adjustment
# ---- validate ----------------------------------------------------------------
#   - Assertions on output structure, ranges, factor levels
#   - Diagnostic summaries (weighted means, zero proportions, dispersion)
# ---- save-to-disk ------------------------------------------------------------
#   - Parquet (primary — preserves R factors)
#   - SQLite (secondary — factors stored as character)
#   - sample_flow table (exclusion audit trail)
```

### Step 4: Document Inline

Every transformation decision must be documented in comments:

- Why a specific recode mapping was chosen
- Source CCHS variable codes and their meanings
- Cross-cycle label discrepancies and resolution
- Range validation boundaries and what happens to out-of-range values

### Step 5: Instruct Human

Tell the human to:

1. Run `Rscript manipulation/2-ellis.R`
2. Inspect output: row counts, column names, factor levels, outcome distribution
3. Report issues (unexpected NAs, wrong factor levels, missing variables)
4. Iterate until output is satisfactory
5. Proceed to Phase 3 (Validation) when Ellis output is stable
