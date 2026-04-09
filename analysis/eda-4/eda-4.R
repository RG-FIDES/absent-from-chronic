# nolint start
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
rm(list = ls(all.names = TRUE))
cat("\014")
cat("Working directory: ", getwd())

# ---- load-packages -----------------------------------------------------------
library(magrittr)        # pipes
library(dplyr)           # data wrangling
library(tidyr)           # data reshaping
library(ggplot2)         # graphs
library(forcats)         # factors
library(scales)          # formatting
library(stringr)         # strings
library(lubridate)       # dates
library(labelled)        # labels
library(janitor)         # tidy data
library(testit)          # assertions
library(fs)              # file system
library(purrr)           # iteration helpers
library(plotly)          # interactive visualizations
requireNamespace("arrow")
requireNamespace("survey")   # complex survey design
requireNamespace("naniar")   # missing data visualization
requireNamespace("mice")     # missing data diagnostics (Little's MCAR)
requireNamespace("htmlwidgets")
requireNamespace("plotly")

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

# ---- load-sources ----------------------------------------------------------------
base::source("./scripts/common-functions.R")      # project-level utilities
base::source("./scripts/operational-functions.R")  # project-level operations
if (file.exists("./scripts/graphing/graph-presets.R")) {
  base::source("./scripts/graphing/graph-presets.R") # Alberta color palettes
}

# ---- declare-globals ---------------------------------------------------------
local_root <- "./analysis/eda-4/"
local_data <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")
data_private_derived <- "./data-private/derived/eda-4/"

if (!fs::dir_exists(local_data)) fs::dir_create(local_data)
if (!fs::dir_exists(prints_folder)) fs::dir_create(prints_folder)
if (!fs::dir_exists(data_private_derived)) fs::dir_create(data_private_derived)

# Ellis output paths
path_cchs2_parquet <- "./data-private/derived/cchs-2-tables"
path_analytical_pq <- file.path(path_cchs2_parquet, "cchs_analytical.parquet")
path_sampleflow_pq <- file.path(path_cchs2_parquet, "sample_flow.parquet")

# Key variable names
outcome_cols <- c("days_absent_total", "days_absent_chronic")
weight_col <- "wts_m_pooled"
cycle_col <- "cycle_f"

# ---- declare-functions -------------------------------------------------------
base::source(paste0(local_root, "local-functions.R"))

# ---- load-data ---------------------------------------------------------------
# Load Ellis parquet outputs
if (!file.exists(path_analytical_pq)) {
  stop("Missing required file: ", path_analytical_pq, call. = FALSE)
}

ds0 <- arrow::read_parquet(path_analytical_pq)
sample_flow <- if (file.exists(path_sampleflow_pq)) {
  arrow::read_parquet(path_sampleflow_pq)
} else {
  NULL
}

message(sprintf("Loaded analytical data: %s rows, %s columns",
                format(nrow(ds0), big.mark = ","),
                ncol(ds0)))

required_cols <- c("adm_rno", weight_col, cycle_col, outcome_cols)
missing_required <- setdiff(required_cols, names(ds0))
if (length(missing_required) > 0) {
  stop("Missing required columns in cchs_analytical.parquet: ",
       paste(missing_required, collapse = ", "),
       call. = FALSE)
}

survey_design <- survey::svydesign(
  ids = ~1,
  weights = stats::as.formula(paste0("~", weight_col)),
  data = ds0
)

# ---- tweak-data-0 ---------------------------------------------------------------
# General data transformations shared across all analyses

# ---- inspect-data-0 ---------------------------------------------------------
# Basic structure of loaded datasets
data_overview <- tibble::tibble(
  metric = c("n_rows", "n_columns", "n_unique_people", "n_cycles"),
  value = c(
    nrow(ds0),
    ncol(ds0),
    dplyr::n_distinct(ds0$adm_rno),
    dplyr::n_distinct(ds0[[cycle_col]])
  )
)

data_overview

