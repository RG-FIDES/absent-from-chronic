rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(forcats)
library(stringr)
library(janitor)
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("arrow")
requireNamespace("config")
requireNamespace("fs")

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")

# ---- declare-globals ---------------------------------------------------------
config <- config::get()

path_ferry  <- config$database$cchs$ferry_sqlite
path_ellis  <- config$database$cchs$ellis_sqlite
parquet_dir <- config$database$cchs$ellis_parquet_dir

prints_folder <- "./manipulation/prints/"
if (!fs::dir_exists(prints_folder)) fs::dir_create(prints_folder, recursive = TRUE)

report_render_start_time <- Sys.time()

# Analytic age bounds — DHHGAGE category codes (codebook: codes 1-16, not year values)
# Code 2 = 15-17 years (first group >= 15), code 15 = 75-79 years (last group <= 79)
DHHGAGE_CODE_MIN <- 2L
DHHGAGE_CODE_MAX <- 15L

# ---- declare-functions -------------------------------------------------------
# Map CCHS "not applicable" / refusal / unknown codes to NA
# CCHS standard special codes: 6, 7, 8, 9, 96, 97, 98, 99
recode_cchs_na <- function(x) {
  dplyr::case_when(
    x %in% c(6, 7, 8, 9, 96, 97, 98, 99) ~ NA_real_,
    TRUE ~ as.double(x)
  )
}

# Append a step to the sample-flow audit table
add_flow_step <- function(flow_tbl, step_num, description, n_remaining) {
  n_prev  <- if (nrow(flow_tbl) == 0) NA_integer_ else dplyr::last(flow_tbl$n_remaining)
  n_excl  <- if (is.na(n_prev)) NA_integer_ else n_prev - n_remaining
  pct_rem <- if (is.na(n_prev)) 100 else round(100 * n_remaining / n_prev, 1)
  dplyr::bind_rows(
    flow_tbl,
    tibble::tibble(
      step         = step_num,
      description  = description,
      n_remaining  = as.integer(n_remaining),
      n_excluded   = as.integer(n_excl),
      pct_remaining = pct_rem
    )
  )
}

cat("\n---- SECTION: Import from Ferry --------------------------------------\n")
# ---- load-data ---------------------------------------------------------------
con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path_ferry)

ds_2010_raw <- DBI::dbReadTable(con, "cchs_2010")
ds_2014_raw <- DBI::dbReadTable(con, "cchs_2014")

DBI::dbDisconnect(con)

cat("  Loaded cchs_2010:", nrow(ds_2010_raw), "rows x", ncol(ds_2010_raw), "cols\n")
cat("  Loaded cchs_2014:", nrow(ds_2014_raw), "rows x", ncol(ds_2014_raw), "cols\n")

# ---- SECTION: Two-Tier White-List --------------------------------------------
# Tier 1 — CONFIRMED: essential to research. Missing = hard error, pipeline stops.
# Tier 2 — INFERRED:  expected but not critical. Missing = warning, graceful drop.
#
# Verify after alias resolution (see next section) — these are post-harmonization names.

vars_confirmed <- c(
  # Outcome: LOP days-absent components (must sum to construct primary outcome)
  "lop_015",    # Employed in past 3 months? (inclusion gate)
  "lopg040",    # Days lost: chronic condition
  "lopg070",    # Days lost: injury
  "lopg082",    # Days lost: cold
  "lopg083",    # Days lost: flu / influenza
  "lopg084",    # Days lost: stomach flu
  "lopg085",    # Days lost: respiratory infection
  "lopg086",    # Days lost: other infectious disease
  "lopg100",    # Days lost: other physical or mental health reason
  # 17 resolvable chronic conditions (binary)
  "ccc_031",   # Asthma
  "ccc_041",   # Fibromyalgia
  "ccc_051",   # Arthritis
  "ccc_061",   # Back problems (excl. fibromyalgia / arthritis)
  "ccc_071",   # High blood pressure / hypertension
  "ccc_081",   # Migraine
  "ccc_091",   # COPD
  "ccc_101",   # Diabetes
  "ccc_121",   # Heart disease (cardiovascular)
  "ccc_131",   # Cancer
  "ccc_141",   # Stomach / intestinal ulcer
  "ccc_151",   # Stroke effects (cardiovascular / stroke)
  "ccc_171",   # Bowel disorder (Crohn's / colitis)
  "ccc_251",   # Chronic fatigue syndrome
  "ccc_261",   # Multiple chemical sensitivities
  "ccc_280",   # Mood disorder
  "ccc_290",   # Anxiety disorder
  # Core demographics
  "dhhgage",   # Age (derived grouped)
  "dhh_sex",   # Sex
  "dhhgms",    # Marital status
  "dhhghsz",   # Household size
  "geogprv",   # Province of residence
  "incghh",    # Total household income (all sources)
  # Survey weight
  "wts_m",
  # Proxy indicator
  "adm_prx"
)

