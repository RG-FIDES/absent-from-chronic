# Absent from Chronic — Research Documentation

## Purpose

A research documentation site for the study *"Predictors of Work Absenteeism Associated with
Chronic Conditions Among Canadian Workers"*, built for Marc-Andre Blanchette — the study's lead
research scientist and principal investigator.

The site provides a structured, navigable record of analytical decisions, data pipeline
documentation, variable selection rationale, and preliminary descriptive findings. Its organizing
principle is evidence: every section corresponds to a layer of work that responds to requirements
in `stats_instructions_v3.md`. A visitor should be able to navigate from "what was asked" to "what
was done" without needing access to the repository.

The audience is a single expert reader (the PI) who wants to verify coverage — not a general
public site. Tone is professional and direct. Content is shown essentially as the analyst produced
it.

---

## Navigation

### index (Home Page)

- **Protocol**: Narrative Bridge
- **Intent**: Orient Marc-Andre with a clear statement of what this site contains and where to
  find evidence of each addressed requirement. Establish that the pipeline is built, the data is
  clean, and the study variables are documented and profiled.
- **Goal**: Home page — the first thing a visitor sees.
- **Spirit**: Professional and direct. Lead with the study title and purpose. Three-sentence summary
  of the analytical layers (pipeline → data primer → EDA). No marketing language. End with a brief
  "How to use this site" paragraph pointing to the main sections.
- **Inputs**: `ai/project/mission.md`, `README.md`, `data-public/metadata/CACHE-manifest.md`
  (use the dataset summary: 63,843 rows, 62 columns, two CCHS cycles pooled).

---

### Project

#### Mission

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/mission.md`

#### Method

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/method.md`

#### Glossary

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/glossary.md`

---

### Pipeline

#### Pipeline Guide

- **Protocol**: Technical Bridge
- **Source**: `./manipulation/pipeline.md`
- **Transforms**:
  - Retain the ASCII flow diagram and scripts table as-is.
  - Strip R console code blocks and PowerShell commands (not relevant to PI audience).
  - Remove references to `data-private/` paths.
  - Remove the developer note about the missing `manipulation/3-ellis.R` — replace with a neutral
    statement: *"A third Ellis lane produced additional derived outputs; documentation is in the
    CACHE Manifest."*
  - Rewrite any local file links to plain text (no paths point outside the site).

#### CACHE Manifest

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./data-public/metadata/CACHE-manifest.md`

#### INPUT Manifest

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./data-public/metadata/INPUT-manifest.md`

---

### Data Primer

#### Variable Inclusion

- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/data-primer-1/variable-inclusion.html`

#### Univariate Distributions

- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/data-primer-1/univariate-distributions.html`

---

### Analysis

#### EDA-2

- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/eda-2/eda-2.html`

#### EDA-4

- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/eda-4/eda-4.html`

---

### Docs

#### README

- **Protocol**: Technical Bridge
- **Source**: `./README.md`
- **Transforms**:
  - Strip all R console code blocks and PowerShell instructions.
  - Remove `data-private/` path references.
  - Remove the "Running the data pipeline" and "Running the analysis scripts" sections — these are
    developer-facing; the PI audience does not need them.
  - Retain the "About This Project" section and the data location table (sanitized).
  - Rewrite internal markdown links to match site navigation where applicable; remove any links
    that point to files not included in the site.

#### Site Map

- **Protocol**: Narrative Bridge
- **Intent**: Help Marc-Andre navigate the site and understand what each section contains and how
  it maps to the statistical analysis requirements. Provide a complete inventory of all pages.
- **Goal**: Site map — an oriented index of all pages.
- **Spirit**: Concise and functional. Include a **Content Types** legend table (defining VERBATIM,
  REDIRECTED, TECHNICAL BRIDGE, NARRATIVE BRIDGE) and a **Navigation Structure** list annotating
  every page with its content type and source file. Add a brief "Stats Instructions Coverage" note
  where the mapping from page to requirement is clear (e.g., Data Primer → §2.2 variable
  selection; Univariate Distributions → §3 descriptive statistics).
- **Inputs**: Contract navigation structure (this file).

---

## Exclusions

- `*.R` — source scripts, not publishable
- `*_cache/` — Quarto render cache
- `data-private/` — private data, never publish
- `analysis/eda-1/` — mtcars scaffold, always excluded
- `README.md` inside subfolders (only root README is included)
- `.github/` — internal workflow files
- `ai/memory/`, `ai/scripts/`, `ai/templates/` — internal AI support files
- `renv/`, `scripts/`, `utility/` — developer infrastructure
- `analysis/frontend-1/` — intent folder, not content

---

## Theme

flatly

---

## Footer

*Absent from Chronic* — Statistical Analysis Replication | Marc-Andre Blanchette, Research Scientist

---

## Repo URL

https://github.com/[owner]/absent-from-chronic
