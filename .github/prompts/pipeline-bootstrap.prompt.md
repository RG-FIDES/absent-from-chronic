---
description: >
  Phase 1 of the Pipeline Orchestra. Guides discovery of raw data sources and scaffolding
  of extract-metadata and ferry scripts. Produces initial INPUT-manifest.
agent: Pipeline Engineer
---

# Pipeline Bootstrap — Discovery + Ferry

Bootstrap a new data pipeline from raw source files. This is Phase 1 of the Pipeline Orchestra.

## When to Use

- Raw data files have just arrived and no pipeline scripts exist yet
- A new data source is being added to an existing pipeline
- The ferry script needs to be rebuilt for changed source files

## Process

### Step 1: Read Context

1. Read `.github/pipeline-orchestra-1.md` for system architecture
2. Read `config.yml` for current file path configuration
3. Read `scripts/templates/ferry-to-cache.R` for the ferry template
4. Check if `manipulation/0-extract-metadata.R` and `manipulation/1-ferry.R` already exist
5. If they exist, read them and ask: "These scripts already exist. Should I update them or
   start fresh?"

### Step 2: Interview

Ask 3–5 adaptive questions (each answer shapes the next):

1. "What raw data files do you have?" — Establish paths, formats (`.sav`, `.csv`, etc.),
   received dates. Check if `config.yml` already has paths configured.
2. "What is the research question or requirements document?" — Locate the document that
   specifies which variables are needed (e.g., `stats_instructions_v3.md`).
3. "Are there multiple data sources to pool?" — Determine if cross-source harmonization is
   needed (variable name differences, overlapping time periods).
4. "Any known data quality issues?" — Encoding problems, missing files, confidentiality
   suppressions.

### Step 3: Scaffold Extract-Metadata Script

Create or update `manipulation/0-extract-metadata.R`:

- Read raw files with labels preserved (e.g., `haven::read_sav(path, user_na = TRUE)`)
- Extract variable labels (`attr(col, "label")`) and value labels (`attr(col, "labels")`)
- Write codebook CSVs to `data-private/derived/` (variable labels, value labels, cross-source diffs)
- Follow `r-scripts.instructions.md` conventions (preamble, chunk markers)

### Step 4: Scaffold Ferry Script

Create or update `manipulation/1-ferry.R`:

- **Ferry Pattern only**: `haven::read_sav()` → `haven::zap_labels()` → `janitor::clean_names()`
  → `DBI::dbWriteTable()` to SQLite
- Source file paths from `config.yml` — no hardcoded paths
- Parquet backup alongside SQLite
- Validate expected variables are present (from interview and requirements doc)
- No column selection, no recoding, no filtering

### Step 5: Draft INPUT-Manifest

Create or update `data-public/metadata/INPUT-manifest.md`:

- File inventory (paths, formats, row/column counts, received dates)
- Variable tiers (CONFIRMED = essential; INFERRED = expected)
- Known limitations and data quality notes
- Pipeline flow diagram (source → ferry → staging)

### Step 6: Instruct Human

Tell the human to:

1. Run `Rscript manipulation/0-extract-metadata.R` and inspect codebook CSVs
2. Run `Rscript manipulation/1-ferry.R` and inspect the staging SQLite
3. Report any issues (missing variables, encoding problems, unexpected row counts)
4. Proceed to Phase 2 (Ellis) when satisfied with the staging data