vars_inferred <- c(
  # Additional demographics
  "dhhgle5",   # Children <= 5 in household
  "dhhg611",   # Children 6-11 in household
  "dhhgl12",   # Children < 12 in household
  # Education
  "edudr04",   # Respondent education, 4 levels
  "edudh04",   # Household education, 4 levels
  # Immigration / ethnicity
  "sdcfimm",   # Immigrant flag YES/NO (primary non-immigrant signal)
  "sdcgres",   # Length of time in Canada (recent vs long-term immigrant)
  "sdcgcgt",   # Cultural / racial origin
  # Health behaviours
  "hwtgisw",   # BMI category (international standard, 18+)
  "hwtgbmi",   # BMI (continuous, self-report)
  "alcdttm",   # Alcohol use — type of drinker (12 months)
  "fvcgtot",   # Fruit and vegetable consumption (daily)
  "pacdpai",   # Leisure physical activity index
  # Smoking status (derived)
  "smkgstp",   # Years since stopping smoking completely
  # General / perceived health
  "gen_01",    # Self-perceived general health
  "gen_02",    # Self-perceived health compared to prior year
  "gen_02b",   # Self-perceived mental health
  "gen_09",    # Self-perceived work stress
  # Functional limitations (ADL module)
  "adl_01",    # Needs help: preparing meals
  "adl_02",    # Needs help: appointments / errands
  "adl_03",    # Needs help: housework
  "adl_04",    # Needs help: personal care
  "adl_05",    # Needs help: moving inside house
  "adl_06",    # Needs help: personal finances
  # Employment type
  "lbsdpft",   # Full-time / part-time status (derived)
  # Family doctor / primary care
  "hcu_1aa_h", # Has regular medical doctor (harmonized name — see alias block)
  # Student status
  "sdcg9",     # Full-time or part-time student
  # Injury
  "inj_01"     # Injured in past 12 months
)

cat("\n  White-list summary:\n")
cat("    CONFIRMED vars (Tier 1):", length(vars_confirmed), "\n")
cat("    INFERRED  vars (Tier 2):", length(vars_inferred), "\n")

cat("\n---- SECTION: Cross-Cycle Alias Resolution ---------------------------\n")
# ---- alias-resolution --------------------------------------------------------
# CCHS 2010 and 2014 use different variable names for some constructs.
# This block renames 2010 variables to match 2014 names (or a harmonized name)
# BEFORE the white-list check is applied.
#
# Verified cross-cycle differences:
#   Construct           2010 name   2014 name      Harmonized name
#   Regular family doc  ACC_50A     HCU_1AA        hcu_1aa_h
#   Country of birth    SDCGCBG     SDCGCB13       sdcgcbg_h
#
# All other variables in the white-lists appear under identical names in both cycles.

# Add cycle identifier before renaming
ds_2010_raw$cchs_cycle <- 0L   # 0 = 2010-2011
ds_2014_raw$cchs_cycle <- 1L   # 1 = 2013-2014

# Apply clean_names first so we work in lowercase throughout
ds_2010 <- ds_2010_raw %>% janitor::clean_names()
ds_2014 <- ds_2014_raw %>% janitor::clean_names()

# Rename 2010 variables to harmonized names
ds_2010 <- ds_2010 %>%
  dplyr::rename(
    hcu_1aa_h  = any_of("acc_50a"),    # Has regular family doctor (2010)
    sdcgcbg_h  = any_of("sdcgcbg")     # Country of birth 2010 → harmonized
  )

# Rename 2014 variables to harmonized names
ds_2014 <- ds_2014 %>%
  dplyr::rename(
    hcu_1aa_h  = any_of("hcu_1aa"),    # Has regular medical doctor (2014)
    sdcgcbg_h  = any_of("sdcgcb13")   # Country of birth 2014 → harmonized
  )

cat("  Alias resolution complete.\n")

# ---- SECTION: White-List Enforcement -----------------------------------------

# Enforce Tier 1 (CONFIRMED) — hard stop if any variable is absent from either source
missing_confirmed_2010 <- setdiff(vars_confirmed, names(ds_2010))
missing_confirmed_2014 <- setdiff(vars_confirmed, names(ds_2014))

if (length(missing_confirmed_2010) > 0) {
  stop(
    "CONFIRMED variables missing from cchs_2010:\n",
    paste(" -", missing_confirmed_2010, collapse = "\n")
  )
}
if (length(missing_confirmed_2014) > 0) {
  stop(
    "CONFIRMED variables missing from cchs_2014:\n",
    paste(" -", missing_confirmed_2014, collapse = "\n")
  )
}
cat("  Tier 1 check PASSED — all CONFIRMED variables present in both cycles.\n")