data_context_tables <- tibble::tibble(
  source_table = c("cchs_analytical.parquet", "sample_flow.parquet"),
  location = c(path_analytical_pq, path_sampleflow_pq),
  rows = c(
    nrow(ds0),
    if (!is.null(sample_flow)) nrow(sample_flow) else NA_integer_
  ),
  columns = c(
    ncol(ds0),
    if (!is.null(sample_flow)) ncol(sample_flow) else NA_integer_
  ),
  usage_in_eda4 = c(
    "Core analytical dataset for missingness diagnostics and descriptive statistics.",
    "Sample-flow context and exclusions (if available)."
  )
)

# ---- inspect-data-1 ---------------------------------------------------------
# Grain verification: confirm unit of analysis (person-level, person-wave, etc.)
data_context_grain <- ds0 %>%
  summarise(
    n_rows = n(),
    n_unique_person = n_distinct(adm_rno),
    n_unique_person_cycle = n_distinct(paste(adm_rno, .data[[cycle_col]], sep = "_"))
  ) %>%
  mutate(
    grain_statement = dplyr::if_else(
      n_rows == n_unique_person_cycle,
      "Grain verified: one row per person x cycle",
      "Potential duplicate person x cycle rows detected"
    )
  )

data_context_person <- ds0 %>%
  select(
    adm_rno,
    all_of(cycle_col),
    all_of(weight_col),
    all_of(outcome_cols),
    any_of(c("age_group", "sex", "employment_type", "work_schedule", "education", "income"))
  ) %>%
  arrange(adm_rno) %>%
  slice_head(n = 2)

data_context_distributions <- ds0 %>%
  summarise(
    total_n = n(),
    total_weight = sum(.data[[weight_col]], na.rm = TRUE),
    total_non_missing = sum(!is.na(.data[[outcome_cols[1]]])),
    chronic_non_missing = if (outcome_cols[2] %in% names(ds0)) sum(!is.na(.data[[outcome_cols[2]]])) else NA_integer_,
    total_zero_n = sum(.data[[outcome_cols[1]]] == 0, na.rm = TRUE),
    chronic_zero_n = if (outcome_cols[2] %in% names(ds0)) sum(.data[[outcome_cols[2]]] == 0, na.rm = TRUE) else NA_integer_
  ) %>%
  pivot_longer(cols = everything(), names_to = "metric", values_to = "value")

data_context_grain

# ---- g1-data-prep ---------------------------------------------------------------
# Data preparation: identify categorical and continuous predictor variables
# Subset relevant columns for missing data analysis
exclude_base <- c(
  "adm_rno", "hh_oid", "person_oid", "record_id",
  weight_col, outcome_cols, cycle_col, "cycle"
)
exclude_bootstrap <- names(ds0)[grepl("^(bw|bsw|bootstrap|repw)", names(ds0), ignore.case = TRUE)]
excluded_cols <- unique(c(exclude_base, exclude_bootstrap))

candidate_vars <- setdiff(names(ds0), excluded_cols)

predictor_vars <- candidate_vars[vapply(ds0[candidate_vars], function(x) {
  n_non_miss <- sum(!is.na(x))
  n_non_miss > 0
}, logical(1))]

g1_missing_source <- ds0 %>% select(all_of(predictor_vars))
missing_summary <- summarize_missingness(g1_missing_source)

missing_summary_decision <- missing_summary %>%
  summarise(
    n_variables = n(),
    n_vars_missing = sum(n_missing > 0),
    max_pct_missing = max(pct_missing, na.rm = TRUE),
    median_pct_missing = median(pct_missing, na.rm = TRUE),
    all_lt_5pct = all(pct_missing < 0.05)
  )

vars_for_visual <- missing_summary %>%
  filter(n_missing > 0) %>%
  slice_head(n = 25) %>%
  pull(variable)

if (length(vars_for_visual) < 3) {
  vars_for_visual <- missing_summary %>%
    slice_head(n = min(15, nrow(missing_summary))) %>%
    pull(variable)
}

g1_missing_viz <- g1_missing_source %>% select(any_of(vars_for_visual))
g1_missing_viz_sample <- if (nrow(g1_missing_viz) > 5000) {
  dplyr::slice_sample(g1_missing_viz, n = 5000)
} else {
  g1_missing_viz
}

