# Human Memory

Human decisions and reasoning.

---

# 2026-02-19

Let's create 1-ferry.R and 2-ellis.R following the example in ./manipulation of caseload-forecast-demo (its ferry and ellis and related files). Convert file to SQLite after ferry and  create parquet file with formatted factors after ellis. We loading all supporting docs in a NotebookLM as requested to extract componets from data dictionaries relevant to the research project ( as described in `data-private\raw\2026-02-19\stats_instructions_v3.md`), the product was stored in (`data-public\derived\required-variables-and-sample.md`)

# 2025-11-11

Removed ai_memory_check() function - unnecessary wrapper that just called memory_status(), quick_intent_scan(), and show_memory_help() in sequence. Users should call these directly. Renamed wrapper script from run-ai-memory-check.R to show-memory-status.R for clarity. Result: 312 lines reduced to 293 lines (6% further reduction). Total cleanup: 377 -> 293 lines (22% reduction overall). 
