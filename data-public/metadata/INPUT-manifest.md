# INPUT Manifest

Describes the raw input datasets consumed by the data pipeline **before** Ferry/Ellis processing.  
Updated: 2026-02-19

---

## Summary

| File | Cycle | Rows (approx.) | Columns (approx.) | Received |
|------|-------|---------------:|------------------:|----------|
| `CCHS2010_LOP.sav` | 2010–2011 | 62,909 | 1,500+ | 2026-02-19 |
| `CCHS_2014_EN_PUMF.sav` | 2013–2014 | 63,522 | 1,500+ | 2026-02-19 |

---

## Source File Details

### File 1 — CCHS 2010–2011

| Attribute | Value |
|-----------|-------|
| **Filename** | `CCHS2010_LOP.sav` |
| **Survey cycle** | 2010–2011 Combined |
| **Survey name** | Canadian Community Health Survey (CCHS) |
| **Administrator** | Statistics Canada |
| **Data type** | SPSS system file (.sav) with value/variable labels |
| **Location** | `./data-private/raw/2026-02-19/CCHS2010_LOP.sav` |
| **Approximate rows** | 62,909 |
| **Approximate columns** | 1,500+ |
| **Received date** | 2026-02-19 |
| **Access type** | PUMF (Public Use Microdata File) |
| **LOP module** | Yes — includes "Length of Physical Disability" (LOP) variables (`LOPG*`) |

### File 2 — CCHS 2013–2014

| Attribute | Value |
|-----------|-------|
| **Filename** | `CCHS_2014_EN_PUMF.sav` |
| **Survey cycle** | 2013–2014 Combined |
| **Survey name** | Canadian Community Health Survey (CCHS) |
| **Administrator** | Statistics Canada |
| **Data type** | SPSS system file (.sav) with value/variable labels |
| **Location** | `./data-private/raw/2026-02-19/CCHS_2014_EN_PUMF.sav` |
| **Approximate rows** | 63,522 |
| **Approximate columns** | 1,500+ |
| **Received date** | 2026-02-19 |
| **Access type** | PUMF (Public Use Microdata File) |
| **LOP module** | Yes — includes `LOPG*` absenteeism variables |

---

## Variable Coverage

The Ferry lane (`1-ferry.R`) imports **all columns** from both files with zero semantic transformation.

The Ellis lane (`2-ellis.R`) applies a **white-list** selecting only variables relevant to the
work-absenteeism analysis. White-listed variables fall into two tiers:

### Tier 1: CONFIRMED (error if missing)
Variables verified against the PDF data dictionaries and the study's
`required-variables-and-sample.md` specification.

| CCHS Variable | Description | Source Module |
|---------------|-------------|---------------|
| `LOPG010` | Days absent — personal illness/injury | LOP |
| `LOPG020` | Days absent — family responsibilities | LOP |
| `LOPG025` | Days absent — own maternity/parental leave | LOP |
| `LOPG027` | Days absent — medical/dental appointments | LOP |
| `LOPG030` | Days absent — personal needs | LOP |
| `LOPG035` | Days absent — other reasons | LOP |
| `LOPG040` | Days absent — own chronic condition (primary outcome) | LOP |
| `LOPG045` | Days absent — long-term disability | LOP |
| `LOP_015`  | Currently employed (1=Yes) | LOP |
| `DHHGAGE`  | Age group (coded 1–16) | DHH |
| `ADM_PRX`  | Proxy respondent flag (1=proxy) | ADM |
| `GEODPMF`  | Province of residence | GEO |
| `WTS_M`    | Survey weight (master weight) | WTS |

### Tier 2: INFERRED (warning if missing — graceful drop)
Variables inferred from standard CCHS PUMF naming conventions.  
**Verify exact names against the data dictionary PDFs** if any are missing after running `2-ellis.R`.

- **CCC module (19 vars):** `CCC_015`, `CCC_020`, `CCC_025`, `CCC_030`, `CCC_035`, `CCC_040`,
  `CCC_060`, `CCC_095`, `CCC_100`, `CCC_110`, `CCC_115`, `CCC_120`, `CCC_125`, `CCC_130`,
  `CCC_135`, `CCC_140`, `CCC_145`, `CCC_150`, `CCC_185`
- **Predisposing (7 vars):** `DHH_SEX`, `DHHGMS`, `DHHDGHSZ`, `EDUDH04`, `SDCFIMM`,
  `SDCDGCB`, `DHHDGLVG`
- **Facilitating (11 vars):** `INCDGHH`, `HCU_1AA`, `LBFDGHP`, `LBFDGFT`, `FVCDGTOT`,
  `ALCDGTYP`, `SMKDSTY`, `HWTDGBMI`, `PACDPAI`, `GEN_07`
- **Needs (5 vars):** `GEN_01`, `GEN_02A`, `GEN_09`, `RAC_1`, `INJ_01`
- **ID (1 var):** `ADM_RNO`
- **Bootstrap weights (500 vars):** `BSW001`–`BSW500` (pattern `^BSW`)

---

## Known Limitations

- **Variable name differences between cycles**: Some CCHS variables change names slightly
  between cycles. The Ellis lane includes a harmonization step; any harmonization decisions
  are documented in `manipulation/2-ellis.R` under `# ---- SECTION 1 / harmonize`.
- **DHHGAGE coding**: Age codes 1–16+ vary by cycle. The Ellis exclusion filter uses
  `dhhgage %in% 2:15` (approximately age 15–75). Verify these codes against the PDF
  data dictionaries for each cycle.
- **Missing value codes**: Special NA codes (6, 7, 8, 9, 96, 97, 98, 99) are recoded to `NA`
  throughout by the Ellis lane. Original SPSS codes are stripped during Ferry import.
- **LOP module availability**: Not all provinces include the LOP module in both cycles.
  Check `GEODPMF` × `cycle` cross-tabulation for potential geographic exclusions.

---

## Pipeline Traceability

```
CCHS2010_LOP.sav          ──┐
                             ├──► 1-ferry.R ──► cchs-1.sqlite (cchs_2010_raw, cchs_2014_raw)
CCHS_2014_EN_PUMF.sav     ──┘              └──► cchs-1-raw/*.parquet (backup)
                                                      │
                                                      ▼
                                             2-ellis.R (white-list + recode)
                                                      │
                                            ┌─────────┴────────────┐
                                            ▼                       ▼
                                   cchs-2.sqlite             cchs-2-tables/
                                  (cchs_analytical,          cchs_analytical.parquet
                                   sample_flow)              sample_flow.parquet
```

---

*This manifest is updated manually when new raw data files are received.*