# ---- g1 -----------------------------------------------------------------
# Missing data heatmap (plotly): distribution of missingness across variables
g1_missing_heatmap_df <- g1_missing_viz_sample %>%
  mutate(row_id = row_number()) %>%
  mutate(across(-row_id, ~ is.na(.x))) %>%
  pivot_longer(cols = -row_id, names_to = "variable", values_to = "missing_flag") %>%
  mutate(
    missing_flag = as.integer(missing_flag),
    missing_label = if_else(missing_flag == 1, "Missing", "Observed")
  )

g1_missing_heatmap <- plotly::plot_ly(
  data = g1_missing_heatmap_df,
  x = ~variable,
  y = ~row_id,
  z = ~missing_flag,
  type = "heatmap",
  colors = c("#2ca25f", "#de2d26"),
  showscale = FALSE,
  text = ~paste0("Variable: ", variable, "<br>Row: ", row_id, "<br>Status: ", missing_label),
  hoverinfo = "text"
) %>%
  plotly::layout(
    title = list(text = "Q5.1 Missingness heatmap across selected predictors"),
    xaxis = list(title = "Predictor variable", tickangle = -45),
    yaxis = list(title = "Sampled rows")
  )

save_plotly_widget(
  plot_obj = g1_missing_heatmap,
  file_stem = "g1_missing_heatmap_plotly",
  prints_folder = prints_folder
)

g1_missing_heatmap_gg <- ggplot(
  g1_missing_heatmap_df,
  aes(x = variable, y = row_id, fill = missing_label)
) +
  geom_tile() +
  scale_fill_manual(values = c("Observed" = "#2ca25f", "Missing" = "#de2d26")) +
  labs(
    title = "Q5.1 Missingness heatmap across selected predictors",
    x = "Predictor variable",
    y = "Sampled rows",
    fill = "Status"
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  filename = file.path(prints_folder, "g1_missing_heatmap_ggplot.png"),
  plot = g1_missing_heatmap_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# ---- g2 -----------------------------------------------------------------
# Missing data by variable (plotly): proportion missing per variable
g2_missing_by_var_df <- missing_summary %>%
  mutate(
    pct_missing_label = scales::percent(pct_missing, accuracy = 0.1),
    variable = forcats::fct_reorder(variable, pct_missing)
  )

g2_missing_by_var <- plotly::plot_ly(
  data = g2_missing_by_var_df,
  x = ~pct_missing,
  y = ~variable,
  type = "bar",
  orientation = "h",
  marker = list(color = "#1f77b4"),
  text = ~paste0("Missing proportion: ", pct_missing_label,
                 "<br>Missing n: ", scales::comma(n_missing),
                 "<br>Complete n: ", scales::comma(n_complete)),
  hoverinfo = "text"
) %>%
  plotly::layout(
    title = list(text = "Q5.1 Missingness proportion by predictor variable"),
    xaxis = list(title = "Missingness proportion", tickformat = ".0%"),
    yaxis = list(title = "Predictor variable")
  )

save_plotly_widget(
  plot_obj = g2_missing_by_var,
  file_stem = "g2_missing_by_variable_plotly",
  prints_folder = prints_folder
)

g2_missing_by_var_gg <- ggplot(
  g2_missing_by_var_df,
  aes(x = variable, y = pct_missing)
) +
  geom_col(fill = "#1f77b4") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Q5.1 Missingness proportion by predictor variable",
    x = "Predictor variable",
    y = "Missingness proportion"
  ) +
  theme_minimal(base_size = 10)

