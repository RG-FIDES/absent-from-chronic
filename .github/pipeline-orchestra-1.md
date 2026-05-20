# Pipeline Orchestra — Design Document v1

> **Status**: v1 — Initial design
> **Created**: 2026-05-16
> **Scope**: Single-agent system for developing, validating, and maintaining data pipeline
> scripts and companion documentation in `manipulation/` and `data-public/metadata/`

---

## Overview

The **Pipeline Orchestra** is a single-agent system that guides researchers through the
complete lifecycle of data pipeline development — from raw file discovery through validated,
documented, analysis-ready output. It fills the automation gap between raw data arrival and
the point where the Composing Orchestra can begin analytical work.

### Problem Statement

Seven tightly coupled artifacts (4 scripts + 3 documents) must stay in sync throughout the
pipeline lifecycle. Prior to this system, all seven were hand-crafted and manually maintained
with no guided process, no consistency checking, and no co-evolution mechanism when one
artifact changed.

### Relationship to Other Orchestras

| Concern | Pipeline Orchestra | Composing Orchestra | Publishing Orchestra |
|---------|--------------------|---------------------|----------------------|
| **Creates** | Pipeline scripts + manifests in `manipulation/` | Analytical reports in `analysis/` | Curated website in `_frontend-N/` |
| **Agent count** | 1 (`@pipeline-engineer`) | 1 (`@report-composer`) | 2 (Interviewer + Writer) |
| **Contract** | Phased prompts (4 entry points) | `report-contract.prompt.md` | `publishing-contract.prompt.md` |
| **Trigger** | Raw data arrives or Ellis changes | Human requests EDA/Report | Human requests website |
| **Output** | `.R` scripts + `.md` manifests | `.R` + `.qmd` pair + rendered HTML/PDF | `edited_content/` + `_site/` |

The three systems are **complementary and sequential**: Pipeline creates data → Composing
analyses data → Publishing curates for the web.

---

## Core Concepts

### Seven Pipeline Artifacts

| # | Artifact | Pattern | Role |
|---|----------|---------|------|
| 0 | `0-extract-metadata.R` | Discovery | Harvest SPSS variable/value labels into codebook CSVs |
| 1 | `1-ferry.R` | Ferry | Transport raw data to SQLite staging with zero transformation |
| 2 | `2-ellis.R` | Ellis | White-list, recode, validate; produce analysis-ready output |
| 3 | `3-test-ellis-cache.R` | Validation | Three-way alignment test (code ↔ disk ↔ manifest) |
| — | `INPUT-manifest.md` | Documentation | Describes raw inputs before any transformation |
| — | `CACHE-manifest.md` | Documentation | Describes Ellis output (variable inventory, diagnostics) |
| — | `pipeline.md` | Documentation | Execution guide, architecture diagram, troubleshooting |

### Two-Tier White-List Design

Ellis uses a two-tier variable selection system:

- **CONFIRMED** (Tier 1): Variables essential to the research. Missing = hard error, pipeline stops.
- **INFERRED** (Tier 2): Variables expected but not critical. Missing = warning, graceful drop.

This design allows the pipeline to run even when some expected variables are absent (common
with PUMF confidentiality suppression) while still failing loudly on essential variables.

### Single-Agent Design

Unlike the Publishing Orchestra (which separates planning from execution), the Pipeline
Orchestra uses **one agent** for all phases. This is deliberate:

- Pipeline development is **iterative** — the researcher and agent refine together over
  multiple run-inspect-adjust cycles
- Each phase builds on context from previous phases
- The same agent that understands the raw data also designs the transformation logic
- Phased prompts provide **entry points** for jumping into any phase independently

---

## Workflow

### Phase 0: Setup (Human, Manual)

Before invoking the agent:

1. Place raw data files in `data-private/raw/{date}/`
2. Update `config.yml` with file paths under `raw_data`
3. Ensure research requirements document exists (referenced by the agent during interview)
4. Activate the Data Engineer persona (VS Code task)

### Phase 1: Discovery + Ferry

**Entry point**: `@pipeline-engineer` or `.github/prompts/pipeline-bootstrap.prompt.md`

**Agent interview** (3–5 adaptive questions):

1. What raw files? (paths, formats, received dates)
2. Research question or requirements document?
3. Multiple sources to pool? Cross-cycle harmonization needed?
4. Known variable naming issues across sources?

**Agent actions**:

