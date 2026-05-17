---
description: >
  Phase 4 of the Pipeline Orchestra. Cross-checks all seven pipeline artifacts for consistency
  and drift. Reports discrepancies without modifying files unless instructed.
agent: Pipeline Engineer
---

# Pipeline Audit — Quality Assurance

Audit the pipeline for consistency across all artifacts. This is Phase 4 of the Pipeline Orchestra.

## When to Use

- Periodic quality check (recommended after any Ellis modification)
- Before publishing or sharing analysis results
- When you suspect documentation is out of date
- After pulling changes from collaborators

## Process

### Step 1: Read All Seven Artifacts

Read each artifact completely:

1. `manipulation/0-extract-metadata.R` — metadata extraction script
2. `manipulation/1-ferry.R` — ferry transport script
3. `manipulation/2-ellis.R` — Ellis transformation script
4. `manipulation/3-test-ellis-cache.R` — validation test script
5. `data-public/metadata/INPUT-manifest.md` — raw input documentation
6. `data-public/metadata/CACHE-manifest.md` — Ellis output documentation
7. `manipulation/pipeline.md` — pipeline execution guide

Also read:

- `config.yml` — file path configuration
- `flow.R` — `ds_rail` registration (verify script paths match)

### Step 2: Cross-Check Consistency

Verify alignment across all artifact pairs:

**Ellis ↔ CACHE-manifest**:

- Every output variable in Ellis code appears in the manifest variable inventory
- Factor levels in Ellis recode blocks match levels listed in the manifest
- Diagnostic values in the manifest (row counts, weighted means) match actual output
- Sample exclusion steps match between code and manifest

**Ellis ↔ Test script**:

- Every assertion in the test script corresponds to a documented property
- Row count assertions match the manifest's stated sample size
- Factor level checks cover all variables listed in the manifest
- No assertions reference variables or tables that Ellis no longer produces

**Ferry ↔ INPUT-manifest**:

- File paths in the ferry script match those documented in INPUT-manifest
- Variable tiers (CONFIRMED/INFERRED) in INPUT-manifest align with Ellis white-list
- Row/column counts match between manifest claims and actual staging database

**Scripts ↔ pipeline.md**:

- Script paths in `pipeline.md` match actual files on disk
- Execution instructions are current (no references to renamed or deleted scripts)
- Diagnostic checkpoint values match the latest run

**Scripts ↔ flow.R**:

- All pipeline scripts are registered in `ds_rail` (active or commented)
- Script paths in `ds_rail` match actual file names (especially after renames)

**Scripts ↔ config.yml**:

- File paths used by scripts match `config.yml` settings
- No hardcoded paths that should come from config

### Step 3: Report Findings

Present findings as a structured audit report:

```text
## Pipeline Audit Report — {date}

### Passed Checks
- [list of consistent items]

### Discrepancies Found
1. **{artifact pair}**: {description of mismatch}
   - File: {path}, Line: {number}
   - Expected: {what should be there}
   - Found: {what is actually there}
   - Suggested fix: {specific recommendation}

### Recommendations
- {prioritized list of actions}
```

### Step 4: Fix Only When Asked

Do NOT modify any files during an audit unless the human explicitly requests fixes.
Present the report and wait for instructions.
