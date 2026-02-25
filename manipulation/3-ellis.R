#' ---
#' title: "Ellis Lane 3: CCHS Clarity Dataset Build"
#' author: "Andriy Koval"
#' date: "2026-02-22"
#' ---
#'
#' ============================================================================
#' ELLIS PATTERN: Build clear analyst-facing tables from Lane 2 outputs
#' ============================================================================
#'
#' Purpose:
#'   1) Keep full sample context from Lane 2
#'   2) Remove less useful columns in curated outputs
#'   3) Split into employed and unemployed tables
#'   4) Rename key columns for clearer interpretation
#'   5) Save as cchs-3.sqlite + cchs-3-tables/ and produce 3-ellis.html
#'
#' Input:
#'   Primary: ./data-private/derived/cchs-2-tables/
#'            - cchs_analytical.parquet
#'            - sample_flow.parquet
#'   Fallback: ./data-private/derived/cchs-2.sqlite (same table names)
#'
#' Output:
#'   SQLite:  ./data-private/derived/cchs-3.sqlite
#'   Parquet: ./data-private/derived/cchs-3-tables/
#'            - cchs_analytical.parquet
#'            - cchs_employed.parquet
#'            - cchs_unemployed.parquet
#'            - sample_flow.parquet
#'            - data_dictionary.parquet
#'   HTML:    ./manipulation/3-ellis.html
#' ============================================================================

#+ echo=F
# rmarkdown::render(input = "./manipulation/3-ellis.R")

# ---- setup -------------------------------------------------------------------
rm(list = ls(all.names = TRUE))
cat("\014")
script_start <- Sys.time()

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(stringr)
library(janitor)
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("checkmate")
requireNamespace("arrow")
requireNamespace("fs")

# ---- load-sources ------------------------------------------------------------
project_root <- if (dir.exists("scripts") && dir.exists("manipulation")) {
  "."
} else if (dir.exists("../scripts") && dir.exists("../manipulation")) {
  ".."
} else {
  stop("Cannot locate project root. Run from project root or from manipulation/.")
}
base::source(file.path(project_root, "scripts", "common-functions.R"))

# ---- declare-globals ---------------------------------------------------------
input_parquet_dir <- file.path(project_root, "data-private", "derived", "cchs-2-tables")
input_parquet_analytical <- file.path(input_parquet_dir, "cchs_analytical.parquet")
input_parquet_flow <- file.path(input_parquet_dir, "sample_flow.parquet")
input_sqlite <- file.path(project_root, "data-private", "derived", "cchs-2.sqlite")

output_parquet_dir <- file.path(project_root, "data-private", "derived", "cchs-3-tables")
output_sqlite <- file.path(project_root, "data-private", "derived", "cchs-3.sqlite")
output_html <- file.path(project_root, "manipulation", "3-ellis.html")

if (!fs::dir_exists(output_parquet_dir)) fs::dir_create(output_parquet_dir, recurse = TRUE)

# ---- helper-functions --------------------------------------------------------
map_employment_code <- function(x) {
  dplyr::case_when(
    x == 1L ~ "Employed",
    x == 2L ~ "Unemployed",
    x == 6L ~ "Not applicable",
    x == 7L ~ "Don't know",
    x == 8L ~ "Refusal",
    x == 9L ~ "Not stated",
    is.na(x) ~ "Missing",
    TRUE ~ "Other"
  )
}

map_proxy_code <- function(x) {
  dplyr::case_when(
    x == 1L ~ "Proxy",
    x == 2L ~ "Non-proxy",
    x == 6L ~ "Not applicable",
    x == 7L ~ "Don't know",
    x == 8L ~ "Refusal",
    x == 9L ~ "Not stated",
    is.na(x) ~ "Missing",
    TRUE ~ "Other"
  )
}

map_cycle <- function(x) {
  dplyr::case_when(
    x == 0L ~ "CCHS 2010-2011",
    x == 1L ~ "CCHS 2013-2014",
    TRUE ~ "Unknown"
  )
}

rename_with_map <- function(df, rename_map) {
  current_names <- names(df)
  for (old_name in names(rename_map)) {
    if (old_name %in% current_names) {
      current_names[current_names == old_name] <- rename_map[[old_name]]
    }
  }
  names(df) <- current_names
  df
}

