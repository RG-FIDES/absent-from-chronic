# Frontend 22 — EDA-3 Developer Briefing Site

## Purpose

This website presents the Absent from Chronic project to a developer audience, with emphasis on the newly completed EDA-3 analysis outputs. The site should be informative, engaging, and collaborative, helping developers quickly understand what was produced, how it was produced, and where to go next.

Because the current repository snapshot has mature EDA outputs but no rendered non-exploratory report HTML, the Analysis section is intentionally centered on EDA artifacts and a composed findings brief.

## Navigation

### index (Home Page)
- **Protocol**: Narrative Bridge
- **Intent**: Orient developers to the project and immediately spotlight EDA-3 as the key analytical deliverable.
- **Goal**: Home page for first-time visitors.
- **Spirit**: Informative, engaging, collaborative.
- **Inputs**:
  - `./analysis/frontend-22/initial.prompt.md`
  - `./README.md`
  - `./ai/project/mission.md`
  - `./analysis/eda-3/eda-3.qmd`
  - `./analysis/eda-3/figure-png-iso/g1-display-1.png`
  - `./manipulation/pipeline.md`

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

#### Summary
- **Protocol**: Narrative Bridge
- **Intent**: Provide a concise technical summary of project purpose, analytical approach, and what EDA-3 contributes.
- **Goal**: Fast project orientation for developers.
- **Spirit**: Clear and factual.
- **Inputs**:
  - `./ai/project/mission.md`
  - `./ai/project/method.md`
  - `./README.md`
  - `./analysis/eda-3/report-contract.prompt.md`

### Pipeline

#### Pipeline Guide
- **Protocol**: Technical Bridge
- **Source**: `./manipulation/pipeline.md`
- **Transforms**: Mermaid shortcode injection, sanitize developer-noise where redundant, preserve core pipeline explanation and architecture.

#### Cache Manifest
- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./data-public/metadata/CACHE-manifest.md`

### Analysis

#### EDA
- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/eda-3/eda-3.html`

#### Report
- **Protocol**: Narrative Bridge
- **Intent**: Compose a concise developer-facing findings brief from EDA-3 outputs in lieu of a rendered report HTML artifact.
- **Goal**: Analysis summary page for implementation and follow-up decisions.
- **Spirit**: Evidence-led and practical.
- **Inputs**:
  - `./analysis/eda-3/eda-3.qmd`
  - `./analysis/eda-3/report-contract.prompt.md`
  - `./analysis/eda-3/figure-png-iso/g2-display-1.png`
  - `./analysis/eda-3/figure-png-iso/g21-display-1.png`
  - `./analysis/eda-3/figure-png-iso/g22-display-1.png`
  - `./analysis/eda-3/figure-png-iso/g23-display-1.png`

### Docs

#### README
- **Protocol**: Technical Bridge
- **Source**: `./README.md`
- **Transforms**: Rewrite internal links for site context, remove setup-only/developer-ops noise not relevant to frontend audience, preserve project overview sections.

#### Site Map
- **Protocol**: Narrative Bridge
- **Intent**: Provide complete navigation and provenance map for the generated website.
- **Goal**: Orientation and traceability page.
- **Spirit**: Concise and functional.
- **Inputs**:
  - This contract file (`./_frontend-22/publishing-contract.prompt.md`)

#### Publisher Notes
- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./.github/publishing-orchestra-3.md`

## Exclusions

- `analysis/eda-1/`
- `*.R`
- `*_cache/`
- `data-private/`
- `analysis/*/data-local/`
- `analysis/*/prompts/`
- `analysis/*/README.md`
- `manipulation/example/`

## Theme

yeti

## Footer

Absent from Chronic — Frontend 22

## Repo URL

https://github.com/RG-FIDES/absent-from-chronic
