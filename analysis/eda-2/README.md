# EDA-2

> **Status**: Empty template — ready to populate with analysis.

## Purpose

Replace this section with the research question or analytical goal for EDA-2.

## Files

| File | Role |
|------|------|
| `eda-2.R` | Interactive development script (your analytical laboratory) |
| `eda-2.qmd` | Publication layer — narrative + rendered output |
| `data-local/` | Intermediate files (git-ignored, reproduced by script) |
| `prints/` | High-quality PNG exports via `ggsave()` |
| `figure-png-iso/` | Quarto chunk figure cache |

## Quick Start

1. Open `eda-2.R` and fill in the `load-data` chunk with your data source.
2. Develop graphs interactively in the `g1`, `g2-data-prep`, `g2`, `g21` chunks.
3. Run the `eda-2.qmd` to render the report:

```powershell
quarto render analysis/eda-2/eda-2.qmd
```

Or use the VS Code task **Render EDA-2 Quarto Report** (add it to `.vscode/tasks.json` mirroring the EDA-1 task).

## Conventions

- All graphs saved at **8.5 × 5.5 inches, 300 DPI** via `ggsave()` — optimised for letter-size portrait print.
- Graph naming: `g1`, `g2`, `g2-data-prep` / `g21`, `g22` … (families share a data ancestor).
- See `./analysis/eda-1/eda-style-guide.md` for the full style reference.

## Interactive Plotting (VS Code)

Install `httpgd` for live interactive plots in VS Code:

```powershell
Rscript -e "install.packages('httpgd', repos='https://cran.rstudio.com')"
```

The script auto-starts `httpgd` when it detects an interactive session.