1. Read existing templates (`scripts/templates/ferry-to-cache.R`) and any existing scripts
2. Scaffold `0-extract-metadata.R` — metadata extraction from raw files
3. Scaffold `1-ferry.R` — zero-transformation import into staging SQLite
4. Draft `INPUT-manifest.md` — raw source documentation

**Human actions**:

1. Run `0-extract-metadata.R` → inspect codebook CSVs in `data-private/derived/`
2. Run `1-ferry.R` → inspect staging database
3. Report any issues back to agent

**Ferry Pattern constraints**:

- Allowed: `haven::read_sav()`, `haven::zap_labels()`, `janitor::clean_names()`
- Forbidden: Variable selection, recoding, filtering, derived variables

### Phase 2: Ellis Development

**Entry point**: `@pipeline-engineer` or `.github/prompts/pipeline-ellis.prompt.md`

**Agent interview**:

1. What variables does the research require? (point to requirements doc)
2. What outcome variable(s) need construction? (sums, composites, caps)
3. What exclusion criteria define the analytical sample?
4. What factor recoding is needed? (reference codebook metadata from Phase 1)
5. **Codebook verification**: For every variable used in a filter, comparison operator, or
   recode, open the codebook CSV (`data-private/derived/codebook-value-labels.csv`) and
   record the exact code→label mapping before writing any `case_when` or `filter` logic.

**Agent actions**:

1. Read ferry output schema and codebook CSVs
2. **Codebook audit pass**: For each variable in the white-lists, extract its code→label
   table from the codebook CSV. Flag two categories of risk before writing any recode:
   - **Code-range overlap**: Variables whose valid code range overlaps with standard CCHS
     special codes (6, 7, 8, 9, 96–99). For example, `DHHGAGE` uses codes 1–16 where
     6=30–34 yrs, 7=35–39 yrs, 8=40–44 yrs, 9=45–49 yrs are *valid* age groups, not
     missing-data flags. These variables must never be included in bulk `dplyr::across()`
     NA-recoding; they require individual handling.
   - **Category codes masquerading as quantities**: Variables where the numeric code
     represents a labelled category (e.g., `DHHGAGE` codes 1–16 = age *groups*, `FVCGTOT`
     codes 1–3 = frequency *tiers*, `INCGHH` codes 1–5 = income *brackets*). Range
     filters (`filter(var >= X)`) must use **code values**, not natural unit values.
     Comparing `dhhgage >= 15` (intending "age ≥ 15 years") is incorrect when the
     minimum valid code is 1; the correct filter is `dhhgage >= 2` (code 2 = 15–17 yrs).
3. Scaffold `2-ellis.R` with all required sections:
   - Two-tier white-list (CONFIRMED + INFERRED)
   - Cross-cycle variable harmonization (alias resolution)
   - Factor recode blocks with explicit level definitions
   - Outcome construction (row-wise operations, range validation)
   - Sample exclusion pipeline with `sample_flow` audit table
   - Survey weight adjustment (if pooling multiple cycles)
   - Data validation assertions
4. Human runs Ellis, inspects output, reports issues
5. Agent refines → human re-runs → iterate until stable

**Ellis Pattern requirements**:

- Every variable recoded with explicit factor levels verified against the codebook CSV
- CCHS special codes (6, 7, 8, 9, 96–99) mapped to NA — but **only for variables whose
  valid code range does not overlap these values** (see codebook audit pass above)
- Range filters (`filter(var >= X)`) must use **code values**, not natural/unit values;
  confirm against codebook before writing any comparison operator
- Bulk `dplyr::across()` NA recoding over multiple variables: verify that no variable in
  the list has valid data at standard special-code positions; exclude any such variable
  and handle it individually
- All transformation decisions documented inline
- `sample_flow` table tracks exclusion at each step

### Phase 3: Validation + Documentation

**Entry point**: `@pipeline-engineer` or `.github/prompts/pipeline-validate.prompt.md`

**Agent actions**:

1. Read actual Ellis output artifacts (Parquet schema, SQLite tables, row/column counts)
2. Generate `CACHE-manifest.md` from output reality — organized by analytical category:
   - Outcome variables
   - Chronic condition variables (binary factors)
   - Demographic/predisposing factors
   - Health-system/facilitating factors
   - Health status/needs factors
   - Survey design variables
   - Sample construction variables