write_fallback_html <- function(path, n_analytical, n_emp, n_unemp) {
  lines <- c(
    "<!DOCTYPE html>",
    "<html lang='en'>",
    "<head><meta charset='utf-8'><title>Ellis 3 Report</title>",
    "<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;}table{border-collapse:collapse;}th,td{border:1px solid #ddd;padding:8px;}th{background:#f5f5f5;}</style>",
    "</head><body>",
    "<h1>Ellis Lane 3 Report</h1>",
    paste0("<p>Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</p>"),
    "<table><tr><th>Table</th><th>Rows</th></tr>",
    paste0("<tr><td>cchs_analytical</td><td>", format(n_analytical, big.mark = ","), "</td></tr>"),
    paste0("<tr><td>cchs_employed</td><td>", format(n_emp, big.mark = ","), "</td></tr>"),
    paste0("<tr><td>cchs_unemployed</td><td>", format(n_unemp, big.mark = ","), "</td></tr>"),
    "</table>",
    "</body></html>"
  )
  writeLines(lines, path)
}

# ==============================================================================
# SECTION 1: DATA IMPORT
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 1: DATA IMPORT\n")
cat(strrep("=", 70), "\n")

if (file.exists(input_parquet_analytical) && file.exists(input_parquet_flow)) {
  ds0 <- arrow::read_parquet(input_parquet_analytical)
  sample_flow <- arrow::read_parquet(input_parquet_flow)
  input_mode <- "parquet"
} else if (file.exists(input_sqlite)) {
  cnn <- DBI::dbConnect(RSQLite::SQLite(), input_sqlite)
  on.exit(DBI::dbDisconnect(cnn), add = TRUE)

  tables <- DBI::dbListTables(cnn)
  checkmate::assert_true("cchs_analytical" %in% tables)
  checkmate::assert_true("sample_flow" %in% tables)

  ds0 <- DBI::dbGetQuery(cnn, "SELECT * FROM cchs_analytical")
  sample_flow <- DBI::dbGetQuery(cnn, "SELECT * FROM sample_flow")
  input_mode <- "sqlite"
} else {
  stop("Cannot find Lane 2 inputs. Run manipulation/2-ellis.R first.")
}

cat(sprintf("📥 Input mode: %s\n", input_mode))
cat(sprintf("📥 cchs_analytical rows: %s | cols: %s\n",
            format(nrow(ds0), big.mark = ","),
            format(ncol(ds0), big.mark = ",")))

# ==============================================================================
# SECTION 2: CLARITY TRANSFORMATIONS
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 2: CLARITY TRANSFORMATIONS\n")
cat(strrep("=", 70), "\n")

# Step 1: standardize names
ds1 <- ds0 %>% janitor::clean_names()

# Step 2: create renamed analytical version
# Keep all columns except explicitly excluded ones, and rename fields.
exclude_cols <- c(
  "adm_rno",
  "income_5cat",
  "employment_type",
  "work_schedule",
  "alcohol_type",
  "bmi_category",
  "dhhgage"
)

cchs_analytical <- ds1 %>%
  select(-any_of(exclude_cols))

