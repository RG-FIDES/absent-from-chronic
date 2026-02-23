# nolint start
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

message("Data loaded:")
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
cat("Data Overview:\n")
cat("  - ds0 (cchs_employed):", format(nrow(ds0), big.mark = ","), "rows x", ncol(ds0), "cols\n")
cat("  - NA absence_days_total:", sum(is.na(ds0$absence_days_total)), "\n")
cat("  - 0 days absent:        ", sum(ds0$absence_days_total == 0L, na.rm = TRUE), "\n")
cat("  - 1+ days absent:       ", sum(ds0$absence_days_total >= 1L, na.rm = TRUE), "\n")

# ---- inspect-data-1 ----------------------------------------------------------
cat("\nDS0 Structure (cchs_employed):\n")
ds0 |> dplyr::glimpse()

# ---- inspect-data-2 ----------------------------------------------------------
cat("\nKey Variables Summary:\n")
ds0 |>
  dplyr::select(absence_days_total, abs_chronic_days, sex_label, age_group_3, survey_cycle_label) |>
  summary() |>
  print()

# ---- tweak-data-1 ------------------------------------------------------------
# ds1: analysis-ready subset — respondents with 1+ reported absence days.
# Excludes: NAs (absence not reported) and 0-day respondents (no absence event).
# ds1 is the working dataset for all g1-family graphs and downstream analysis.

n_excluded_na   <- sum(is.na(ds0$absence_days_total))
n_excluded_zero <- sum(ds0$absence_days_total == 0L, na.rm = TRUE)

ds1 <- ds0 |>
  dplyr::filter(!is.na(absence_days_total), absence_days_total > 0L)

message("ds1 created: ", format(nrow(ds1), big.mark = ","), " respondents with 1+ absence days")
message("  Excluded NAs:    ", format(n_excluded_na,   big.mark = ","))
message("  Excluded 0-days: ", format(n_excluded_zero, big.mark = ","))
message("  ds0 total:       ", format(nrow(ds0),        big.mark = ","))

# ---- inspect-data-3 ----------------------------------------------------------
cat("\nds1 Overview (1+ absence days only):\n")
cat("  - Rows:   ", format(nrow(ds1), big.mark = ","), "\n")
cat("  - Median absence_days_total:", median(ds1$absence_days_total), "\n")
cat("  - Mean   absence_days_total:", round(mean(ds1$absence_days_total), 1), "\n")
cat("  - Min / Max:                ", min(ds1$absence_days_total),
    "/", max(ds1$absence_days_total), "\n")

# ---- g1-data-prep ------------------------------------------------------------
# Aggregate ds1: one row per unique absence_days_total value with respondent count.
# ds1 already excludes NAs and 0-day respondents — no further filtering needed here.
# Median and mean computed from the raw ds1 vector for use as reference lines.

g1_data   <- ds1 |>
  dplyr::count(absence_days_total, name = "n_people")

g1_median <- median(ds1$absence_days_total)
g1_mean   <- round(mean(ds1$absence_days_total), 1)

message("g1_data prepared: ", nrow(g1_data), " unique day values")
message("  Median: ", g1_median, " days | Mean: ", g1_mean, " days")

# ---- analytic-absence-ratio --------------------------------------------------
# Compute the share of employed respondents reporting zero absence days vs. 1+.
# Purpose: context for the reader — how common is any absence at all?
# Uses ds0 totals computed in tweak-data-1 (n_excluded_na, n_excluded_zero, ds1).

n_total_reported <- nrow(ds0) - n_excluded_na   # answered the question
pct_zero         <- round(n_excluded_zero / n_total_reported * 100, 1)
pct_one_plus     <- round(nrow(ds1)       / n_total_reported * 100, 1)

absence_ratio_tbl <- dplyr::tibble(
  group              = c("No absence (0 days)", "Any absence (1+ days)", "Not reported (NA)"),
  n                  = c(n_excluded_zero, nrow(ds1), n_excluded_na),
  pct_of_respondents = c(pct_zero, pct_one_plus, NA_real_)
)

message("Absence ratio among employed Canadians who answered:")
print(absence_ratio_tbl)
message(pct_zero, "% reported no absence days vs. ",
        pct_one_plus, "% with 1+ days.")