# Enforce Tier 2 (INFERRED) — warn and drop if missing
missing_inferred_2010 <- setdiff(vars_inferred, names(ds_2010))
missing_inferred_2014 <- setdiff(vars_inferred, names(ds_2014))
missing_inferred_any  <- unique(c(missing_inferred_2010, missing_inferred_2014))

if (length(missing_inferred_any) > 0) {
  warning(
    "INFERRED variables not present in at least one cycle (will be dropped gracefully):\n",
    paste(" -", missing_inferred_any, collapse = "\n")
  )
  vars_inferred <- setdiff(vars_inferred, missing_inferred_any)
}
cat("  Tier 2 check: retaining", length(vars_inferred), "INFERRED variables.\n")

# Select white-listed columns (plus cycle flag) from each cycle
all_vars_to_keep <- c(vars_confirmed, vars_inferred, "cchs_cycle")

ds_2010 <- ds_2010 %>% dplyr::select(dplyr::any_of(all_vars_to_keep))
ds_2014 <- ds_2014 %>% dplyr::select(dplyr::any_of(all_vars_to_keep))

cat("\n---- SECTION: Pool Cycles + Weight Adjustment ------------------------\n")
# ---- pool-cycles -------------------------------------------------------------
# Bind rows from both cycles. Column alignment is maintained because both data
# frames are already filtered to the same white-listed variable set.
#
# Survey weight adjustment (Statistics Canada recommendation for pooling two
# CCHS annual cycles): divide each respondent's master weight by the number
# of cycles pooled. With two cycles, divide by 2.
# Source: CCHS User Guide — combining annual cycles.
ds_pooled <- dplyr::bind_rows(ds_2010, ds_2014) %>%
  dplyr::mutate(wts_m_pooled = wts_m / 2)

cat("  Pooled rows:", nrow(ds_pooled),
    "  (2010:", nrow(ds_2010), " + 2014:", nrow(ds_2014), ")\n")

cat("\n---- SECTION: Sample Exclusion Pipeline -----------------------------\n")
# ---- sample-exclusion --------------------------------------------------------
# Track each exclusion step in an audit table.
# Final sample should approximate the n=64,141 reported in the prior analysis.

sample_flow <- tibble::tibble(
  step          = integer(),
  description   = character(),
  n_remaining   = integer(),
  n_excluded    = integer(),
  pct_remaining = numeric()
)

# Step 0: Full pooled sample
sample_flow <- add_flow_step(sample_flow, 0L,
  "Full pooled sample (2010 + 2014)", nrow(ds_pooled))

# Step 1: Restrict to age 15-75 (DHHGAGE codes 2-15)
# dhhgage is a category code 1-16, not a year value.
# Code 2 = 15-17 yrs (lower bound), code 15 = 75-79 yrs (upper bound).
ds_analytic <- ds_pooled %>% dplyr::filter(dhhgage >= DHHGAGE_CODE_MIN, dhhgage <= DHHGAGE_CODE_MAX)
sample_flow <- add_flow_step(sample_flow, 1L,
  paste0("Age 15\u201375 (DHHGAGE codes ", DHHGAGE_CODE_MIN, "\u2013", DHHGAGE_CODE_MAX, ")"),
  nrow(ds_analytic))

# Step 2: Employed in past 3 months (LOP_015 = 1)
# LOP_015 codes: 1 = Yes, 2 = No; 6/7/8/9 = special (map to NA)
ds_analytic <- ds_analytic %>%
  dplyr::mutate(lop_015 = dplyr::if_else(lop_015 == 1L, 1L, NA_integer_)) %>%
  dplyr::filter(!is.na(lop_015))
sample_flow <- add_flow_step(sample_flow, 2L,
  "Employed in past 3 months (LOP_015 = 1)", nrow(ds_analytic))

# Step 3: Exclude proxy respondents (ADM_PRX = 1)
# ADM_PRX codes: 1 = proxy interview, 2 = not proxy
ds_analytic <- ds_analytic %>%
  dplyr::filter(adm_prx != 1L | is.na(adm_prx))
sample_flow <- add_flow_step(sample_flow, 3L,
  "Exclude proxy respondents (ADM_PRX = 1)", nrow(ds_analytic))

# Step 4: Exclude genuine non-response on outcome LOP components
# LOP day-count variables: valid range 1-90 (days); 0 is never recorded.
# NA (SPSS system-missing) = "NOT APPLICABLE" — the component count question
#   was not asked because the respondent had no days absent for that reason.
#   This is the survey skip pattern, not a data quality problem. Treated as 0.
# Code 99 = NOT STATED — genuine non-response; respondent was asked but gave
#   no valid answer. Excluded.
# No numeric codes 96, 97, 98 appear in the data (confirmed via codebook query).
lop_day_vars <- c("lopg040", "lopg070", "lopg082", "lopg083",
                  "lopg084", "lopg085", "lopg086", "lopg100")

