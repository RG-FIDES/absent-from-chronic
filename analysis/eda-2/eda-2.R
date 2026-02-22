# nolint start
# AI agents must consult ./analysis/eda-2/eda-style-guide.md before making changes to this file.
# (Copy eda-style-guide.md from eda-1 when ready, or reference ./analysis/eda-1/eda-style-guide.md)
rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run. This is not called by knitr, because it's above the first chunk.
cat("\014") # Clear the console
# verify root location
cat("Working directory: ", getwd()) # Must be set to Project Directory
# Project Directory should be the root by default unless overwritten

# ---- load-packages -----------------------------------------------------------
# Choose to be greedy: load only what's needed
# Three ways, from least (1) to most(3) greedy:
# -- 1.Attach these packages so their functions don't need to be qualified:
# http://r-pkgs.had.co.nz/namespace.html#search-path
library(magrittr)
library(ggplot2)   # graphs
library(forcats)   # factors
library(stringr)   # strings
library(lubridate) # dates
library(labelled)  # labels
library(dplyr)     # data wrangling
library(tidyr)     # data wrangling
library(scales)    # format
library(broom)     # for model
library(emmeans)   # for interpreting model results
library(janitor)   # tidy data
library(testit)    # For asserting conditions meet expected patterns.
library(fs)        # file system operations
requireNamespace("DBI")     # database interface
requireNamespace("RSQLite") # SQLite driver

# ---- httpgd (VS Code interactive plots) ------------------------------------
# If the httpgd package is installed, try to start it so VS Code R extension
# can display interactive plots. This is optional and wrapped in tryCatch so
# the script still runs when httpgd is absent or fails to start.
if (requireNamespace("httpgd", quietly = TRUE)) {
	tryCatch({
		if (is.function(httpgd::hgd)) {
			httpgd::hgd()
		} else if (is.function(httpgd::httpgd)) {
			httpgd::httpgd()
		} else {
			httpgd::hgd()
		}
		message("httpgd started (if available). Configure your VS Code R extension to use it for plots.")
	}, error = function(e) {
		message("httpgd detected but failed to start: ", conditionMessage(e))
	})
} else {
	message("httpgd not installed. To enable interactive plotting in VS Code, install httpgd (binary recommended on Windows) or use other devices (svg/png).")
}

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")      # project-level
base::source("./scripts/operational-functions.R") # project-level

# ---- declare-globals ---------------------------------------------------------

local_root <- "./analysis/eda-2/"
local_data <- paste0(local_root, "data-local/") # for local outputs

if (!fs::dir_exists(local_data))         {fs::dir_create(local_data)}

data_private_derived <- "./data-private/derived/eda-2/"
if (!fs::dir_exists(data_private_derived)) {fs::dir_create(data_private_derived)}

prints_folder <- paste0(local_root, "prints/")
if (!fs::dir_exists(prints_folder))      {fs::dir_create(prints_folder)}

# ---- declare-functions -------------------------------------------------------
# Uncomment when local-functions.R is created:
# base::source(paste0(local_root, "local-functions.R"))

# ---- load-data ---------------------------------------------------------------
# Source: cchs_employed table from Lane 3 output
# Each row = one employed survey respondent
# Key variable: absence_days_total — total work days missed due to any health reason
db_path <- "./data-private/derived/cchs-3.sqlite"

cnn <- DBI::dbConnect(RSQLite::SQLite(), db_path)
ds0 <- DBI::dbGetQuery(cnn, "SELECT * FROM cchs_employed")
DBI::dbDisconnect(cnn)   # disconnect immediately — avoids 'closed connection' in knitr chunks
rm(cnn)

message("📊 Data loaded:")
message("  - ds0 (cchs_employed): ", format(nrow(ds0), big.mark = ","), " employed respondents")
message("  - Source: ", db_path)

# ---- tweak-data-0 ------------------------------------------------------------
# Coerce types; no records are dropped here (NAs remain for transparency).
ds0 <- ds0 |>
  dplyr::mutate(
    absence_days_total = as.integer(absence_days_total),
    has_any_absence    = dplyr::if_else(is.na(absence_days_total), NA,
                                        absence_days_total > 0L)
  )

# ---- inspect-data-0 ----------------------------------------------------------
cat("📊 Data Overview:\n")
cat("  - ds0 (cchs_employed):", format(nrow(ds0), big.mark = ","), "rows ×", ncol(ds0), "cols\n")
cat("  - NA absence_days_total:", sum(is.na(ds0$absence_days_total)), "\n")
cat("  - 0 days absent:        ", sum(ds0$absence_days_total == 0L, na.rm = TRUE), "\n")
cat("  - 1+ days absent:       ", sum(ds0$absence_days_total >= 1L, na.rm = TRUE), "\n")

# ---- inspect-data-1 ----------------------------------------------------------
cat("\n📋 DS0 Structure (cchs_employed):\n")
ds0 |> dplyr::glimpse()