# Short, understandable English names based on cchs-2 dictionary meanings.
rename_map <- c(
  cycle = "survey_cycle_id",
  cycle_f = "survey_cycle_label",
  lop_015 = "employment_code",
  adm_prx = "proxy_code",
  days_absent_total = "absence_days_total",
  days_absent_chronic = "absence_days_chronic",
  lopg040 = "abs_chronic_days",
  lopg070 = "abs_injury_days",
  lopg082 = "abs_cold_days",
  lopg083 = "abs_flu_days",
  lopg084 = "abs_stomach_flu_days",
  lopg085 = "abs_resp_infection_days",
  lopg086 = "abs_other_infection_days",
  lopg100 = "abs_other_health_days",
  wts_m_pooled = "weight_pooled",
  wts_m_original = "weight_original",
  geodpmf = "geo_region_id",
  age_group = "age_group_3",
  sex = "sex_label",
  marital_status = "marital_status_label",
  education = "education_level",
  immigration_status = "immigration_status_label",
  visible_minority = "visible_minority_label",
  has_family_doctor = "has_family_doctor_label",
  smoking_status = "smoking_status_label",
  physical_activity = "physical_activity_label",
  self_health_general = "self_health_general_label",
  self_health_mental = "self_health_mental_label",
  health_vs_lastyear = "health_vs_last_year_label",
  activity_limitation = "activity_limitation_label",
  injury_past_year = "injury_past_year_label",
  dhhdghsz = "household_size",
  fvcdgtot = "fruit_veg_daily_total",
  cc_arthritis = "chronic_arthritis",
  cc_back_problems = "chronic_back_problems",
  cc_hypertension = "chronic_hypertension",
  cc_migraine = "chronic_migraine",
  cc_copd = "chronic_copd",
  cc_diabetes = "chronic_diabetes",
  cc_heart_disease = "chronic_heart_disease",
  cc_cancer = "chronic_cancer",
  cc_ulcer = "chronic_ulcer",
  cc_stroke = "chronic_stroke",
  cc_bowel_disorder = "chronic_bowel_disorder",
  cc_chronic_fatigue = "chronic_fatigue_syndrome",
  cc_chemical_sensitiv = "chronic_chemical_sensitivity",
  cc_mood_disorder = "chronic_mood_disorder",
  cc_anxiety_disorder = "chronic_anxiety_disorder"
)

cchs_analytical <- cchs_analytical %>%
  rename_with_map(rename_map) %>%
  mutate(
    survey_cycle = factor(map_cycle(as.integer(survey_cycle_id)),
                          levels = c("CCHS 2010-2011", "CCHS 2013-2014", "Unknown")),
    employment_status = factor(map_employment_code(as.integer(employment_code)),
                               levels = c("Employed", "Unemployed", "Not applicable", "Don't know", "Refusal", "Not stated", "Missing", "Other")),
    proxy_status = factor(map_proxy_code(as.integer(proxy_code)),
                          levels = c("Non-proxy", "Proxy", "Not applicable", "Don't know", "Refusal", "Not stated", "Missing", "Other")),
    has_any_absence = factor(case_when(
      is.na(absence_days_total) ~ NA_character_,
      absence_days_total > 0 ~ "Yes",
      TRUE ~ "No"
    ), levels = c("No", "Yes"))
  )

# Step 3: split employed / unemployed from renamed analytical table
ds_employed <- cchs_analytical %>% filter(employment_code == 1L)
ds_unemployed <- cchs_analytical %>% filter(is.na(employment_code) | employment_code != 1L)

cat(sprintf("   ✓ Renamed analytical rows:  %s (cols: %d)\n",
            format(nrow(cchs_analytical), big.mark = ","), ncol(cchs_analytical)))
cat(sprintf("   ✓ Employed rows:            %s\n", format(nrow(ds_employed), big.mark = ",")))
cat(sprintf("   ✓ Unemployed/rest rows:     %s\n", format(nrow(ds_unemployed), big.mark = ",")))
cat("   ℹ Note: cchs_unemployed is defined as NOT employed (all rows where employment_code != 1 or missing).\n")

# Step 5: dictionary for exclusions + renames
data_dictionary <- tibble::tibble(
  item_type = c(rep("excluded", length(exclude_cols)), rep("renamed", length(rename_map))),
  original_column = c(
    exclude_cols,
    names(rename_map)
  ),
  new_column = c(
    rep(NA_character_, length(exclude_cols)),
    unname(rename_map)
  ),
  note = c(
    rep("Excluded per analyst request", length(exclude_cols)),
    rep("Renamed to short, clear English label", length(rename_map))
  )
)

# ==============================================================================
# SECTION 3: VALIDATION
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 3: VALIDATION\n")
cat(strrep("=", 70), "\n")

checkmate::assert_true(nrow(cchs_analytical) == nrow(ds0))
checkmate::assert_true(all(!exclude_cols %in% names(cchs_analytical)))
checkmate::assert_true(nrow(ds_employed) + nrow(ds_unemployed) == nrow(cchs_analytical))
checkmate::assert_names(names(cchs_analytical),
                        must.include = c("survey_cycle_id", "employment_code", "absence_days_total", "weight_pooled", "chronic_arthritis"))
