# nolint start
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
# EDA-5: LOP Component Decomposition — Sections 4.1 and 4.2
# Mode: EDA (explore with open mind)
rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console

# Guard: ensure working directory is the project root (where flow.R lives).
# VS Code's R extension may launch scripts from the file's own directory.
if (!file.exists("flow.R")) {
  candidate <- getwd()
  while (!file.exists(file.path(candidate, "flow.R")) &&
         candidate != dirname(candidate)) {
    candidate <- dirname(candidate)
  }
  if (file.exists(file.path(candidate, "flow.R"))) {
    setwd(candidate)
  }
}

# verify root location
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(ggplot2)
library(forcats)
library(stringr)
library(dplyr)
library(tidyr)
library(scales)
library(fs)
requireNamespace("arrow")

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
    message("httpgd started. Configure VS Code R extension to use it for plots.")
  }, error = function(e) {
    message("httpgd detected but failed to start: ", conditionMessage(e))
  })
} else {
  message("httpgd not installed. Install with: install.packages('httpgd')")
}

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")
base::source("./scripts/operational-functions.R")
if (file.exists("./scripts/graphing/graph-presets.R")) {
  base::source("./scripts/graphing/graph-presets.R")
}

# ---- declare-globals ---------------------------------------------------------
local_root    <- "./analysis/eda-5/"
local_data    <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")
data_private_derived <- "./data-private/derived/eda-5/"

if (!fs::dir_exists(local_data))           fs::dir_create(local_data)
if (!fs::dir_exists(prints_folder))        fs::dir_create(prints_folder)
if (!fs::dir_exists(data_private_derived)) fs::dir_create(data_private_derived)

path_cchs2_parquet  <- "./data-private/derived/cchs-2-tables"
path_analytical_pq  <- file.path(path_cchs2_parquet, "cchs_analytic.parquet")
weight_col          <- "wts_m_pooled"

# LOP component columns and their human-readable labels
lop_components <- c(
  "lopg040" = "Chronic condition",
  "lopg070" = "Injury",
  "lopg082" = "Cold",
  "lopg083" = "Flu / influenza",
  "lopg084" = "Gastroenteritis",
  "lopg085" = "Respiratory infection",
  "lopg086" = "Other infectious disease",
  "lopg100" = "Other physical / mental health"
)

# ---- declare-functions -------------------------------------------------------
# No analysis-specific helpers required at this stage.

# ---- load-data ---------------------------------------------------------------
if (!file.exists(path_analytical_pq)) {
  stop("Missing required file: ", path_analytical_pq, call. = FALSE)
}

ds0 <- arrow::read_parquet(path_analytical_pq)

required_cols <- c(
  weight_col, "days_absent_total", "days_absent_chronic",
  "cchs_cycle", "cchs_cycle_f",
  names(lop_components)
)
missing_required <- setdiff(required_cols, names(ds0))
if (length(missing_required) > 0) {
  stop("Missing required columns in cchs_analytic.parquet: ",
       paste(missing_required, collapse = ", "), call. = FALSE)
}

cat(sprintf("Loaded analytical data: %s rows, %s columns\n",
            format(nrow(ds0), big.mark = ","),
            format(ncol(ds0), big.mark = ",")))

# ---- data-context-tables -----------------------------------------------------
data_context_tables <- tibble::tibble(
  source_table = "cchs_analytic.parquet",
  location     = path_analytical_pq,
  rows         = nrow(ds0),
  columns      = ncol(ds0),
  usage        = paste(
    "All 8 raw LOP component columns + derived days_absent_total,",
    "days_absent_chronic, and pooled survey weight wts_m_pooled"
  )
)
print(data_context_tables)

# ---- data-context-person -----------------------------------------------------
# A respondent with activity on at least 3 LOP components — shows the key columns
data_context_person <- ds0 %>%
  select(
    cchs_cycle_f, !!weight_col,
    days_absent_total, days_absent_chronic,
    all_of(names(lop_components))
  ) %>%
  filter(
    rowSums(
      select(., all_of(names(lop_components))) > 0,
      na.rm = TRUE
    ) >= 3
  ) %>%
  slice_head(n = 2)
print(data_context_person)

# ---- data-context-distributions ----------------------------------------------
# Non-missing counts, zero counts, and raw prevalence per LOP component
data_context_distributions <- ds0 %>%
  summarise(
    across(
      all_of(names(lop_components)),
      list(
        n_nonmissing = ~ sum(!is.na(.x)),
        n_zero       = ~ sum(.x == 0,  na.rm = TRUE),
        n_positive   = ~ sum(.x > 0,   na.rm = TRUE),
        pct_positive = ~ mean(.x > 0,  na.rm = TRUE) * 100
      )
    )
  ) %>%
  tidyr::pivot_longer(
    cols         = everything(),
    names_to     = c("column", ".value"),
    names_pattern = "^(.+)_(n_nonmissing|n_zero|n_positive|pct_positive)$"
  ) %>%
  mutate(reason_label = lop_components[column])