ds_analytic <- ds_analytic %>%
  dplyr::mutate(dplyr::across(
    dplyr::all_of(lop_day_vars),
    ~dplyr::case_when(
      is.na(.) ~ 0,           # Not applicable = 0 days absent for this reason
      . == 99  ~ NA_real_,    # Not stated = genuine non-response → exclude
      TRUE     ~ as.double(.) # Valid day count (1–90)
    )
  )) %>%
  dplyr::filter(dplyr::if_all(dplyr::all_of(lop_day_vars), ~!is.na(.)))

sample_flow <- add_flow_step(sample_flow, 4L,
  "Complete outcome data (all 8 LOP day-count variables)", nrow(ds_analytic))

# Step 5: Flag completeness of chronic condition indicators (no row exclusion)
# CCC codes: 1 = Yes, 2 = No; 6/7/8/9 = special → NA.
# flag_complete_ccc = TRUE when all 17 CCC variables are non-NA.
# CCC_091 (COPD) was administered to a sub-sample in both cycles (~70% coverage);
# forcing complete-case exclusion here would drop ~22,000 rows.
ccc_vars <- c("ccc_031","ccc_041","ccc_051","ccc_061","ccc_071",
              "ccc_081","ccc_091","ccc_101","ccc_121","ccc_131",
              "ccc_141","ccc_151","ccc_171","ccc_251","ccc_261",
              "ccc_280","ccc_290")

ds_analytic <- ds_analytic %>%
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(ccc_vars),
      ~dplyr::case_when(. %in% c(6, 7, 8, 9) ~ NA_real_, TRUE ~ as.double(.))
    ),
    flag_complete_ccc = dplyr::if_all(dplyr::all_of(ccc_vars), ~!is.na(.))
  )

n_ccc_complete <- sum(ds_analytic$flag_complete_ccc)
cat("  flag_complete_ccc:", n_ccc_complete, "rows have all 17 CCC indicators\n")

# Step 6: Flag completeness of key predictor variables (no row exclusion)
# NOTE: dhhgage is excluded intentionally — its valid codes (1-16) overlap with
# the standard CCHS special-code range (6-9). Applying the bulk NA recode would
# silently drop all respondents aged 30-49 (codes 6-9). Age missingness is
# effectively impossible after the code-range filter in step 1.
# flag_complete_predictors = TRUE when all key predictors are non-NA.
key_predictor_vars <- c("dhh_sex", "dhhgms", "dhhghsz",
                        "geogprv", "incghh")

ds_analytic <- ds_analytic %>%
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(key_predictor_vars),
      ~dplyr::case_when(. %in% c(6, 7, 8, 9, 96, 97, 98, 99) ~ NA_real_, TRUE ~ as.double(.))
    ),
    flag_complete_predictors = dplyr::if_all(dplyr::all_of(key_predictor_vars), ~!is.na(.))
  )

n_pred_complete <- sum(ds_analytic$flag_complete_predictors)
cat("  flag_complete_predictors:", n_pred_complete, "rows have all key predictors\n")

# Combined completeness flag — convenience toggle for subsetting in analysis
ds_analytic <- ds_analytic %>%
  dplyr::mutate(flag_analytic_complete = flag_complete_ccc & flag_complete_predictors)

n_analytic <- sum(ds_analytic$flag_analytic_complete)
cat("  flag_analytic_complete:", n_analytic, "rows fully complete (CCC + predictors)\n")

# Print sample flow audit table
cat("\n  Sample Flow Audit:\n")
print(sample_flow, n = Inf)

# Warn if final n is far from the prior-analysis reference of 64,141
if (abs(nrow(ds_analytic) - 64141L) > 5000L) {
  warning(
    "Final analytic n = ", nrow(ds_analytic),
    " deviates >5,000 from prior-analysis reference (64,141). ",
    "Check exclusion criteria and variable coding."
  )
}

cat("\n---- SECTION: Construct Outcome Variable -----------------------------\n")
# ---- construct-outcome -------------------------------------------------------
# Primary outcome: total workdays absent in the past 3 months (any health reason)
# Formula: sum of all 8 LOP day-count components (NAs already removed above)
# Range: 0-90 days (per stats_instructions_v3 Section 4.1)
# Reference mean from prior analysis: 1.35 (SE = 0.02); 70.59% zero values

ds_analytic <- ds_analytic %>%
  dplyr::mutate(
    # Sum across all LOP day-count components
    days_absent_total = lopg040 + lopg070 + lopg082 + lopg083 +
                        lopg084 + lopg085 + lopg086 + lopg100,

    # Cap at 90 days (study-defined maximum per stats_instructions_v3 §4.1)
    days_absent_total = pmin(days_absent_total, 90),

    # Sensitivity outcome: days absent due to chronic condition only
    days_absent_chronic = pmin(lopg040, 90)
  )