# ---- inspect-data-2 ----------------------------------------------------------
cat("\n📋 Key Variables Summary:\n")
ds0 |>
  dplyr::select(absence_days_total, abs_chronic_days, sex_label, age_group_3, survey_cycle_label) |>
  summary() |>
  print()

# ---- g1 ----------------------------------------------------------------------
# Overview: how many employed people had ANY absence days vs. none?
# Purpose: quick orientation — scale of the absence problem
abs_share <- ds0 |>
  dplyr::filter(!is.na(absence_days_total)) |>
  dplyr::mutate(
    absence_group = dplyr::if_else(absence_days_total == 0L,
                                   "No absence (0 days)",
                                   "Any absence (1+ days)")
  ) |>
  dplyr::count(absence_group) |>
  dplyr::mutate(pct = n / sum(n) * 100)

g1_absence_overview <- abs_share |>
  ggplot(aes(x = absence_group, y = n, fill = absence_group)) +
  geom_col(alpha = 0.85, width = 0.55) +
  geom_text(aes(label = paste0(format(n, big.mark = ","), "\n(", round(pct, 1), "%)"),
                vjust = -0.35), size = 3.8) +
  scale_fill_manual(values = c("No absence (0 days)" = "steelblue",
                               "Any absence (1+ days)" = "firebrick")) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.12))) +
  labs(
    title    = "Work Absence Among Employed Canadians",
    subtitle = "Original data (ds0 = cchs_employed) — CCHS 2010-11 & 2013-14 pooled",
    x        = NULL,
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS cycles 2010-2011 and 2013-2014"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(paste0(prints_folder, "g1_absence_overview.png"),
       g1_absence_overview, width = 8.5, height = 5.5, dpi = 300)
print(g1_absence_overview)

# ---- g2-data-prep ------------------------------------------------------------
# Prepare data for the g2 family: "How are absence days distributed?"
# Conceptual anchor: absence day distribution among employed respondents.
#
# Strategy:
#   - Bin absence_days_total into interpretable ranges
#   - Exclude NA (unreported) for display; show count separately in subtitle
#   - Preserve 0 as its own category (the majority)

n_na <- sum(is.na(ds0$absence_days_total))

bin_breaks <- c(-Inf, 0, 3, 7, 14, 30, 90, Inf)
bin_labels <- c("0 days", "1–3 days", "4–7 days", "8–14 days",
                "15–30 days", "31–90 days", "91+ days")

g2_data <- ds0 |>
  dplyr::filter(!is.na(absence_days_total)) |>
  dplyr::mutate(
    absence_bin = cut(absence_days_total,
                      breaks = bin_breaks,
                      labels = bin_labels,
                      right  = TRUE,
                      include.lowest = TRUE)
  ) |>
  dplyr::count(absence_bin, name = "n_people") |>
  dplyr::mutate(
    pct = n_people / sum(n_people) * 100,
    is_zero = absence_bin == "0 days"
  )

message("📊 g2_data prepared: ", nrow(g2_data), " absence-day bins | ",
        n_na, " NAs excluded from display")

# ---- g2 ----------------------------------------------------------------------
# Full distribution: number of people per absence-day bin (all bins including 0)
g2_absence_dist <- g2_data |>
  ggplot(aes(x = absence_bin, y = n_people, fill = is_zero)) +
  geom_col(alpha = 0.85) +
  geom_text(aes(label = paste0(format(n_people, big.mark = ","),
                               "\n(", round(pct, 1), "%)"),
                vjust = -0.3), size = 3.2) +
  scale_fill_manual(values = c("TRUE" = "steelblue", "FALSE" = "firebrick"),
                    guide = "none") +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.14))) +
  labs(
    title    = "Distribution of Work Absence Days",
    subtitle = paste0("g2_data — employed respondents by absence-day band\n",
                      "(NAs excluded from display: n = ", n_na, ")"),
    x        = "Absence days (binned)",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal()

ggsave(paste0(prints_folder, "g2_absence_distribution.png"),
       g2_absence_dist, width = 8.5, height = 5.5, dpi = 300)
print(g2_absence_dist)

# ---- g21 ---------------------------------------------------------------------
# Family member: zoom into the 1+ days group — same g2_data, zero bin removed.
# Purpose: reveal the within-absent distribution without the dominant zero bar.
g21_absent_only <- g2_data |>
  dplyr::filter(!is_zero) |>
  ggplot(aes(x = absence_bin, y = n_people)) +
  geom_col(fill = "firebrick", alpha = 0.85) +
  geom_text(aes(label = paste0(format(n_people, big.mark = ","),
                               "\n(", round(pct, 1), "% of all)")),
            vjust = -0.3, size = 3.4) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.14))) +
  labs(
    title    = "Absence Day Distribution — Among Those With Any Absence",
    subtitle = "Same g2_data, zero-day group excluded to reveal within-absent pattern",
    x        = "Absence days (binned)",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal()

ggsave(paste0(prints_folder, "g21_absent_only_distribution.png"),
       g21_absent_only, width = 8.5, height = 5.5, dpi = 300)
print(g21_absent_only)

# nolint end