print(data_context_distributions)

# ---- tweak-data-0 ------------------------------------------------------------
# Long-form LOP component dataset — shared ancestor for G1, G2, G3, G4, G6 families

ds_lop_long <- ds0 %>%
  select(
    cchs_cycle, cchs_cycle_f, !!weight_col,
    days_absent_total, days_absent_chronic,
    all_of(names(lop_components))
  ) %>%
  tidyr::pivot_longer(
    cols      = all_of(names(lop_components)),
    names_to  = "lop_col",
    values_to = "days_reason"
  ) %>%
  mutate(
    reason_label = lop_components[lop_col],
    reason_label = factor(reason_label, levels = lop_components),
    has_days     = !is.na(days_reason) & days_reason > 0
  )


# =============================================================================
# G0 FAMILY — Outcome Distribution Orientation
# Framing question: How does absence distribute across the analytical sample?
# g0  : zero vs non-zero split (horizontal stacked bar)
# g01 : histogram of total missed days among the ≥1-day group, coloured by day range
# g02 : day-range breakdown stacked bar for the ≥1-day group
# =============================================================================

# ---- g0-data-prep ------------------------------------------------------------
g0_data <- ds0 %>%
  mutate(
    absent_group = dplyr::if_else(
      !is.na(days_absent_total) & days_absent_total >= 1,
      "At least one missed day",
      "No missed days (zero)"
    ),
    absent_group = factor(
      absent_group,
      levels = c("No missed days (zero)", "At least one missed day")
    )
  ) %>%
  group_by(absent_group) %>%
  summarise(
    n_people  = n(),
    wt_people = sum(.data[[weight_col]], na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  mutate(
    pct_n  = n_people  / sum(n_people)  * 100,
    pct_wt = wt_people / sum(wt_people) * 100
  )

# ---- g0 ----------------------------------------------------------------------
# Horizontal stacked bar: zero vs ≥1 absent day, unweighted n and weighted %

g0_labels <- g0_data %>%
  mutate(
    bar_label = sprintf("%s\nn = %s  (%.1f%%)",
                        absent_group,
                        scales::comma(n_people),
                        pct_n)
  )

g0_lop_zero_vs_nonzero <- g0_data %>%
  ggplot(aes(x = pct_wt, y = "Analytical sample", fill = absent_group)) +
  geom_col(width = 1.0, alpha = 0.88) +
  geom_text(
    data      = g0_labels,
    aes(
      x     = pct_wt,
      label = sprintf("n = %s\n%.1f%%", scales::comma(n_people), pct_n)
    ),
    position   = position_stack(vjust = 0.5),
    size       = 3.4,
    colour     = "white",
    fontface   = "bold",
    lineheight = 1.1
  ) +
  scale_x_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(
    values = c(
      "No missed days (zero)"   = "#4575b4",
      "At least one missed day" = "#d73027"
    )
  ) +
  labs(
    title    = "G0 (\u00a74.2): Zero vs non-zero absenteeism in the analytical sample",
    subtitle = sprintf("Total analytical sample: n = %s respondents",
                       scales::comma(sum(g0_data$n_people))),
    x        = "Weighted share of respondents (%)",
    y        = NULL,
    fill     = NULL,
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    panel.grid.major.y = element_blank(),
    legend.position    = "bottom"
  )

ggsave(paste0(prints_folder, "g0_lop_zero_vs_nonzero.png"),
       g0_lop_zero_vs_nonzero, width = 10, height = 3, dpi = 300)
print(g0_lop_zero_vs_nonzero)

# ---- g01-data-prep -----------------------------------------------------------
# Shared setup for g01 and g02: restrict to ≥1-day group; assign day-range category

day_range_levels  <- c("1 day", "2 days", "3 days", "4 days", "5 days",
                       "6\u201310 days", "11\u201315 days", "16\u201330 days", "31+ days")
day_range_colours <- c(
  "1 day"           = "#f7941d",
  "2 days"          = "#e8601c",
  "3 days"          = "#cc3311",
  "4 days"          = "#aa1133",
  "5 days"          = "#880044",
  "6\u201310 days"  = "#6a0177",
  "11\u201315 days" = "#49006a",
  "16\u201330 days" = "#2d004b",
  "31+ days"        = "#0d0014"
)

ds_nonzero <- ds0 %>%
  filter(!is.na(days_absent_total), days_absent_total >= 1) %>%
  mutate(
    day_range = dplyr::case_when(
      days_absent_total == 1  ~ "1 day",
      days_absent_total == 2  ~ "2 days",
      days_absent_total == 3  ~ "3 days",
      days_absent_total == 4  ~ "4 days",
      days_absent_total == 5  ~ "5 days",
      days_absent_total <= 10 ~ "6\u201310 days",
      days_absent_total <= 15 ~ "11\u201315 days",
      days_absent_total <= 30 ~ "16\u201330 days",
      TRUE                    ~ "31+ days"
    ),
    day_range = factor(day_range, levels = day_range_levels)
  )

# ---- g01 ---------------------------------------------------------------------
# Frequency histogram: x = total days missed, y = respondents
# Bars coloured by the same day-range palette used in g02

g01_hist_data <- ds_nonzero %>%
  count(days_absent_total, day_range)

g01_lop_days_histogram <- g01_hist_data %>%
  ggplot(aes(x = days_absent_total, y = n, fill = day_range)) +
  geom_col(width = 0.9, alpha = 0.90) +
  geom_col(
    data    = ~ filter(.x, days_absent_total == 1),
    width   = 0.9, colour = "black", fill = NA, alpha = 0.5
  ) +
  scale_x_continuous(
    breaks = c(1, 5, 10, 15, 20, 25, 30, 40, 50, 63),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    labels = scales::label_comma(),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_fill_manual(values = day_range_colours) +
  labs(
    title    = "G01 (\u00a74.2): Frequency distribution of total missed days (respondents with \u22651 day)",
    subtitle = sprintf("n = %s respondents; x-axis capped at observed maximum",
                       scales::comma(nrow(ds_nonzero))),
    x        = "Total days absent (days_absent_total)",
    y        = "Number of respondents",
    fill     = "Day range",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(paste0(prints_folder, "g01_lop_days_histogram.png"),
       g01_lop_days_histogram, width = 10, height = 5, dpi = 300)
print(g01_lop_days_histogram)

# ---- g02-data-prep -----------------------------------------------------------
g02_data <- ds_nonzero %>%
  group_by(day_range) %>%
  summarise(
    n_people  = n(),
    wt_people = sum(.data[[weight_col]], na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  mutate(
    pct_n  = n_people  / sum(n_people)  * 100,
    pct_wt = wt_people / sum(wt_people) * 100
  )

# ---- g02 ---------------------------------------------------------------------
# Horizontal stacked bar: day-range breakdown for the ≥1-day group

g02_lop_day_ranges <- g02_data %>%
  ggplot(aes(x = pct_wt, y = "Respondents with \u22651 day", fill = day_range)) +
  geom_col(width = 1.0, alpha = 0.90) +
  geom_text(
    aes(label = sprintf("%s - %.0f%%",
                        stringr::str_remove(as.character(day_range), " days?$"),
                        pct_n)),
    position   = position_stack(vjust = 0.5),
    angle      = 90,
    size       = 3.0,
    colour     = "white",
    fontface   = "bold",
    lineheight = 1.1
  ) +
  scale_x_continuous(
    labels = scales::label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(values = day_range_colours) +
  labs(
    title    = "G02 (\u00a74.2): Day-range breakdown among respondents with \u22651 missed day",
    subtitle = sprintf("Total: n = %s respondents with at least one missed workday",
                       scales::comma(nrow(ds_nonzero))),
    x        = "Weighted share (%)",
    y        = NULL,
    fill     = "Day range",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    panel.grid.major.y = element_blank(),
    legend.position    = "top",
    legend.box.margin  = margin(0, 0, -12, 0)
  ) +
  guides(fill = guide_legend(nrow = 1, reverse = TRUE))

ggsave(paste0(prints_folder, "g02_lop_day_ranges.png"),
       g02_lop_day_ranges, width = 10, height = 4, dpi = 300)
print(g02_lop_day_ranges)


# =============================================================================
# G1 FAMILY — Prevalence of Each LOP Reason Category
# Framing question: What proportion of workers missed ≥1 workday for each reason?
# g1  : weighted prevalence, ordered horizontal bar
# g11 : prevalence by survey cycle (2010-2011 vs 2013-2014)
# =============================================================================

# ---- g1-data-prep ------------------------------------------------------------
g1_data <- ds_lop_long %>%
  group_by(reason_label) %>%
  summarise(
    n_total        = n(),
    n_positive     = sum(has_days, na.rm = TRUE),
    wt_positive    = sum(.data[[weight_col]][has_days], na.rm = TRUE),
    wt_total       = sum(.data[[weight_col]],           na.rm = TRUE),
    pct_weighted   = wt_positive / wt_total * 100,
    pct_unweighted = n_positive  / n_total  * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(pct_weighted)) %>%
  mutate(reason_label = forcats::fct_reorder(reason_label, pct_weighted))

# ---- g1 ----------------------------------------------------------------------
g1_lop_prevalence <- g1_data %>%
  ggplot(aes(x = pct_weighted, y = reason_label)) +
  geom_col(fill = "#2c7bb6", alpha = 0.85, width = 0.65) +
  geom_text(
    aes(label = sprintf("%.1f%%", pct_weighted)),
    hjust = -0.15,
    size  = 3.2
  ) +
  scale_x_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title    = "G1 (\u00a74.1): Weighted prevalence of each LOP reason category",
    subtitle = "Proportion of analytical-sample respondents reporting \u22651 absent day per reason",
    x        = "Weighted % of respondents with \u22651 day absent",
    y        = NULL,
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample (n = 63,843)"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank())

ggsave(paste0(prints_folder, "g1_lop_prevalence.png"),
       g1_lop_prevalence, width = 8.5, height = 5.5, dpi = 300)
print(g1_lop_prevalence)

# ---- g11 ---------------------------------------------------------------------
# Faceted: prevalence by survey cycle

g1_data_by_cycle <- ds_lop_long %>%
  group_by(reason_label, cchs_cycle_f) %>%
  summarise(
    wt_positive  = sum(.data[[weight_col]][has_days], na.rm = TRUE),
    wt_total     = sum(.data[[weight_col]],           na.rm = TRUE),
    pct_weighted = wt_positive / wt_total * 100,
    .groups = "drop"
  ) %>%
  mutate(
    reason_label = forcats::fct_reorder(reason_label, pct_weighted,
                                         .fun = mean, .desc = FALSE)
  )

g11_lop_prevalence_by_cycle <- g1_data_by_cycle %>%
  ggplot(aes(x = pct_weighted, y = reason_label, fill = cchs_cycle_f)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6, alpha = 0.85) +
  geom_text(
    aes(label = sprintf("%.1f%%", pct_weighted)),
    position = position_dodge(width = 0.7),
    hjust    = -0.1,
    size     = 2.8
  ) +
  scale_x_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.18))
  ) +
  scale_fill_manual(values = c("2010-2011" = "#2c7bb6", "2013-2014" = "#d7191c")) +
  labs(
    title    = "G11 (\u00a74.1): LOP reason prevalence by survey cycle",
    subtitle = "Weighted % of respondents with \u22651 absent day per reason \u2014 2010\u201311 vs 2013\u201314",
    x        = "Weighted % of respondents",
    y        = NULL,
    fill     = "Cycle"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position    = "bottom"
  )

ggsave(paste0(prints_folder, "g11_lop_prevalence_by_cycle.png"),
       g11_lop_prevalence_by_cycle, width = 8.5, height = 5.5, dpi = 300)
print(g11_lop_prevalence_by_cycle)


# =============================================================================
# G2 FAMILY — Component Contribution to the Total Outcome
# Framing question: How much does each LOP reason contribute to the
#   weighted mean of days_absent_total?
# g2  : dot-strip lollipop — absolute weighted mean + % share label
# g21 : stacked bar — relative share of each component in the component sum
# =============================================================================

# ---- g2-data-prep ------------------------------------------------------------
g2_data <- ds_lop_long %>%
  group_by(reason_label) %>%
  summarise(
    wt_mean_days = sum(.data[[weight_col]] * days_reason, na.rm = TRUE) /
      sum(.data[[weight_col]], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(wt_mean_days)) %>%
  mutate(
    reason_label = forcats::fct_reorder(reason_label, wt_mean_days),
    pct_of_total = wt_mean_days / sum(wt_mean_days) * 100
  )

# Overall weighted mean of days_absent_total (reference line)
total_wt_mean <- sum(ds0[[weight_col]] * ds0$days_absent_total, na.rm = TRUE) /
  sum(ds0[[weight_col]], na.rm = TRUE)

# ---- g2 ----------------------------------------------------------------------
g2_lop_contribution <- g2_data %>%
  ggplot(aes(x = wt_mean_days, y = reason_label)) +
  geom_segment(aes(xend = 0, yend = reason_label),
               colour = "grey70", linewidth = 0.6) +
  geom_point(aes(size = pct_of_total), colour = "#2c7bb6", alpha = 0.9) +
  geom_text(
    aes(label = sprintf("%.2f d  (%.0f%%)", wt_mean_days, pct_of_total)),
    hjust = -0.15,
    size  = 3.1
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.35))) +
  scale_size_continuous(range = c(2, 8), guide = "none") +
  labs(
    title    = "G2 (\u00a74.1): Weighted mean days absent attributed to each LOP reason",
    subtitle = sprintf(
      "Point size \u221d share of total; reference weighted mean (days_absent_total) = %.2f days",
      total_wt_mean
    ),
    x       = "Weighted mean days absent (all respondents, including zeros)",
    y       = NULL,
    caption = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank())

ggsave(paste0(prints_folder, "g2_lop_contribution.png"),
       g2_lop_contribution, width = 8.5, height = 5.5, dpi = 300)
print(g2_lop_contribution)

# ---- g21 ---------------------------------------------------------------------
# Stacked horizontal bar: relative share of each component in the total

# Preserve ordering from g2 (descending wt_mean)
g21_data <- g2_data %>%
  mutate(
    reason_ordered = forcats::fct_reorder(as.character(reason_label),
                                          pct_of_total, .desc = FALSE)
  )

g21_lop_contribution_stacked <- g21_data %>%
  ggplot(aes(x = pct_of_total, y = "Component sum", fill = reason_ordered)) +
  geom_col(width = 0.7, alpha = 0.88) +
  geom_text(
    data = filter(g21_data, pct_of_total > 4),
    aes(
      label = sprintf("%s\n%.0f%%", reason_ordered, pct_of_total)
    ),
    position   = position_stack(vjust = 0.5),
    size       = 2.8,
    colour     = "white",
    fontface   = "bold",
    lineheight = 1.0
  ) +
  scale_x_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_brewer(palette = "Set2", direction = 1) +
  labs(
    title    = "G21 (\u00a74.1): Relative share of each LOP reason in total absent-day burden",
    subtitle = "Weighted mean days per reason as % of the 8-component sum",
    x        = "Share of total absent-day burden (%)",
    y        = NULL,
    fill     = "LOP reason",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    panel.grid.major.y = element_blank(),
    legend.position    = "right"
  )

ggsave(paste0(prints_folder, "g21_lop_contribution_stacked.png"),
       g21_lop_contribution_stacked, width = 10, height = 3.5, dpi = 300)
print(g21_lop_contribution_stacked)


# =============================================================================
# G3 FAMILY — Co-occurrence of Reason Categories
# Framing question: How many reasons does a typical respondent report
#   simultaneously, and which reason pairs most frequently co-occur?
# g3  : bar chart — distribution of reason-count per respondent (0, 1, 2, …)
# g31 : tile heatmap — pairwise co-occurrence rates across 8 reason categories
# =============================================================================

# ---- g3-data-prep ------------------------------------------------------------
# Per-respondent count of reason categories with ≥1 day
g3_count_data <- ds0 %>%
  select(cchs_cycle_f, !!weight_col, all_of(names(lop_components))) %>%
  mutate(
    n_reasons = rowSums(
      across(all_of(names(lop_components)), ~ !is.na(.x) & .x > 0),
      na.rm = TRUE
    )
  )

g3_dist <- g3_count_data %>%
  group_by(n_reasons) %>%
  summarise(
    n_obs = n(),
    wt_n  = sum(.data[[weight_col]], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    pct_obs = n_obs / sum(n_obs) * 100,
    pct_wt  = wt_n  / sum(wt_n)  * 100
  )

# Pairwise co-occurrence matrix (% of respondents positive on both)
lop_cols   <- names(lop_components)
lop_labels <- unname(lop_components)

positive_flags <- ds0 %>%
  select(all_of(lop_cols)) %>%
  mutate(across(everything(), ~ !is.na(.x) & .x > 0))

cooccur_mat <- matrix(
  NA_real_,
  nrow     = length(lop_cols),
  ncol     = length(lop_cols),
  dimnames = list(lop_labels, lop_labels)
)

for (i in seq_along(lop_cols)) {
  for (j in seq_along(lop_cols)) {
    cooccur_mat[i, j] <- mean(
      positive_flags[[lop_cols[i]]] & positive_flags[[lop_cols[j]]],
      na.rm = TRUE
    ) * 100
  }
}

g3_cooccur_data <- as.data.frame(cooccur_mat) %>%
  tibble::rownames_to_column("reason_row") %>%
  tidyr::pivot_longer(-reason_row, names_to = "reason_col",
                      values_to = "pct_cooccur") %>%
  mutate(
    reason_row = factor(reason_row, levels = rev(lop_labels)),
    reason_col = factor(reason_col, levels = lop_labels),
    is_diagonal = reason_row == reason_col
  )

# ---- g3 ----------------------------------------------------------------------
g3_lop_nreasons <- g3_dist %>%
  ggplot(aes(x = factor(n_reasons), y = pct_wt)) +
  geom_col(fill = "#2c7bb6", alpha = 0.85, width = 0.65) +
  geom_text(
    aes(label = sprintf("%.1f%%", pct_wt)),
    vjust = -0.35,
    size  = 3.2
  ) +
  scale_y_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.14))
  ) +
  labs(
    title    = "G3 (\u00a74.1): Number of LOP reason categories reported per respondent",
    subtitle = "Weighted % of respondents by count of reason categories with \u22651 absent day",
    x        = "Number of distinct LOP reason categories reported",
    y        = "Weighted % of respondents",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.x = element_blank())

ggsave(paste0(prints_folder, "g3_lop_nreasons.png"),
       g3_lop_nreasons, width = 8.5, height = 5.5, dpi = 300)
print(g3_lop_nreasons)

# ---- g31 ---------------------------------------------------------------------
# Pairwise co-occurrence heatmap; diagonal = univariate prevalence

g31_lop_cooccurrence <- g3_cooccur_data %>%
  ggplot(aes(x = reason_col, y = reason_row, fill = pct_cooccur)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(
    aes(label = ifelse(pct_cooccur >= 0.3, sprintf("%.1f", pct_cooccur), "")),
    size = 2.8
  ) +
  scale_fill_distiller(
    palette   = "Blues",
    direction = 1,
    name      = "% respondents\n(unweighted)"
  ) +
  labs(
    title    = "G31 (\u00a74.1): Pairwise co-occurrence of LOP reason categories",
    subtitle = "Cell = % of respondents reporting \u22651 day for both reasons; diagonal = univariate prevalence",
    x        = NULL,
    y        = NULL,
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 30, hjust = 1),
    panel.grid  = element_blank()
  )

ggsave(paste0(prints_folder, "g31_lop_cooccurrence.png"),
       g31_lop_cooccurrence, width = 8.5, height = 5.5, dpi = 300)
print(g31_lop_cooccurrence)


# =============================================================================
# G4 FAMILY — Conditional Intensity: Days Produced Per Reason, Among Reporters
# Framing question: Among workers who missed work for a given reason,
#   how many days did that reason typically produce?
# g4  : horizontal bar (weighted mean) + diamond (median) per reason, reporters only
# g41 : distribution of days_absent_total (non-zeros, log y-scale)
# =============================================================================

# ---- g4-data-prep ------------------------------------------------------------
# Restrict to respondents who reported ≥1 day for each specific reason
g4_data <- ds_lop_long %>%
  filter(has_days) %>%
  group_by(reason_label) %>%
  summarise(
    wt_mean_days = sum(.data[[weight_col]] * days_reason, na.rm = TRUE) /
      sum(.data[[weight_col]], na.rm = TRUE),
    mean_days    = mean(days_reason, na.rm = TRUE),
    median_days  = median(days_reason, na.rm = TRUE),
    n_reporters  = n(),
    .groups = "drop"
  ) %>%
  mutate(reason_label = forcats::fct_reorder(reason_label, wt_mean_days))

n_zero_total <- sum(ds0$days_absent_total == 0, na.rm = TRUE)
pct_zero_total <- n_zero_total / nrow(ds0) * 100

g41_data <- ds0 %>%
  filter(!is.na(days_absent_total), days_absent_total >= 1) %>%
  count(days_absent_total, name = "n_respondents")

# ---- g4 ----------------------------------------------------------------------
g4_conditional_intensity <- g4_data %>%
  ggplot(aes(x = wt_mean_days, y = reason_label)) +
  geom_col(fill = "#2c7bb6", alpha = 0.75, width = 0.65) +
  geom_point(aes(x = median_days), colour = "#d73027", size = 3.5, shape = 18) +
  geom_text(
    aes(
      label = sprintf("w.mean = %.1f  med = %.0f  (n = %s)",
                      wt_mean_days, median_days,
                      scales::comma(n_reporters))
    ),
    hjust = -0.04,
    size  = 2.9
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title    = "G4 (\u00a74.2): Conditional intensity \u2014 days absent per reason, reporters only",
    subtitle = "Bar = weighted mean; red diamond = median. Restricted to respondents reporting \u22651 day for that reason.",
    x        = "Days absent (among reporters of that reason)",
    y        = NULL,
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank())

ggsave(paste0(prints_folder, "g4_conditional_intensity.png"),
       g4_conditional_intensity, width = 8.5, height = 5.5, dpi = 300)
print(g4_conditional_intensity)

# ---- g41 ---------------------------------------------------------------------
# Distribution of days_absent_total: non-zeros, log y-scale

g41_total_distribution <- g41_data %>%
  ggplot(aes(x = days_absent_total, y = n_respondents)) +
  geom_col(fill = "#4575b4", alpha = 0.80, width = 0.85) +
  scale_y_log10(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 30, 45, 63)) +
  labs(
    title    = sprintf(
      "G41 (\u00a74.2): Distribution of days_absent_total (non-zeros only, log y-scale)\n%s zeros excluded (%.1f%% of full sample)",
      scales::comma(n_zero_total), pct_zero_total
    ),
    subtitle = "One bar per integer value; log y-axis reveals the heavy right tail",
    x        = "Total absent days (days_absent_total)",
    y        = "Number of respondents (log scale)",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())