3. Scaffold `3-test-ellis-cache.R` with assertions:
   - Artifact existence (SQLite, Parquet files present)
   - SQLite ↔ Parquet parity (row/column counts match)
   - Data quality checks (outcome range, factor validity, weight adjustment)
   - Sample flow structure (monotonic exclusion counts)
4. Run test script, report results
5. Update `pipeline.md` with current diagnostic checkpoints

**Key principle**: CACHE-manifest is generated from **actual output**, not from code inspection.
This prevents code-reality drift.

### Phase 4: Quality Audit

**Entry point**: `@pipeline-engineer` or `.github/prompts/pipeline-audit.prompt.md`

**Agent actions**:

1. Read all 7 artifacts without modification
2. Cross-check consistency:
   - Variables in Ellis code ↔ variables in CACHE-manifest
   - Assertions in test script ↔ claims in CACHE-manifest
   - Script paths in `pipeline.md` ↔ actual files on disk
   - File paths in `INPUT-manifest.md` ↔ `config.yml`
3. Check for drift indicators:
   - File modification timestamps
   - Row/column count mismatches
   - Missing or extra variables
4. Report findings with specific file locations and line numbers
5. Do NOT modify files unless explicitly instructed

---

## File Inventory

### Framework Files (in `.github/`)

| File | Purpose |
|------|---------|
| `pipeline-orchestra-1.md` | This design document |
| `agents/pipeline-engineer.agent.md` | Agent definition |
| `instructions/pipeline-scripts.instructions.md` | Conventions for `manipulation/**` |
| `prompts/pipeline-bootstrap.prompt.md` | Phase 1 entry point |
| `prompts/pipeline-ellis.prompt.md` | Phase 2 entry point |
| `prompts/pipeline-validate.prompt.md` | Phase 3 entry point |
| `prompts/pipeline-audit.prompt.md` | Phase 4 entry point |

### Pipeline Artifacts (in `manipulation/` and `data-public/metadata/`)

| File | Purpose |
|------|---------|
| `0-extract-metadata.R` | SPSS metadata extraction |
| `1-ferry.R` | Raw data transport to staging |
| `2-ellis.R` | Data transformation and validation |
| `3-test-ellis-cache.R` | Three-way alignment test |
| `INPUT-manifest.md` | Raw input documentation |
| `CACHE-manifest.md` | Ellis output documentation |
| `pipeline.md` | Execution guide and architecture |

### Supporting Files

| File | Purpose |
|------|---------|
| `guides/pipeline-process.md` | Human-facing process guide |
| `scripts/templates/ferry-to-cache.R` | Ferry pattern template |
| `scripts/templates/ellis-lane.R` | Ellis pattern skeleton |
| `scripts/templates/ellis.R` | Ellis full example |
| `config.yml` | Project configuration |
| `flow.R` | Pipeline orchestration (`ds_rail`) |

---

## Conventions

### Script Numbering

Scripts are numbered 0–3 for execution order:

- `0-` = Discovery (metadata extraction)
- `1-` = Transport (ferry)
- `2-` = Transformation (ellis)
- `3-` = Validation (test)

### R Script Structure

Pipeline scripts follow the standard from `r-scripts.instructions.md`:

```r
# ---- setup -------------------------------------------------------------------
# ---- declare-globals ---------------------------------------------------------
# ---- load-data ---------------------------------------------------------------
# ---- tweak-data --------------------------------------------------------------
# ---- validate ----------------------------------------------------------------
# ---- save-to-disk ------------------------------------------------------------
```

### Manifest Structure

- `INPUT-manifest.md`: File inventory, variable tiers, known limitations
- `CACHE-manifest.md`: Variable inventory by category, factor levels, diagnostics, notes

### Test Structure

- Section 1: Artifact existence
- Section 2: Cross-format parity (SQLite ↔ Parquet)
- Section 3: Data quality assertions
- Section 4: Sample flow validation

---

## Design Decisions

1. **Single agent, not multiple** — Pipeline development is iterative and benefits from
   conversation continuity across phases.
2. **Phased prompts as entry points** — Allows jumping into any phase without replaying
   earlier phases. Each prompt encodes phase-specific interview questions.
3. **Agent advises + scaffolds, human executes** — Safety principle. The agent never
   auto-runs data scripts that could produce or overwrite pipeline outputs.
4. **CACHE-manifest from output, not code** — Prevents drift between what the code intends
   and what the output actually contains.
5. **Non-blocking test in flow.R** — `3-test-ellis-cache.R` uses `run_r_soft()` so test
   failures log warnings but do not halt the pipeline.