# ---- g1-scatter --------------------------------------------------------------
# Scatter: x = absence_days_total (discrete day count), y = number of people.
# X-axis zoomed to 1–40 via coord_cartesian; tail clipped but not dropped.
# Breaks every 5 days for finer resolution. Labelled boxes mark median and mean.

n_over_40 <- sum(ds1$absence_days_total > 40L)

g1_scatter <- g1_data |>
  ggplot(aes(x = absence_days_total, y = n_people)) +
  geom_point(alpha = 0.65, size = 1.8, colour = "steelblue") +
  geom_vline(xintercept = g1_median, colour = "firebrick",  linetype = "dashed", linewidth = 0.8) +
  geom_vline(xintercept = g1_mean,   colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  annotate("label",
           x = g1_median, y = Inf,
           label    = paste0("Median: ", g1_median, " days"),
           colour   = "firebrick", fill = "white", label.size = 0.3,
           hjust    = -0.05, vjust = 1.4, size = 3.4, fontface = "bold") +
  annotate("label",
           x = g1_mean, y = Inf,
           label    = paste0("Mean: ", g1_mean, " days"),
           colour   = "darkorange", fill = "white", label.size = 0.3,
           hjust    = -0.05, vjust = 3.2, size = 3.4, fontface = "bold") +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  coord_cartesian(xlim = c(1, 40)) +
  labs(
    title    = "Absence Days vs. Number of Respondents (1+ days, zoomed to 1–40)",
    subtitle = paste0("Each point = one unique day-value; n = ",
                      format(nrow(ds1), big.mark = ","),
                      " respondents",
                      ifelse(n_over_40 > 0,
                             paste0(" (", n_over_40, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal()

ggsave(paste0(prints_folder, "g1_scatter.png"),
       g1_scatter, width = 8.5, height = 5.5, dpi = 300)
print(g1_scatter)

# ---- g1-hist -----------------------------------------------------------------
# Histogram of absence_days_total from ds1 (1+ days, no NAs, no 0s).
# X-axis zoomed to 1–40 via coord_cartesian; tail data retained in bins.
# Breaks every 5 days. Labelled boxes mark median and mean.

g1_hist <- ds1 |>
  ggplot(aes(x = absence_days_total)) +
  geom_histogram(binwidth = 5, fill = "steelblue", colour = "white", alpha = 0.85) +
  geom_vline(xintercept = g1_median, colour = "firebrick",  linetype = "dashed", linewidth = 0.8) +
  geom_vline(xintercept = g1_mean,   colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  annotate("label",
           x = g1_median, y = Inf,
           label    = paste0("Median: ", g1_median, " days"),
           colour   = "firebrick", fill = "white", label.size = 0.3,
           hjust    = -0.05, vjust = 1.4, size = 3.4, fontface = "bold") +
  annotate("label",
           x = g1_mean, y = Inf,
           label    = paste0("Mean: ", g1_mean, " days"),
           colour   = "darkorange", fill = "white", label.size = 0.3,
           hjust    = -0.05, vjust = 3.2, size = 3.4, fontface = "bold") +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  coord_cartesian(xlim = c(1, 40)) +
  labs(
    title    = "Distribution of Work Absence Days — 1+ Days Only (zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds1), big.mark = ","), " respondents",
                      ifelse(n_over_40 > 0,
                             paste0(" (", n_over_40, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal()

ggsave(paste0(prints_folder, "g1_hist.png"),
       g1_hist, width = 8.5, height = 5.5, dpi = 300)
print(g1_hist)

# ---- g2-data-prep ------------------------------------------------------------
# Prepare per-sex statistics for g2 reference lines.
# g2 family explores whether the absence-day distribution differs by sex.
# ds1 is the source — same filtered population as g1.

g2_stats <- ds1 |>
  dplyr::group_by(sex_label) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g2 <- sum(ds1$absence_days_total > 40L)

message("g2_stats (per sex):")
print(g2_stats)

# ---- analytic-sex-ratio ------------------------------------------------------
# Ratio of 0-absence vs. 1+ absence respondents broken down by sex.
# Uses ds0 (all who answered) — not ds1 — so the 0-day group is retained.
# Purpose: show that the majority pattern (most miss no days) holds within each sex,
# and whether the split differs between sexes.

sex_ratio_tbl <- ds0 |>
  dplyr::filter(!is.na(absence_days_total)) |>
  dplyr::mutate(
    absence_group = dplyr::if_else(absence_days_total == 0L,
                                   "No absence (0 days)", "Any absence (1+ days)")
  ) |>
  dplyr::count(sex_label, absence_group) |>
  dplyr::group_by(sex_label) |>
  dplyr::mutate(
    total_in_sex = sum(n),
    pct          = round(n / total_in_sex * 100, 1)
  ) |>
  dplyr::ungroup() |>
  dplyr::arrange(sex_label, dplyr::desc(absence_group))

message("Sex-specific absence ratio (0-day vs. 1+ days):")
print(sex_ratio_tbl)

# ---- g2-hist-sex -------------------------------------------------------------
# Two-panel histogram (faceted by sex_label): 5-day bins, zoomed to 1–40.
# Each panel carries its own median (dashed red) and mean (dotted orange) lines.

g2_hist_sex <- ds1 |>
  ggplot(aes(x = absence_days_total, fill = sex_label)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g2_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g2_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g2_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g2_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_manual(values = c("Male" = "steelblue", "Female" = "tomato"),
                    guide  = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ sex_label, ncol = 2) +
  labs(
    title    = "Absence Day Distribution by Sex (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds1), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g2 > 0,
                             paste0(" (", n_over_40_g2, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 12, face = "bold"))

ggsave(paste0(prints_folder, "g2_hist_sex.png"),
       g2_hist_sex, width = 11, height = 5.5, dpi = 300)
print(g2_hist_sex)

# ---- g3-data-prep ------------------------------------------------------------
# Prepare per-age-group statistics from ds1.
# g3 family explores whether absence-day distribution differs by age group.
# g3_stats is saved to data-local for downstream reference.

g3_stats <- ds1 |>
  dplyr::group_by(age_group_3) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g3 <- sum(ds1$absence_days_total > 40L)

message("g3_stats (per age group):")
print(g3_stats)

write.csv(g3_stats,
          file      = paste0(local_data, "g3_stats_age.csv"),
          row.names = FALSE)
message("g3_stats saved to: ", local_data, "g3_stats_age.csv")

# ---- g3-hist-age -------------------------------------------------------------
# One panel per age_group_3 (ncol = 3): same 5-day bins and 1–40 zoom as g1/g2.
# Per-group median (dashed red) and mean (dotted orange) labelled in each panel.
# Panels use distinct fill colours from Set2; legend suppressed (labels in strips).

g3_hist_age <- ds1 |>
  ggplot(aes(x = absence_days_total, fill = age_group_3)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g3_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g3_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g3_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 3.0, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g3_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 3.0, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_brewer(palette = "Set2", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ age_group_3, ncol = 3) +
  labs(
    title    = "Absence Day Distribution by Age Group (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds1), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g3 > 0,
                             paste0(" (", n_over_40_g3, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 11, face = "bold"))

ggsave(paste0(prints_folder, "g3_hist_age.png"),
       g3_hist_age, width = 13, height = 5.5, dpi = 300)
print(g3_hist_age)

# ---- g4-data-prep ------------------------------------------------------------
# g4 family: g1 scatter + histogram replicated, split by survey_cycle_label.
# Purpose: check whether the absence-day distribution differs across CCHS cycles.
# g4_data  — one row per (cycle × unique day-value) for the scatter.
# g4_stats — one row per cycle with median, mean, n for vline labels.

g4_data <- ds1 |>
  dplyr::count(survey_cycle_label, absence_days_total, name = "n_people")

g4_stats <- ds1 |>
  dplyr::group_by(survey_cycle_label) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g4 <- sum(ds1$absence_days_total > 40L)

message("g4_stats (per survey cycle):")
print(g4_stats)

# ---- g4-scatter-cycle --------------------------------------------------------
# Scatter split by survey_cycle_label: each panel mirrors g1-scatter.
# Per-cycle median (dashed red) and mean (dotted orange) drawn from g4_stats.

g4_scatter_cycle <- g4_data |>
  ggplot(aes(x = absence_days_total, y = n_people, colour = survey_cycle_label)) +
  geom_point(alpha = 0.65, size = 1.8) +
  geom_vline(data = g4_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g4_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g4_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g4_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_colour_brewer(palette = "Set1", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ survey_cycle_label, ncol = 2) +
  labs(
    title    = "Absence Days vs. Respondents by Survey Cycle (1+ days, zoomed to 1–40)",
    subtitle = paste0("Each point = one unique day-value per cycle; n = ",
                      format(nrow(ds1), big.mark = ","),
                      " respondents",
                      ifelse(n_over_40_g4 > 0,
                             paste0(" (", n_over_40_g4, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 12, face = "bold"))

ggsave(paste0(prints_folder, "g4_scatter_cycle.png"),
       g4_scatter_cycle, width = 11, height = 5.5, dpi = 300)
print(g4_scatter_cycle)

# ---- g4-hist-cycle -----------------------------------------------------------
# Histogram split by survey_cycle_label: each panel mirrors g1-hist.
# Same 5-day bins and 1–40 zoom; per-cycle median and mean from g4_stats.

g4_hist_cycle <- ds1 |>
  ggplot(aes(x = absence_days_total, fill = survey_cycle_label)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g4_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g4_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g4_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g4_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 3.2, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_brewer(palette = "Set1", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ survey_cycle_label, ncol = 2) +
  labs(
    title    = "Absence Day Distribution by Survey Cycle (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds1), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g4 > 0,
                             paste0(" (", n_over_40_g4, " with >40 days outside view)"),
                             ""),
                      " | 0-day and NA excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 12, face = "bold"))

ggsave(paste0(prints_folder, "g4_hist_cycle.png"),
       g4_hist_cycle, width = 11, height = 5.5, dpi = 300)
print(g4_hist_cycle)

# ---- g5-data-prep ------------------------------------------------------------
# g5 family: absence-day distribution split by education_level.
# ds5: ds1 with NA education_level respondents removed.

ds5 <- ds1 |> dplyr::filter(!is.na(education_level))
n_excluded_edu_na <- nrow(ds1) - nrow(ds5)

g5_stats <- ds5 |>
  dplyr::group_by(education_level) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g5 <- sum(ds5$absence_days_total > 40L)

message("ds5: ", format(nrow(ds5), big.mark = ","),
        " respondents (excluded ", n_excluded_edu_na, " NA education_level)")
message("g5_stats (per education level):")
print(g5_stats)

# ---- g5-hist-edu -------------------------------------------------------------
# One panel per education_level; same 5-day bins and 1–40 zoom as prior families.
# Per-group median (dashed red) and mean (dotted orange) labelled in each panel.

g5_hist_edu <- ds5 |>
  ggplot(aes(x = absence_days_total, fill = education_level)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g5_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g5_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g5_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g5_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_brewer(palette = "Set3", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ education_level, ncol = 3) +
  labs(
    title    = "Absence Day Distribution by Education Level (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds5), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g5 > 0,
                             paste0(" (", n_over_40_g5, " with >40 days outside view)"),
                             ""),
                      " | 0-day, NA absence, and NA education excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 10, face = "bold"))

ggsave(paste0(prints_folder, "g5_hist_edu.png"),
       g5_hist_edu, width = 13, height = 6.5, dpi = 300)
print(g5_hist_edu)

# ---- g6-data-prep ------------------------------------------------------------
# g6 family: absence-day distribution split by marital_status_label.
# ds6: ds1 with NA marital_status_label respondents removed.

ds6 <- ds1 |> dplyr::filter(!is.na(marital_status_label))
n_excluded_marital_na <- nrow(ds1) - nrow(ds6)

g6_stats <- ds6 |>
  dplyr::group_by(marital_status_label) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g6 <- sum(ds6$absence_days_total > 40L)

message("ds6: ", format(nrow(ds6), big.mark = ","),
        " respondents (excluded ", n_excluded_marital_na, " NA marital_status_label)")
message("g6_stats (per marital status):")
print(g6_stats)

# ---- g6-hist-marital ---------------------------------------------------------
# One panel per marital_status_label; same 5-day bins and 1–40 zoom as prior families.
# Per-group median (dashed red) and mean (dotted orange) labelled in each panel.

g6_hist_marital <- ds6 |>
  ggplot(aes(x = absence_days_total, fill = marital_status_label)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g6_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g6_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g6_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g6_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_brewer(palette = "Paired", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ marital_status_label, ncol = 3) +
  labs(
    title    = "Absence Day Distribution by Marital Status (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds6), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g6 > 0,
                             paste0(" (", n_over_40_g6, " with >40 days outside view)"),
                             ""),
                      " | 0-day, NA absence, and NA marital status excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 10, face = "bold"))

ggsave(paste0(prints_folder, "g6_hist_marital.png"),
       g6_hist_marital, width = 13, height = 6.5, dpi = 300)
print(g6_hist_marital)

# ---- g7-data-prep ------------------------------------------------------------
# g7 family: absence-day distribution split by immigration_status_label.
# ds7: ds1 with NA immigration_status_label respondents removed.

ds7 <- ds1 |> dplyr::filter(!is.na(immigration_status_label))
n_excluded_immig_na <- nrow(ds1) - nrow(ds7)

g7_stats <- ds7 |>
  dplyr::group_by(immigration_status_label) |>
  dplyr::summarise(
    median_days = median(absence_days_total),
    mean_days   = round(mean(absence_days_total), 1),
    n_people    = dplyr::n(),
    .groups     = "drop"
  )

n_over_40_g7 <- sum(ds7$absence_days_total > 40L)

message("ds7: ", format(nrow(ds7), big.mark = ","),
        " respondents (excluded ", n_excluded_immig_na, " NA immigration_status_label)")
message("g7_stats (per immigration status):")
print(g7_stats)

# ---- g7-hist-immigration -----------------------------------------------------
# One panel per immigration_status_label; same 5-day bins and 1–40 zoom as prior families.
# Per-group median (dashed red) and mean (dotted orange) labelled in each panel.

g7_hist_immigration <- ds7 |>
  ggplot(aes(x = absence_days_total, fill = immigration_status_label)) +
  geom_histogram(binwidth = 5, colour = "white", alpha = 0.85) +
  geom_vline(data = g7_stats,
             aes(xintercept = median_days),
             colour = "firebrick", linetype = "dashed", linewidth = 0.8) +
  geom_vline(data = g7_stats,
             aes(xintercept = mean_days),
             colour = "darkorange", linetype = "dotted", linewidth = 0.8) +
  geom_label(data = g7_stats,
             aes(x = median_days, y = Inf,
                 label = paste0("Median: ", median_days, " days")),
             colour = "firebrick", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 1.4, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  geom_label(data = g7_stats,
             aes(x = mean_days, y = Inf,
                 label = paste0("Mean: ", mean_days, " days")),
             colour = "darkorange", fill = "white", label.size = 0.3,
             hjust = -0.05, vjust = 3.2, size = 2.9, fontface = "bold",
             inherit.aes = FALSE) +
  scale_x_continuous(breaks = c(1, seq(5, 40, by = 5)), labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  scale_fill_brewer(palette = "Dark2", guide = "none") +
  coord_cartesian(xlim = c(1, 40)) +
  facet_wrap(~ immigration_status_label, ncol = 3) +
  labs(
    title    = "Absence Day Distribution by Immigration Status (1+ days, zoomed to 1–40)",
    subtitle = paste0("n = ", format(nrow(ds7), big.mark = ","),
                      " respondents | 5-day bins",
                      ifelse(n_over_40_g7 > 0,
                             paste0(" (", n_over_40_g7, " with >40 days outside view)"),
                             ""),
                      " | 0-day, NA absence, and NA immigration status excluded"),
    x        = "Total absence days reported",
    y        = "Number of respondents",
    caption  = "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014"
  ) +
  theme_minimal() +
  theme(strip.text = element_text(size = 10, face = "bold"))

ggsave(paste0(prints_folder, "g7_hist_immigration.png"),
       g7_hist_immigration, width = 13, height = 6.5, dpi = 300)
print(g7_hist_immigration)

# nolint end