ggsave(paste0(prints_folder, "g41_total_distribution.png"),
       g41_total_distribution, width = 8.5, height = 5.5, dpi = 300)
print(g41_total_distribution)


# =============================================================================
# G5 FAMILY — Chronic Condition's Structural Role Among Absent Workers
# Framing question: Among workers who missed at least one day, how central
#   is the chronic-condition component to the total?
# g5  : three-group bar — no chronic / mixed / entirely chronic
# g51 : bubble chart — days_absent_chronic vs days_absent_total (both > 0)
# =============================================================================

# ---- g5-data-prep ------------------------------------------------------------
g5_data <- ds0 %>%
  filter(!is.na(days_absent_total), days_absent_total > 0) %>%
  mutate(
    chr   = ifelse(is.na(days_absent_chronic), 0L, days_absent_chronic),
    group = dplyr::case_when(
      chr == 0                 ~ "No chronic days\n(non-chronic absence only)",
      chr == days_absent_total ~ "Entirely chronic\n(chronic = total)",
      TRUE                     ~ "Mixed\n(some chronic + other reasons)"
    ),
    group = factor(group, levels = c(
      "No chronic days\n(non-chronic absence only)",
      "Mixed\n(some chronic + other reasons)",
      "Entirely chronic\n(chronic = total)"
    ))
  ) %>%
  group_by(group) %>%
  summarise(
    n        = n(),
    wt_n     = sum(.data[[weight_col]], na.rm = TRUE),
    .groups  = "drop"
  ) %>%
  mutate(
    pct_n  = n    / sum(n)    * 100,
    pct_wt = wt_n / sum(wt_n) * 100
  )