cat("  Outcome summary (days_absent_total):\n")
cat("    Mean (unweighted):", round(mean(ds_analytic$days_absent_total), 2), "\n")
cat("    Zeros (%):", round(100 * mean(ds_analytic$days_absent_total == 0), 1), "\n")
cat("    Max:", max(ds_analytic$days_absent_total), "\n")

cat("\n---- SECTION: Recode Predictor Variables -----------------------------\n")
# ---- recode-demographics -----------------------------------------------------
# All factor recode blocks follow the same pattern:
#   1. Map CCHS special codes (6/7/8/9/96/97/98/99) to NA
#   2. Define levels explicitly — never rely on source ordering
#   3. Use factor() with named levels for transparency
#
# CCHS codebook references are cited per variable.

ds_analytic <- ds_analytic %>%
  dplyr::mutate(

    # ---- Age group (3 categories per stats_instructions_v3 §2.2)
    # DHHGAGE codes: 2=15-17, 3=18-19, 4=20-24, 5=25-29, ..., 10=50-54,
    #                11=55-59, 12=60-64, ..., 15=75-79
    # Regrouped to: 15-24 (codes 2-4), 25-54 (codes 5-10), 55-75 (codes 11-15)
    age_group_3 = dplyr::case_when(
      dhhgage %in% c(2, 3, 4)    ~ "15-24",
      dhhgage %in% c(5:10)       ~ "25-54",
      dhhgage %in% c(11:15)      ~ "55-75",
      TRUE                       ~ NA_character_
    ) %>% factor(levels = c("15-24", "25-54", "55-75")),

    # ---- Sex  (CCHS DHH_SEX: 1=Male, 2=Female)
    sex = dplyr::case_when(
      dhh_sex == 1 ~ "Male",
      dhh_sex == 2 ~ "Female",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Male", "Female")),

    # ---- Marital status (DHHGMS: 1=MARRIED, 2=COMMON-LAW, 3=WIDOW/SEP/DIV, 4=SINGLE/NEVER MAR)
    marital_status = dplyr::case_when(
      dhhgms == 1 ~ "Married",
      dhhgms == 2 ~ "Common-law",
      dhhgms == 3 ~ "Widowed / Separated / Divorced",
      dhhgms == 4 ~ "Single / Never married",
      TRUE        ~ NA_character_
    ) %>% factor(levels = c("Married", "Common-law",
                             "Widowed / Separated / Divorced",
                             "Single / Never married")),

    # ---- Household size (DHHGHSZ: 1=1 PERSON, 2=2 PERSONS, 3=3 PERSONS,
    #                               4=4 PERSONS, 5=5 OR + PERSONS; 6-9=NA)
    # Code 5 is an upper-bounded category ("5 or more") — stored as ordered factor
    # to preserve correct semantics and prevent false arithmetic precision.
    household_size = dplyr::case_when(
      dhhghsz == 1 ~ "1 person",
      dhhghsz == 2 ~ "2 persons",
      dhhghsz == 3 ~ "3 persons",
      dhhghsz == 4 ~ "4 persons",
      dhhghsz == 5 ~ "5 or more persons",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("1 person", "2 persons", "3 persons",
                             "4 persons", "5 or more persons"),
                 ordered = TRUE),

    # ---- Province of residence (GEOGPRV: 10-62; codes follow Statistics Canada)
    province = dplyr::case_when(
      geogprv == 10 ~ "NL", geogprv == 11 ~ "PEI", geogprv == 12 ~ "NS",
      geogprv == 13 ~ "NB", geogprv == 24 ~ "QC",  geogprv == 35 ~ "ON",
      geogprv == 46 ~ "MB", geogprv == 47 ~ "SK",  geogprv == 48 ~ "AB",
      geogprv == 59 ~ "BC", geogprv == 60 ~ "YK",  geogprv == 61 ~ "NT",
      geogprv == 62 ~ "NU",
      TRUE          ~ NA_character_
    ) %>% factor(levels = c("NL","PEI","NS","NB","QC","ON",
                             "MB","SK","AB","BC","YK","NT","NU")),

    # ---- Household income (INCGHH: 1=NO OR <$20,000, 2=$20-$39K,
    #                                3=$40-$59K, 4=$60-$79K, 5=$80K+)
    income_hh = dplyr::case_when(
      incghh == 1 ~ "No income or < $20,000",
      incghh == 2 ~ "$20,000 - $39,999",
      incghh == 3 ~ "$40,000 - $59,999",
      incghh == 4 ~ "$60,000 - $79,999",
      incghh == 5 ~ "$80,000 +",
      TRUE        ~ NA_character_
    ) %>% factor(levels = c("No income or < $20,000","$20,000 - $39,999",
                             "$40,000 - $59,999","$60,000 - $79,999",
                             "$80,000 +")),

    # ---- CYCLE factor
    cchs_cycle_f = dplyr::case_when(
      cchs_cycle == 0L ~ "2010-2011",
      cchs_cycle == 1L ~ "2013-2014",
      TRUE             ~ NA_character_
    ) %>% factor(levels = c("2010-2011", "2013-2014"))

  ) # end mutate demographics

# ---- recode-chronic-conditions -----------------------------------------------
# CCC variables: 1 = Yes (has condition), 2 = No; 6/7/8/9 = NA (already set above)
# Recode to logical indicators: TRUE = has condition
ds_analytic <- ds_analytic %>%
  dplyr::mutate(dplyr::across(
    dplyr::all_of(ccc_vars),
    ~dplyr::case_when(. == 1 ~ TRUE, . == 2 ~ FALSE, TRUE ~ NA)
  )) %>%
  dplyr::rename(
    cond_asthma           = ccc_031,
    cond_fibromyalgia     = ccc_041,
    cond_arthritis        = ccc_051,
    cond_back_problems    = ccc_061,
    cond_hypertension     = ccc_071,
    cond_migraine         = ccc_081,
    cond_copd             = ccc_091,
    cond_diabetes         = ccc_101,
    cond_heart_disease    = ccc_121,
    cond_cancer           = ccc_131,
    cond_ulcer            = ccc_141,
    cond_stroke           = ccc_151,
    cond_bowel_disorder   = ccc_171,
    cond_fatigue_syndrome = ccc_251,
    cond_chem_sensitivity = ccc_261,
    cond_mood_disorder    = ccc_280,
    cond_anxiety          = ccc_290
  )

# ---- recode-health-behaviours ------------------------------------------------
ds_analytic <- ds_analytic %>%
  dplyr::mutate(

    # BMI category (HWTGISW: 1=Underweight, 2=Normal, 3=Overweight, 4=Obese; 9=NA)
    bmi_category = dplyr::case_when(
      hwtgisw == 1 ~ "Underweight",
      hwtgisw == 2 ~ "Normal weight",
      hwtgisw == 3 ~ "Overweight",
      hwtgisw == 4 ~ "Obese",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Underweight","Normal weight","Overweight","Obese")),

    # Alcohol use — type of drinker (ALCDTTM: 1=REGULAR DRINKER, 2=OCCASIO. DRINKER,
    #                                          3=NO DRINK LAST12M; 6/7/8/9=NA)
    # Codebook has 3 valid codes only. Code 3 captures all non-drinkers in the past
    # 12 months and does not distinguish former drinkers from lifetime abstainers.
    alcohol_type = dplyr::case_when(
      alcdttm == 1 ~ "Regular drinker",
      alcdttm == 2 ~ "Occasional drinker",
      alcdttm == 3 ~ "Did not drink in past 12 months",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Regular drinker","Occasional drinker",
                             "Did not drink in past 12 months")),

    # Physical activity index (PACDPAI: 1=Active, 2=Moderately active, 3=Inactive)
    physical_activity = dplyr::case_when(
      pacdpai == 1 ~ "Active",
      pacdpai == 2 ~ "Moderately active",
      pacdpai == 3 ~ "Inactive",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Active","Moderately active","Inactive")),

    # Fruit and vegetable consumption (FVCGTOT: 1=LESS 5 PER DAY, 2=5-10 TIMES/DAY,
    #                                           3=MORE 10 TIMES/DAY; 6/7/8/9=NA)
    # FVCGTOT is a 3-code category variable, not a raw count of daily servings.
    fruit_veg_daily = dplyr::case_when(
      fvcgtot == 1 ~ "Less than 5 per day",
      fvcgtot == 2 ~ "5 to 10 per day",
      fvcgtot == 3 ~ "More than 10 per day",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Less than 5 per day","5 to 10 per day",
                             "More than 10 per day"))

  )

# ---- recode-perceived-health -------------------------------------------------
ds_analytic <- ds_analytic %>%
  dplyr::mutate(

    # Self-perceived general health (GEN_01: 1=Excellent, 2=VGood, 3=Good, 4=Fair, 5=Poor)
    health_perceived = dplyr::case_when(
      gen_01 == 1 ~ "Excellent",
      gen_01 == 2 ~ "Very good",
      gen_01 == 3 ~ "Good",
      gen_01 == 4 ~ "Fair",
      gen_01 == 5 ~ "Poor",
      TRUE        ~ NA_character_
    ) %>% factor(levels = c("Excellent","Very good","Good","Fair","Poor")),

    # Self-perceived mental health (GEN_02B: 1=Excellent, 2=VGood, 3=Good, 4=Fair, 5=Poor)
    mental_health_perceived = dplyr::case_when(
      gen_02b == 1 ~ "Excellent",
      gen_02b == 2 ~ "Very good",
      gen_02b == 3 ~ "Good",
      gen_02b == 4 ~ "Fair",
      gen_02b == 5 ~ "Poor",
      TRUE         ~ NA_character_
    ) %>% factor(levels = c("Excellent","Very good","Good","Fair","Poor")),

    # Self-perceived health compared to prior year
    # (GEN_02: 1=MUCH BETTER, 2=SOMEWHAT BETTER, 3=ABOUT THE SAME,
    #          4=SOMEWHAT WORSE, 5=MUCH WORSE; 6/7/8/9=NA)
    health_vs_prior_year = dplyr::case_when(
      gen_02 == 1 ~ "Much better",
      gen_02 == 2 ~ "Somewhat better",
      gen_02 == 3 ~ "About the same",
      gen_02 == 4 ~ "Somewhat worse",
      gen_02 == 5 ~ "Much worse",
      TRUE        ~ NA_character_
    ) %>% factor(levels = c("Much better","Somewhat better","About the same",
                             "Somewhat worse","Much worse"))

  )

# ---- recode-inferred-conditionally -------------------------------------------
# Inferred variables: only recode if they survived the white-list drop
if ("edudr04" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # EDUDR04: 1=Less than sec, 2=Secondary grad, 3=Some post-sec, 4=Post-sec grad
      education = dplyr::case_when(
        edudr04 == 1 ~ "Less than secondary",
        edudr04 == 2 ~ "Secondary graduate",
        edudr04 == 3 ~ "Some post-secondary",
        edudr04 == 4 ~ "Post-secondary graduate",
        TRUE         ~ NA_character_
      ) %>% factor(levels = c("Less than secondary","Secondary graduate",
                               "Some post-secondary","Post-secondary graduate"))
    )
}