checkmate::assert_numeric(cchs_analytical$weight_pooled, any.missing = FALSE, lower = 0)

cat("✅ Validation checks passed\n")

# ==============================================================================
# SECTION 4: SAVE TO PARQUET (Primary)
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 4: SAVE TO PARQUET\n")
cat(strrep("=", 70), "\n")

arrow::write_parquet(cchs_analytical, file.path(output_parquet_dir, "cchs_analytical.parquet"))
arrow::write_parquet(ds_employed,     file.path(output_parquet_dir, "cchs_employed.parquet"))
arrow::write_parquet(ds_unemployed,   file.path(output_parquet_dir, "cchs_unemployed.parquet"))
arrow::write_parquet(sample_flow,          file.path(output_parquet_dir, "sample_flow.parquet"))
arrow::write_parquet(data_dictionary,      file.path(output_parquet_dir, "data_dictionary.parquet"))

cat("✅ Parquet outputs written to cchs-3-tables/\n")

# ==============================================================================
# SECTION 5: SAVE TO SQLITE (Secondary)
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 5: SAVE TO SQLITE\n")
cat(strrep("=", 70), "\n")

if (file.exists(output_sqlite)) file.remove(output_sqlite)

to_sql <- function(d) d %>% mutate(across(where(is.factor), as.character))

cnn_out <- DBI::dbConnect(RSQLite::SQLite(), output_sqlite)
DBI::dbWriteTable(cnn_out, "cchs_analytical", to_sql(cchs_analytical), overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "cchs_employed",   to_sql(ds_employed),     overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "cchs_unemployed", to_sql(ds_unemployed),   overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "sample_flow",           to_sql(sample_flow),          overwrite = TRUE)
DBI::dbWriteTable(cnn_out, "data_dictionary",       to_sql(data_dictionary),      overwrite = TRUE)
DBI::dbDisconnect(cnn_out)

cat(sprintf("✅ SQLite saved: %s\n", output_sqlite))

# ==============================================================================
# SECTION 6: HTML REPORT
# ==============================================================================
cat("\n", strrep("=", 70), "\n")
cat("SECTION 6: HTML REPORT\n")
cat(strrep("=", 70), "\n")

# Prevent recursive rendering loop
if (!identical(Sys.getenv("ELLIS3_RENDERING"), "1")) {
  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    Sys.setenv(ELLIS3_RENDERING = "1")
    tryCatch({
      rmarkdown::render(
        input = file.path(project_root, "manipulation", "3-ellis.R"),
        output_format = "html_document",
        output_dir = file.path(project_root, "manipulation"),
        clean = TRUE,
        quiet = TRUE
      )
      cat("✅ HTML rendered: ./manipulation/3-ellis.html\n")
    }, error = function(e) {
      warning("rmarkdown render failed: ", conditionMessage(e))
      write_fallback_html(output_html,
                          nrow(cchs_analytical),
                          nrow(ds_employed),
                          nrow(ds_unemployed))
      cat("✅ Fallback HTML created: ./manipulation/3-ellis.html\n")
    })
  } else {
    write_fallback_html(output_html,
                        nrow(cchs_analytical),
                        nrow(ds_employed),
                        nrow(ds_unemployed))
    cat("✅ Fallback HTML created: ./manipulation/3-ellis.html\n")
  }
} else {
  cat("ℹ Nested render detected; skip rendering call.\n")
}

# ==============================================================================
# SECTION 7: SESSION INFO
# ==============================================================================
duration <- difftime(Sys.time(), script_start, units = "secs")
cat("\n", strrep("=", 70), "\n")
cat("SESSION INFO\n")
cat(strrep("=", 70), "\n")

cat(sprintf("\n⏱️  Ellis 3 completed in %.1f seconds\n", as.numeric(duration)))
cat(sprintf("📅 Executed: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(sprintf("👤 User: %s\n", Sys.info()["user"]))
cat(sprintf("📦 Output rows — analytical: %s | employed: %s | unemployed: %s\n",
            format(nrow(cchs_analytical), big.mark = ","),
            format(nrow(ds_employed), big.mark = ","),
            format(nrow(ds_unemployed), big.mark = ",")))

sessionInfo()