n_absent_total <- sum(g5_data$n)

g51_data <- ds0 %>%
  filter(
    !is.na(days_absent_total),    days_absent_total > 0,
    !is.na(days_absent_chronic),  days_absent_chronic > 0
  ) %>%
  count(days_absent_total, days_absent_chronic, name = "n_combo")

# ---- g5 ----------------------------------------------------------------------
g5_chronic_role <- g5_data %>%
  ggplot(aes(x = group, y = pct_wt, fill = group)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_text(
    aes(label = sprintf("%.1f%%\n(n = %s)", pct_wt, scales::comma(n))),
    vjust = -0.3,
    size  = 3.5
  ) +
  scale_y_continuous(
    labels = label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.22))
  ) +
  scale_fill_manual(
    values = c(
      "No chronic days\n(non-chronic absence only)" = "#74add1",
      "Mixed\n(some chronic + other reasons)"        = "#f46d43",
      "Entirely chronic\n(chronic = total)"          = "#d73027"
    ),
    guide = "none"
  ) +
  labs(
    title    = "G5 (\u00a74.2): Role of chronic absence among workers with any absence",
    subtitle = sprintf(
      "Three-group classification among the %s respondents with days_absent_total > 0 (weighted %%)",
      scales::comma(n_absent_total)
    ),
    x        = NULL,
    y        = "Weighted % of absent respondents",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.x = element_blank())