if ("sdcfimm" %in% names(ds_analytic) && "sdcgres" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # immigration_status: derived from TWO variables jointly.
      #
      # SDCFIMM (Immigrant - F): 1=YES (immigrant), 2=NO (non-immigrant), 9=NOT STATED.
      # SDCGRES (Length/time in Canada): 1=0-9 yrs (recent), 2=10+ yrs (long-term), 9=NOT STATED.
      #
      # CRITICAL DATA QUALITY NOTE:
      # SPSS stores SDCGRES code 6 ("NOT APPLICABLE", i.e., Canadian-born) as SYSTEM MISSING.
      # After haven::zap_labels() in the Ferry, that column is NA — NOT numeric 6.
      # Therefore `sdcgres == 6` NEVER fires. Non-immigrants must be identified via
      # SDCFIMM == 2 (NO) instead.
      #
      # Joint recode logic:
      #   SDCFIMM=1 & SDCGRES=1  → Recent immigrant (0-9 yrs)
      #   SDCFIMM=1 & SDCGRES=2  → Long-term immigrant (10+ yrs)
      #   SDCFIMM=2              → Non-immigrant (Canadian-born)
      #   All other combinations  → NA (NOT STATED / REFUSAL / unknown)
      immigration_status = dplyr::case_when(
        sdcfimm == 1 & sdcgres == 1 ~ "Recent immigrant (0-9 yrs in Canada)",
        sdcfimm == 1 & sdcgres == 2 ~ "Long-term immigrant (10+ yrs in Canada)",
        sdcfimm == 2                 ~ "Non-immigrant (Canadian-born)",
        TRUE                         ~ NA_character_
      ) %>% factor(levels = c("Non-immigrant (Canadian-born)",
                               "Long-term immigrant (10+ yrs in Canada)",
                               "Recent immigrant (0-9 yrs in Canada)"))
    )
} else if ("sdcgres" %in% names(ds_analytic)) {
  # Fallback: sdcfimm was dropped — use sdcgres alone (non-immigrants will be NA)
  warning("sdcfimm not found — immigration_status will lack Non-immigrant category.")
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      immigration_status = dplyr::case_when(
        sdcgres == 1 ~ "Recent immigrant (0-9 yrs in Canada)",
        sdcgres == 2 ~ "Long-term immigrant (10+ yrs in Canada)",
        TRUE         ~ NA_character_
      ) %>% factor(levels = c("Non-immigrant (Canadian-born)",
                               "Long-term immigrant (10+ yrs in Canada)",
                               "Recent immigrant (0-9 yrs in Canada)"))
    )
}