ggsave(
  filename = file.path(prints_folder, "g2_missing_by_variable_ggplot.png"),
  plot = g2_missing_by_var_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# ---- g21 ----------------------------------------------------------------
# Missing data bar chart: proportion missing by variable
vars_for_upset <- missing_summary %>%
  filter(n_missing > 0) %>%
  slice_head(n = 12) %>%
  pull(variable)

if (length(vars_for_upset) < 2) {
  vars_for_upset <- missing_summary %>%
    slice_head(n = min(8, nrow(missing_summary))) %>%
    pull(variable)
}

g21_upset_source <- g1_missing_source %>% select(any_of(vars_for_upset))

if (ncol(g21_upset_source) > 0) {
  g21_pattern_counts <- g21_upset_source %>%
    mutate(
      pattern = apply(
        across(everything(), ~ if_else(is.na(.x), "M", "O")),
        1,
        paste0,
        collapse = ""
      )
    ) %>%
    count(pattern, sort = TRUE) %>%
    slice_head(n = 15) %>%
    mutate(
      missing_count = stringr::str_count(pattern, "M"),
      pattern_rank = row_number()
    )
} else {
  g21_pattern_counts <- tibble::tibble(
    pattern = character(0),
    n = integer(0),
    missing_count = integer(0),
    pattern_rank = integer(0)
  )
}

g21_missing_upset <- plotly::plot_ly(
  data = g21_pattern_counts,
  x = ~reorder(pattern, n),
  y = ~n,
  type = "bar",
  marker = list(color = "#9467bd"),
  text = ~paste0("Pattern: ", pattern,
                 "<br>Rows: ", scales::comma(n),
                 "<br>Missing vars in pattern: ", missing_count),
  hoverinfo = "text"
) %>%
  plotly::layout(
    title = list(text = "Q5.1 Co-occurrence of missingness patterns (top patterns)"),
    xaxis = list(title = "Missingness pattern (M=missing, O=observed)", tickangle = -45),
    yaxis = list(title = "Row count")
  )

save_plotly_widget(
  plot_obj = g21_missing_upset,
  file_stem = "g21_missing_cooccurrence_plotly",
  prints_folder = prints_folder
)

g21_missing_upset_gg <- ggplot(
  g21_pattern_counts,
  aes(x = reorder(pattern, n), y = n)
) +
  geom_col(fill = "#9467bd") +
  labs(
    title = "Q5.1 Co-occurrence of missingness patterns (top patterns)",
    x = "Missingness pattern (M=missing, O=observed)",
    y = "Row count"
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  filename = file.path(prints_folder, "g21_missing_cooccurrence_ggplot.png"),
  plot = g21_missing_upset_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# ---- g22 ----------------------------------------------------------------
# Missing data density (plotly): distribution of variable-level missingness
g22_missing_density <- plotly::plot_ly(
  data = missing_summary,
  x = ~pct_missing,
  type = "histogram",
  nbinsx = 30,
  marker = list(color = "#1f77b4", line = list(color = "white", width = 1))
) %>%
  plotly::layout(
    title = list(text = "Q5.1 Distribution of variable-level missingness"),
    xaxis = list(title = "Missingness proportion", tickformat = ".0%"),
    yaxis = list(title = "Number of variables"),
    shapes = list(
      list(
        type = "line",
        x0 = 0.05,
        x1 = 0.05,
        y0 = 0,
        y1 = 1,
        yref = "paper",
        line = list(color = "#d62728", dash = "dash", width = 2)
      )
    ),
    annotations = list(
      list(
        x = 0.05,
        y = 1,
        yref = "paper",
        text = "5% reference",
        showarrow = FALSE,
        xanchor = "left",
        font = list(color = "#d62728")
      )
    )
  )

save_plotly_widget(
  plot_obj = g22_missing_density,
  file_stem = "g22_missing_density_plotly",
  prints_folder = prints_folder
)

g22_missing_density_gg <- ggplot(missing_summary, aes(x = pct_missing)) +
  geom_histogram(bins = 30, fill = "#1f77b4", color = "white") +
  geom_vline(xintercept = 0.05, color = "#d62728", linetype = "dashed", linewidth = 0.8) +
  annotate("text", x = 0.05, y = Inf, label = "5% reference", vjust = 1.5, hjust = -0.1, color = "#d62728") +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Q5.1 Distribution of variable-level missingness",
    x = "Missingness proportion",
    y = "Number of variables"
  ) +
  theme_minimal(base_size = 10)

ggsave(
  filename = file.path(prints_folder, "g22_missing_density_ggplot.png"),
  plot = g22_missing_density_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# ---- t1-data-prep -------------------------------------------------------
# Data preparation for Table 1: Descriptive Statistics
# Filter, stratify by cycle, prepare categorical variable summaries
categorical_predictor_vars <- predictor_vars[vapply(ds0[predictor_vars], function(x) {
  (is.factor(x) || is.character(x) || is.logical(x)) ||
    ((is.numeric(x) || is.integer(x)) && dplyr::n_distinct(x, na.rm = TRUE) <= 12)
}, logical(1))]

categorical_predictor_vars <- categorical_predictor_vars[vapply(ds0[categorical_predictor_vars], function(x) {
  dplyr::n_distinct(x, na.rm = TRUE) >= 2
}, logical(1))]

t1_table1_categorical <- create_table1_categorical(
  data = ds0,
  design = survey_design,
  categorical_vars = categorical_predictor_vars,
  cycle_col = cycle_col
)

t1_table1_preview <- t1_table1_categorical %>%
  mutate(
    unweighted_pct = scales::percent(unweighted_prop, accuracy = 0.1),
    weighted_pct = scales::percent(weighted_prop, accuracy = 0.1)
  ) %>%
  select(variable, level, group, unweighted_n, unweighted_pct, weighted_n, weighted_pct)

# ---- t1 -----------------------------------------------------------------
# Table 1 (Overall & Stratified by CCHS Cycle):
# Unweighted and weighted frequencies, proportions for categorical predictors
t1_table1_proof <- t1_table1_categorical %>%
  group_by(variable, group) %>%
  summarise(
    sum_unweighted_prop = sum(unweighted_prop, na.rm = TRUE),
    sum_weighted_prop = sum(weighted_prop, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    unweighted_prop_ok = abs(sum_unweighted_prop - 1) < 1e-6,
    weighted_prop_ok = abs(sum_weighted_prop - 1) < 1e-6
  )

# ---- t2-data-prep -------------------------------------------------------
# Data preparation for outcome variable descriptive statistics
t2_outcome_stats <- create_outcome_stats(
  data = ds0,
  design = survey_design,
  outcome_vars = outcome_cols,
  cycle_col = cycle_col
)

# ---- t2 -----------------------------------------------------------------
# Outcome descriptive statistics: weighted mean, SD by cycle and strata
t2_outcome_stats_pretty <- t2_outcome_stats %>%
  mutate(
    unweighted_mean = round(unweighted_mean, 3),
    unweighted_sd = round(unweighted_sd, 3),
    weighted_mean = round(weighted_mean, 3),
    weighted_se = round(weighted_se, 3),
    weighted_variance = round(weighted_variance, 3),
    weighted_sd = round(weighted_sd, 3)
  )

t2_outcome_primary_pretty <- t2_outcome_stats_pretty %>%
  filter(outcome == outcome_cols[1]) %>%
  mutate(group = as.character(group)) %>%
  select(group, unweighted_n, unweighted_mean, unweighted_sd, weighted_mean, weighted_se, weighted_sd)

t1_table1_comprehensive <- t1_table1_preview %>%
  mutate(
    statistic_type = "Categorical predictors",
    outcome = NA_character_,
    unweighted_mean = NA_real_,
    unweighted_sd = NA_real_,
    weighted_mean = NA_real_,
    weighted_sd = NA_real_
  ) %>%
  select(
    statistic_type,
    variable,
    level,
    group,
    unweighted_n,
    unweighted_pct,
    weighted_n,
    weighted_pct,
    outcome,
    unweighted_mean,
    unweighted_sd,
    weighted_mean,
    weighted_sd
  )

t1_outcome_comprehensive <- t2_outcome_stats_pretty %>%
  filter(outcome == outcome_cols[1]) %>%
  mutate(
    statistic_type = "Outcome (days absent)",
    variable = outcome,
    level = "mean/sd",
    unweighted_pct = NA_character_,
    weighted_n = NA_real_,
    weighted_pct = NA_character_
  ) %>%
  mutate(
    group = as.character(group)
  ) %>%
  select(
    statistic_type,
    variable,
    level,
    group,
    unweighted_n,
    unweighted_pct,
    weighted_n,
    weighted_pct,
    outcome,
    unweighted_mean,
    unweighted_sd,
    weighted_mean,
    weighted_sd
  )

# ---- g3 -----------------------------------------------------------------
# Weighted outcome means by cycle (plotly)
g3_outcome_weighted_mean <- t2_outcome_stats %>%
  filter(outcome == outcome_cols[1]) %>%
  mutate(
    group = factor(group, levels = c("Overall", sort(setdiff(unique(group), "Overall"))))
  )

g3_outcome_weighted_mean_plot <- plotly::plot_ly(
  data = g3_outcome_weighted_mean,
  x = ~group,
  y = ~weighted_mean,
  type = "bar",
  marker = list(color = "#4e79a7"),
  error_y = ~list(type = "data", array = weighted_se, visible = TRUE),
  text = ~paste0("Group: ", group,
                 "<br>Weighted mean: ", round(weighted_mean, 3),
                 "<br>Weighted SE: ", round(weighted_se, 3),
                 "<br>Weighted SD: ", round(weighted_sd, 3)),
  hoverinfo = "text"
) %>%
  plotly::layout(
    title = list(text = "Q5.2 Weighted mean days absent by pooled sample and cycle"),
    xaxis = list(title = "Sample group"),
    yaxis = list(title = "Weighted mean days absent")
  )

save_plotly_widget(
  plot_obj = g3_outcome_weighted_mean_plot,
  file_stem = "g3_weighted_mean_days_absent_plotly",
  prints_folder = prints_folder
)

g3_outcome_weighted_mean_gg <- ggplot(
  g3_outcome_weighted_mean,
  aes(x = group, y = weighted_mean)
) +
  geom_col(fill = "#4e79a7") +
  geom_errorbar(
    aes(ymin = weighted_mean - weighted_se, ymax = weighted_mean + weighted_se),
    width = 0.2
  ) +
  labs(
    title = "Q5.2 Weighted mean days absent by pooled sample and cycle",
    x = "Sample group",
    y = "Weighted mean days absent"
  ) +
  theme_minimal(base_size = 10)

ggsave(
  filename = file.path(prints_folder, "g3_weighted_mean_days_absent_ggplot.png"),
  plot = g3_outcome_weighted_mean_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# ---- g31 ----------------------------------------------------------------
# Weighting impact visualization (plotly): unweighted vs weighted proportions
g31_weighting_impact_source <- t1_table1_categorical %>%
  filter(group == "Overall") %>%
  mutate(level_label = paste(variable, level, sep = " :: ")) %>%
  arrange(desc(weighted_n)) %>%
  slice_head(n = 25) %>%
  select(variable, level, level_label, unweighted_prop, weighted_prop) %>%
  pivot_longer(
    cols = c(unweighted_prop, weighted_prop),
    names_to = "measure",
    values_to = "proportion"
  ) %>%
  mutate(measure = recode(measure,
                          unweighted_prop = "Unweighted proportion",
                          weighted_prop = "Weighted proportion"))

g31_weighting_impact_plot <- plotly::plot_ly(
  data = g31_weighting_impact_source,
  x = ~level_label,
  y = ~proportion,
  color = ~measure,
  colors = c("#f28e2b", "#59a14f"),
  type = "bar",
  text = ~paste0("Variable: ", variable,
                 "<br>Level: ", level,
                 "<br>", measure, ": ", scales::percent(proportion, accuracy = 0.1)),
  hoverinfo = "text"
) %>%
  plotly::layout(
    barmode = "group",
    title = list(text = "Q5.2 Unweighted vs weighted proportions (selected predictor levels)"),
    xaxis = list(title = "Variable level", tickangle = -60),
    yaxis = list(title = "Proportion", tickformat = ".0%")
  )

save_plotly_widget(
  plot_obj = g31_weighting_impact_plot,
  file_stem = "g31_weighting_impact_plotly",
  prints_folder = prints_folder
)

g31_weighting_impact_gg <- ggplot(
  g31_weighting_impact_source,
  aes(x = level_label, y = proportion, fill = measure)
) +
  geom_col(position = position_dodge(width = 0.8)) +
  scale_fill_manual(values = c("Unweighted proportion" = "#f28e2b", "Weighted proportion" = "#59a14f")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Q5.2 Unweighted vs weighted proportions (selected predictor levels)",
    x = "Variable level",
    y = "Proportion",
    fill = "Measure"
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 60, hjust = 1))

ggsave(
  filename = file.path(prints_folder, "g31_weighting_impact_ggplot.png"),
  plot = g31_weighting_impact_gg,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

t5_2_requirement_proof <- tibble::tibble(
  requirement = c(
    "Unweighted frequencies available for categorical predictors",
    "Unweighted proportions available for categorical predictors",
    "Weighted frequencies available for categorical predictors",
    "Weighted proportions available for categorical predictors",
    "Weighted mean available for outcome days_absent_total",
    "Weighted SD available for outcome days_absent_total",
    "Stratification by cycle provided",
    "survey package design object used"
  ),
  evidence = c(
    "unweighted_n" %in% names(t1_table1_categorical),
    "unweighted_prop" %in% names(t1_table1_categorical),
    "weighted_n" %in% names(t1_table1_categorical),
    "weighted_prop" %in% names(t1_table1_categorical),
    any(t2_outcome_stats$outcome == outcome_cols[1] & !is.na(t2_outcome_stats$weighted_mean)),
    any(t2_outcome_stats$outcome == outcome_cols[1] & !is.na(t2_outcome_stats$weighted_sd)),
    dplyr::n_distinct(ds0[[cycle_col]], na.rm = TRUE) >= 2,
    inherits(survey_design, "survey.design")
  )
) %>%
  mutate(status = if_else(evidence, "PASS ✓", "FAIL ⚠"))

# ---- t3-data-prep -------------------------------------------------------
# Data preparation for Little's MCAR test
t3_mcar_result <- littles_mcar_test(g1_missing_source)

t3_missing_summary <- missing_summary %>%
  mutate(
    pct_missing_label = scales::percent(pct_missing, accuracy = 0.1)
  )

t3_missing_top <- t3_missing_summary %>%
  slice_head(n = 20) %>%
  select(variable, n_missing, n_complete, pct_missing_label)

recommendation_mcar_holds <- !is.na(t3_mcar_result$p_value[1]) && t3_mcar_result$p_value[1] >= 0.05
recommendation_all_small_missing <- missing_summary_decision$all_lt_5pct[1]

t3_decision <- tibble::tibble(
  criterion = c(
    "Little's MCAR p-value >= 0.05",
    "All variables have <5% missing",
    "Recommended handling strategy"
  ),
  value = c(
    ifelse(is.na(t3_mcar_result$p_value[1]), "Not available", ifelse(recommendation_mcar_holds, "Yes", "No")),
    ifelse(recommendation_all_small_missing, "Yes", "No"),
    dplyr::case_when(
      recommendation_mcar_holds && recommendation_all_small_missing ~
        "Treat missing as separate category or perform complete-case sensitivity check.",
      !recommendation_mcar_holds ~
        "MCAR not supported; prioritize multiple imputation planning before multivariable modeling.",
      TRUE ~
        "MCAR may hold but missingness magnitude suggests considering multiple imputation."
    )
  )
)

t3_mcar_pretty <- t3_mcar_result %>%
  transmute(
    test = test_used,
    statistic = round(statistic, 3),
    df = round(df, 1),
    p_value = round(p_value, 4),
    interpretation,
    note
  )

t3_missing_table_clear <- t3_missing_summary %>%
  mutate(
    missing_rule_lt_5pct = if_else(pct_missing < 0.05, "Yes", "No")
  ) %>%
  select(variable, n_missing, n_complete, pct_missing_label, missing_rule_lt_5pct)

# ---- t3 -----------------------------------------------------------------
# Little's MCAR test results and missing data summary statistics
t3_mcar_result

# ---- finalize-objects ---------------------------------------------------
# Save key objects for downstream use
arrow::write_parquet(missing_summary, file.path(data_private_derived, "q5_1_missing_summary.parquet"))
arrow::write_parquet(t1_table1_categorical, file.path(data_private_derived, "q5_2_table1_categorical.parquet"))
arrow::write_parquet(t2_outcome_stats, file.path(data_private_derived, "q5_2_outcome_stats.parquet"))
arrow::write_parquet(t3_mcar_result, file.path(data_private_derived, "q5_1_mcar_result.parquet"))