ggsave(paste0(prints_folder, "g5_chronic_role.png"),
       g5_chronic_role, width = 8.5, height = 5.5, dpi = 300)
print(g5_chronic_role)

# ---- g51 ---------------------------------------------------------------------
# Bubble chart: chronic days vs total days, 1:1 reference line

g51_max_axis <- max(g51_data$days_absent_total, g51_data$days_absent_chronic)

g51_chronic_vs_total <- g51_data %>%
  ggplot(aes(x = days_absent_total, y = days_absent_chronic, size = n_combo)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey50", linetype = "dashed",
              linewidth = 0.7) +
  geom_point(alpha = 0.55, colour = "#4575b4") +
  scale_size_continuous(
    name   = "# respondents\nat combination",
    range  = c(1, 12),
    labels = label_comma()
  ) +
  scale_x_continuous(breaks = c(1, 5, 10, 20, 30, 60)) +
  scale_y_continuous(breaks = c(1, 5, 10, 20, 30)) +
  coord_fixed(
    xlim = c(0, g51_max_axis),
    ylim = c(0, g51_max_axis)
  ) +
  annotate(
    "text",
    x      = g51_max_axis * 0.60,
    y      = g51_max_axis * 0.68,
    label  = "chronic = total\n(1:1 line)",
    colour = "grey40",
    size   = 3.2,
    hjust  = 0
  ) +
  labs(
    title    = "G51 (\u00a74.2): Chronic days vs. total days absent \u2014 bubble chart (both > 0)",
    subtitle = "Points on 1:1 line: all absence is chronic. Points below: chronic + other reasons combined.",
    x        = "Total absent days (days_absent_total)",
    y        = "Chronic-condition absent days (days_absent_chronic)",
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11)