if ("sdcgcgt" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # SDCGCGT: 1=White, 2=Non-White (visible minority), 9=NA
      visible_minority = dplyr::case_when(
        sdcgcgt == 1 ~ "White",
        sdcgcgt == 2 ~ "Visible minority",
        TRUE         ~ NA_character_
      ) %>% factor(levels = c("White","Visible minority"))
    )
}

if ("lbsdpft" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # LBSDPFT: 1=Full-time, 2=Part-time, 9=NA
      work_schedule = dplyr::case_when(
        lbsdpft == 1 ~ "Full-time",
        lbsdpft == 2 ~ "Part-time",
        TRUE         ~ NA_character_
      ) %>% factor(levels = c("Full-time","Part-time"))
    )
}

if ("hcu_1aa_h" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # HCU_1AA (2014) / ACC_50A (2010) harmonized: 1=Yes, 2=No
      has_family_doctor = dplyr::case_when(
        hcu_1aa_h == 1 ~ "Yes",
        hcu_1aa_h == 2 ~ "No",
        TRUE           ~ NA_character_
      ) %>% factor(levels = c("Yes","No"))
    )
}

if ("adlf6r" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # ADLF6R: derived flag — 1=needs help for at least one task, 2=no help needed
      functional_limitation = dplyr::case_when(
        adlf6r == 1 ~ "Needs help",
        adlf6r == 2 ~ "No help needed",
        TRUE        ~ NA_character_
      ) %>% factor(levels = c("No help needed","Needs help"))
    )
}