ggsave(paste0(prints_folder, "g51_chronic_vs_total.png"),
       g51_chronic_vs_total, width = 7.0, height = 7.0, dpi = 300)
print(g51_chronic_vs_total)


# =============================================================================
# G6 FAMILY — LOP Component Availability (Data Quality Validation)
# Framing question: Are all 8 LOP components complete in the analytical
#   sample, confirming that zeros are preserved and element-wise exclusion
#   upstream eliminated only rows with genuine missingness?
# g6  : 100% stacked bar — zero vs positive per component
# g61 : lollipop — weighted mean raw days per component (population average)
# =============================================================================

# ---- g6-data-prep ------------------------------------------------------------
# Per-component: count of zeros, positives, and missing (should be 0 after exclusion)

g6_long <- ds0 %>%
  select(all_of(names(lop_components)), !!weight_col) %>%
  tidyr::pivot_longer(
    cols      = all_of(names(lop_components)),
    names_to  = "lop_col",
    values_to = "days"
  ) %>%
  mutate(
    reason_label = factor(lop_components[lop_col], levels = lop_components),
    status = dplyr::case_when(
      is.na(days) ~ "Missing (NA)",
      days == 0   ~ "Zero days",
      TRUE        ~ "\u22651 day absent"
    ),
    status = factor(status, levels = c("\u22651 day absent", "Zero days", "Missing (NA)"))
  )

g6_data <- g6_long %>%
  group_by(reason_label, status) %>%
  summarise(
    n    = n(),
    wt_n = sum(.data[[weight_col]], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(reason_label) %>%
  mutate(
    pct_n  = n    / sum(n)    * 100,
    pct_wt = wt_n / sum(wt_n) * 100
  ) %>%
  ungroup() %>%
  # Order reasons by descending % positive
  mutate(
    reason_label = forcats::fct_reorder(
      reason_label,
      ifelse(status == "\u22651 day absent", pct_n, NA_real_),
      .fun  = function(x) max(x, na.rm = TRUE),
      .desc = FALSE
    )
  )

# Weighted mean raw days per component (across all respondents, including zeros)
g61_data <- ds_lop_long %>%
  group_by(reason_label) %>%
  summarise(
    wt_mean_raw = sum(.data[[weight_col]] * days_reason, na.rm = TRUE) /
      sum(.data[[weight_col]], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(reason_label = forcats::fct_reorder(reason_label, wt_mean_raw))

# ---- g6 ----------------------------------------------------------------------
g6_lop_availability <- g6_data %>%
  ggplot(aes(x = pct_n, y = reason_label, fill = status)) +
  geom_col(width = 0.70, alpha = 0.88) +
  geom_text(
    data = filter(g6_data, status == "\u22651 day absent"),
    aes(label = sprintf("%.1f%%", pct_n), x = pct_n / 2),
    colour   = "white",
    fontface = "bold",
    size     = 3.2
  ) +
  scale_x_continuous(
    labels = scales::label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(
    values = c(
      "\u22651 day absent" = "#d73027",
      "Zero days"          = "#4575b4",
      "Missing (NA)"       = "#969696"
    )
  ) +
  labs(
    title    = "G6 (\u00a74.1 data quality): LOP component availability in the analytical sample",
    subtitle = "Zero is preserved as a valid response; 0 missing values confirm 405-row element-wise exclusion was resolved upstream",
    x        = "Share of respondents (%)",
    y        = NULL,
    fill     = NULL,
    caption  = "Source: CCHS analytical sample (n = 63,843); 405 rows with any missing LOP value excluded at Ellis step 4"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position    = "bottom"
  )

ggsave(paste0(prints_folder, "g6_lop_availability.png"),
       g6_lop_availability, width = 8.5, height = 5.5, dpi = 300)
print(g6_lop_availability)

# ---- g61 ---------------------------------------------------------------------
# Lollipop: weighted mean raw days per LOP component (population average)

g61_lop_mean_raw <- g61_data %>%
  ggplot(aes(x = wt_mean_raw, y = reason_label)) +
  geom_segment(aes(xend = 0, yend = reason_label),
               colour = "grey70", linewidth = 0.6) +
  geom_point(colour = "#2c7bb6", size = 3.5, alpha = 0.9) +
  geom_text(
    aes(label = sprintf("%.3f d", wt_mean_raw)),
    hjust = -0.2,
    size  = 3.1
  ) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.30))) +
  labs(
    title    = "G61 (\u00a74.1): Weighted mean raw days per LOP component (population-level average)",
    subtitle = "Numerator includes zeros; shows the unconditional contribution of each reason to population absenteeism",
    x        = "Weighted mean days absent (all respondents, including zeros)",
    y        = NULL,
    caption  = "Source: CCHS 2010\u201311 & 2013\u201314 pooled analytical sample"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank())

ggsave(paste0(prints_folder, "g61_lop_mean_raw.png"),
       g61_lop_mean_raw, width = 8.5, height = 5.5, dpi = 300)
print(g61_lop_mean_raw)

# nolint end