if ("inj_01" %in% names(ds_analytic)) {
  ds_analytic <- ds_analytic %>%
    dplyr::mutate(
      # INJ_01: 1=Yes (injured in past 12 months), 2=No
      injured_past_12m = dplyr::case_when(
        inj_01 == 1 ~ "Yes",
        inj_01 == 2 ~ "No",
        TRUE        ~ NA_character_
      ) %>% factor(levels = c("No","Yes"))
    )
}

cat("\n---- SECTION: Final Dataset Assembly ---------------------------------\n")
# ---- assemble-final ----------------------------------------------------------
# Select the analysis-ready columns for output.
# Raw source columns (CCHS codes) are dropped; recoded variables are retained.

ds_out <- ds_analytic %>%
  dplyr::select(
    # Survey design
    cchs_cycle, cchs_cycle_f, wts_m, wts_m_pooled,
    # Outcome
    days_absent_total, days_absent_chronic,
    # Raw LOP components (keep for sensitivity checks)
    dplyr::all_of(lop_day_vars),
    # Chronic condition flags (renamed logical)
    dplyr::starts_with("cond_"),
    # Demographics (recoded)
    age_group_3, dhhgage, sex, marital_status, household_size,
    dplyr::any_of(c("dhhgle5","dhhg611","dhhgl12")),
    province, income_hh,
    dplyr::any_of(c("education","immigration_status","visible_minority",
                    "has_family_doctor","work_schedule")),
    # Health behaviours
    dplyr::any_of(c("bmi_category","hwtgbmi","alcohol_type",
                    "fruit_veg_daily","physical_activity")),
    # Perceived health
    dplyr::any_of(c("health_perceived","mental_health_perceived",
                    "health_vs_prior_year","gen_09")),
    # Functional limitations
    dplyr::any_of(c("adl_01","adl_02","adl_03","adl_04","adl_05","adl_06",
                    "functional_limitation","injured_past_12m")),
    # Completeness flags (use to subset for analysis-ready subsamples)
    flag_complete_ccc, flag_complete_predictors, flag_analytic_complete
  )

cat("  Final analytic dataset:", nrow(ds_out), "rows x", ncol(ds_out), "cols\n")

cat("\n---- SECTION: Write Output -------------------------------------------\n")
# ---- write-ellis-sqlite ------------------------------------------------------
if (!fs::dir_exists(dirname(path_ellis))) {
  fs::dir_create(dirname(path_ellis), recursive = TRUE)
}

con_out <- DBI::dbConnect(RSQLite::SQLite(), dbname = path_ellis)
DBI::dbWriteTable(con_out, "cchs_analytic", ds_out, overwrite = TRUE)
DBI::dbWriteTable(con_out, "sample_flow",   sample_flow, overwrite = TRUE)
DBI::dbDisconnect(con_out)
cat("  Written to:", path_ellis, " (tables: cchs_analytic, sample_flow)\n")

# ---- write-parquet -----------------------------------------------------------
if (!fs::dir_exists(parquet_dir)) fs::dir_create(parquet_dir, recursive = TRUE)

arrow::write_parquet(ds_out,      file.path(parquet_dir, "cchs_analytic.parquet"))
arrow::write_parquet(sample_flow, file.path(parquet_dir, "sample_flow.parquet"))
cat("  Written parquet files to:", parquet_dir, "\n")

cat("\n---- SECTION: Session Info -------------------------------------------\n")
elapsed <- as.numeric(difftime(Sys.time(), report_render_start_time, units = "secs"))
cat(sprintf("  Elapsed: %.0f seconds\n", elapsed))
sessionInfo()
