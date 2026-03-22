# nolint start
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
rm(list = ls(all.names = TRUE))
cat("\014")
cat("Working directory: ", getwd())

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(forcats)
library(scales)
library(fs)
requireNamespace("arrow")

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")
base::source("./scripts/operational-functions.R")
if (file.exists("./scripts/graphing/graph-presets.R")) {
	base::source("./scripts/graphing/graph-presets.R")
}

# ---- declare-globals ---------------------------------------------------------
local_root <- "./analysis/eda-3/"
local_data <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")
data_private_derived <- "./data-private/derived/eda-3/"

if (!fs::dir_exists(local_data)) fs::dir_create(local_data)
if (!fs::dir_exists(prints_folder)) fs::dir_create(prints_folder)
if (!fs::dir_exists(data_private_derived)) fs::dir_create(data_private_derived)

path_cchs2_parquet <- "./data-private/derived/cchs-2-tables"
path_analytical_pq <- file.path(path_cchs2_parquet, "cchs_analytical.parquet")
path_sampleflow_pq <- file.path(path_cchs2_parquet, "sample_flow.parquet")
outcome_cols <- c("days_absent_total", "days_absent_chronic")
weight_col <- "wts_m_pooled"

# ---- declare-functions -------------------------------------------------------
base::source(paste0(local_root, "local-functions.R"))

# ---- load-data ---------------------------------------------------------------
if (!file.exists(path_analytical_pq)) {
	stop("Missing required file: ", path_analytical_pq, call. = FALSE)
}

ds0 <- arrow::read_parquet(path_analytical_pq)
sample_flow <- if (file.exists(path_sampleflow_pq)) arrow::read_parquet(path_sampleflow_pq) else NULL

required_cols <- c("adm_rno", weight_col, outcome_cols, "cycle", "cycle_f")
missing_required <- setdiff(required_cols, names(ds0))
if (length(missing_required) > 0) {
	stop("Missing required columns in cchs_analytical.parquet: ",
			 paste(missing_required, collapse = ", "), call. = FALSE)
}

cat(sprintf("Loaded analytical data: %s rows, %s columns\n",
						format(nrow(ds0), big.mark = ","),
						format(ncol(ds0), big.mark = ",")))

# ---- data-context-tables -----------------------------------------------------
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
	usage_in_eda3 = c(
		"Core analytical dataset for outcomes, weights, and respondent-level context.",
		"Exclusion-flow documentation used for sample context (if available)."
	)
)

data_context_grain <- ds0 %>%
	summarise(
		n_rows = n(),
		n_unique_person = n_distinct(adm_rno),
		n_unique_person_cycle = n_distinct(paste(adm_rno, cycle, sep = "_"))
	) %>%
	mutate(
		grain_statement = dplyr::if_else(
			n_rows == n_unique_person_cycle,
			"Grain verified: one row per person x cycle",
			"Potential duplicate person x cycle rows detected"
		)
	)

# ---- data-context-person -----------------------------------------------------
data_context_person <- ds0 %>%
	select(
		adm_rno,
		cycle_f,
		!!weight_col,
		days_absent_total,
		days_absent_chronic,
		age_group,
		sex,
		employment_type,
		work_schedule
	) %>%
	arrange(adm_rno, cycle_f) %>%
	slice_head(n = 2)

# ---- data-context-distributions ----------------------------------------------
data_context_distributions <- ds0 %>%
	summarise(
		total_n = n(),
		total_weight = sum(.data[[weight_col]], na.rm = TRUE),
		total_non_missing = sum(!is.na(days_absent_total)),
		chronic_non_missing = sum(!is.na(days_absent_chronic)),
		total_zero_n = sum(days_absent_total == 0, na.rm = TRUE),
		chronic_zero_n = sum(days_absent_chronic == 0, na.rm = TRUE)
	) %>%
	tidyr::pivot_longer(cols = everything(), names_to = "metric", values_to = "value")

# ---- g1-data-prep ------------------------------------------------------------
q4_1_data <- ds0 %>%
	transmute(
		adm_rno,
		cycle,
		cycle_f,
		wts_m_pooled,
		primary_outcome = days_absent_total,
		sensitive_outcome = days_absent_chronic
	)

q4_1_summary <- bind_rows(
	summarize_outcome_stats(
		data = q4_1_data,
		outcome_col = "primary_outcome",
		weight_col = "wts_m_pooled",
		outcome_label = "Primary outcome: days_absent_total"
	),
	summarize_outcome_stats(
		data = q4_1_data,
		outcome_col = "sensitive_outcome",
		weight_col = "wts_m_pooled",
		outcome_label = "Sensitive outcome: days_absent_chronic"
	)
)

q4_1_comparison <- q4_1_summary %>%
	select(outcome, weighted_mean, weighted_se_mean) %>%
	mutate(
		lower_95 = weighted_mean - 1.96 * weighted_se_mean,
		upper_95 = weighted_mean + 1.96 * weighted_se_mean,
		outcome = forcats::fct_inorder(outcome)
	)

q4_1_count_comparison <- bind_rows(
	q4_1_data %>%
		summarise(
			outcome = "Primary outcome: days_absent_total",
			n_obs_non_missing = sum(!is.na(primary_outcome)),
			n_missing = sum(is.na(primary_outcome)),
			weighted_population_non_missing = sum(wts_m_pooled[!is.na(primary_outcome)], na.rm = TRUE)
		),
	q4_1_data %>%
		summarise(
			outcome = "Sensitive outcome: days_absent_chronic",
			n_obs_non_missing = sum(!is.na(sensitive_outcome)),
			n_missing = sum(is.na(sensitive_outcome)),
			weighted_population_non_missing = sum(wts_m_pooled[!is.na(sensitive_outcome)], na.rm = TRUE)
		)
) %>%
	mutate(outcome = forcats::fct_inorder(outcome))

q4_1_count_gap <- q4_1_count_comparison %>%
	summarise(
		non_missing_difference_primary_minus_sensitive =
			n_obs_non_missing[outcome == "Primary outcome: days_absent_total"] -
			n_obs_non_missing[outcome == "Sensitive outcome: days_absent_chronic"],
		missing_difference_primary_minus_sensitive =
			n_missing[outcome == "Primary outcome: days_absent_total"] -
			n_missing[outcome == "Sensitive outcome: days_absent_chronic"],
		weighted_population_difference_primary_minus_sensitive =
			weighted_population_non_missing[outcome == "Primary outcome: days_absent_total"] -
			weighted_population_non_missing[outcome == "Sensitive outcome: days_absent_chronic"]
	)

verify_q41 <- q4_1_summary %>%
	transmute(
		outcome,
		n_obs_non_missing,
		weighted_mean = round(weighted_mean, 4),
		weighted_se_mean = round(weighted_se_mean, 4),
		weighted_median = round(weighted_median, 4),
		zero_proportion_weighted = round(zero_proportion_weighted, 4),
		pearson_dispersion = round(pearson_dispersion, 4)
	)

q4_1_mean_gap <- q4_1_comparison %>%
	summarise(
		mean_difference_primary_minus_sensitive =
			weighted_mean[outcome == "Primary outcome: days_absent_total"] -
			weighted_mean[outcome == "Sensitive outcome: days_absent_chronic"]
	) %>%
	mutate(
		mean_difference_primary_minus_sensitive =
			round(mean_difference_primary_minus_sensitive, 4)
	)

q4_1_count_long <- q4_1_count_comparison %>%
	select(outcome, n_obs_non_missing, n_missing) %>%
	pivot_longer(
		cols = c(n_obs_non_missing, n_missing),
		names_to = "count_type",
		values_to = "n_people"
	) %>%
	mutate(
		count_type = recode(
			count_type,
			n_obs_non_missing = "Rows with non-missing outcome",
			n_missing = "Rows with missing outcome"
		),
		count_type = factor(
			count_type,
			levels = c("Rows with non-missing outcome", "Rows with missing outcome")
		)
	)

# ---- g1 ----------------------------------------------------------------------
g1_outcome_row_counts <- q4_1_count_long %>%
	ggplot(aes(x = outcome, y = n_people, fill = count_type)) +
	geom_col(position = "dodge", width = 0.7, alpha = 0.92) +
	geom_text(
		aes(label = scales::comma(n_people)),
		position = position_dodge(width = 0.7),
		vjust = -0.3,
		size = 3.1
	) +
	scale_y_continuous(labels = label_comma()) +
	labs(
		title = "Q4-1: Row-count comparison between outcome definitions",
		subtitle = "Comparison of available (non-missing) and missing rows by outcome",
		x = NULL,
		y = "Number of rows",
		fill = NULL
	) +
	theme_minimal(base_size = 11) +
	theme(legend.position = "bottom")

ggsave(
	paste0(prints_folder, "g1_outcome_row_counts.png"),
	g1_outcome_row_counts,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- g11 ---------------------------------------------------------------------
g11_outcome_weighted_coverage <- q4_1_count_comparison %>%
	ggplot(aes(x = outcome, y = weighted_population_non_missing, fill = outcome)) +
	geom_col(width = 0.6, alpha = 0.9) +
	geom_text(
		aes(label = scales::comma(round(weighted_population_non_missing))),
		vjust = -0.35,
		size = 3.2
	) +
	scale_y_continuous(labels = label_comma()) +
	labs(
		title = "Q4-1: Weighted non-missing population by outcome",
		subtitle = "Weighted respondent coverage retained for each outcome definition",
		x = NULL,
		y = "Weighted non-missing population"
	) +
	theme_minimal(base_size = 11) +
	theme(legend.position = "none")

ggsave(
	paste0(prints_folder, "g11_outcome_weighted_coverage.png"),
	g11_outcome_weighted_coverage,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- g2-data-prep ------------------------------------------------------------
q4_2_stats <- bind_rows(
	summarize_outcome_stats(
		data = ds0,
		outcome_col = "days_absent_total",
		weight_col = weight_col,
		outcome_label = "Primary outcome: days_absent_total"
	),
	summarize_outcome_stats(
		data = ds0,
		outcome_col = "days_absent_chronic",
		weight_col = weight_col,
		outcome_label = "Sensitive outcome: days_absent_chronic"
	)
) %>%
	mutate(
		across(
			c(weighted_mean, weighted_se_mean, weighted_q1, weighted_median, weighted_q3,
				weighted_variance, weighted_sd, zero_proportion_weighted, pearson_dispersion,
				effective_n),
			~ round(.x, 4)
		)
	)

q4_2_stats_pretty <- q4_2_stats %>%
	transmute(
		outcome,
		`Weighted mean` = weighted_mean,
		`Weighted SE (mean)` = weighted_se_mean,
		`Weighted Q1` = weighted_q1,
		`Weighted median` = weighted_median,
		`Weighted Q3` = weighted_q3,
		`Weighted variance` = weighted_variance,
		`Weighted SD` = weighted_sd,
		`Zero frequency (n)` = zero_frequency_unweighted,
		`Zero proportion (weighted)` = zero_proportion_weighted,
		`Maximum value` = maximum_value,
		`Pearson dispersion (var/mean)` = pearson_dispersion
	)

verify_q42 <- q4_2_stats %>%
	select(
		outcome,
		weighted_mean,
		weighted_se_mean,
		weighted_q1,
		weighted_median,
		weighted_q3,
		weighted_variance,
		weighted_sd,
		zero_frequency_unweighted,
		zero_proportion_weighted,
		maximum_value,
		pearson_dispersion
	)

q4_2_metrics_proof <- tibble::tibble(
	metric_required = c(
		"Mean (weighted)",
		"Standard error of mean (weighted)",
		"Median (weighted)",
		"Q1 (weighted)",
		"Q3 (weighted)",
		"Variance (weighted)",
		"Standard deviation (weighted)",
		"Frequency of zero values",
		"Proportion of zero values",
		"Maximum value",
		"Pearson dispersion (variance / mean)"
	),
	computed_in_table = c(
		"weighted_mean" %in% names(q4_2_stats),
		"weighted_se_mean" %in% names(q4_2_stats),
		"weighted_median" %in% names(q4_2_stats),
		"weighted_q1" %in% names(q4_2_stats),
		"weighted_q3" %in% names(q4_2_stats),
		"weighted_variance" %in% names(q4_2_stats),
		"weighted_sd" %in% names(q4_2_stats),
		"zero_frequency_unweighted" %in% names(q4_2_stats),
		"zero_proportion_weighted" %in% names(q4_2_stats),
		"maximum_value" %in% names(q4_2_stats),
		"pearson_dispersion" %in% names(q4_2_stats)
	)
) %>%
	mutate(status = if_else(computed_in_table, "PASS ✓", "FAIL ⚠"))

q4_2_long <- ds0 %>%
	select(adm_rno, all_of(weight_col), days_absent_total, days_absent_chronic) %>%
	pivot_longer(
		cols = c(days_absent_total, days_absent_chronic),
		names_to = "outcome",
		values_to = "days_absent"
	) %>%
	mutate(
		outcome = recode(
			outcome,
			days_absent_total = "Primary outcome",
			days_absent_chronic = "Sensitive outcome"
		),
		outcome = factor(outcome, levels = c("Primary outcome", "Sensitive outcome"))
	)

q4_2_distribution_data <- q4_2_long %>%
	filter(!is.na(days_absent), !is.na(.data[[weight_col]]), .data[[weight_col]] > 0)

q4_2_zero_prop <- q4_2_distribution_data %>%
	group_by(outcome) %>%
	summarise(
		weighted_zero_prop = sum(.data[[weight_col]][days_absent == 0]) / sum(.data[[weight_col]]),
		unweighted_zero_n = sum(days_absent == 0),
		.groups = "drop"
	)

q4_2_required_core_long <- q4_2_stats %>%
	select(
		outcome,
		weighted_mean,
		weighted_median,
		weighted_q1,
		weighted_q3,
		weighted_sd,
		maximum_value
	) %>%
	pivot_longer(
		cols = -outcome,
		names_to = "metric",
		values_to = "value"
	) %>%
	mutate(
		metric = recode(
			metric,
			weighted_mean = "Weighted mean",
			weighted_median = "Weighted median",
			weighted_q1 = "Weighted Q1",
			weighted_q3 = "Weighted Q3",
			weighted_sd = "Weighted SD",
			maximum_value = "Maximum value"
		),
		metric = factor(
			metric,
			levels = c(
				"Weighted mean",
				"Weighted median",
				"Weighted Q1",
				"Weighted Q3",
				"Weighted SD",
				"Maximum value"
			)
		)
	)

q4_2_required_diagnostic_long <- q4_2_stats %>%
	select(
		outcome,
		weighted_variance,
		zero_frequency_unweighted,
		zero_proportion_weighted,
		pearson_dispersion
	) %>%
	pivot_longer(
		cols = -outcome,
		names_to = "metric",
		values_to = "value"
	) %>%
	mutate(
		metric = recode(
			metric,
			weighted_variance = "Weighted variance",
			zero_frequency_unweighted = "Zero frequency (n)",
			zero_proportion_weighted = "Zero proportion (weighted)",
			pearson_dispersion = "Pearson dispersion (var/mean)"
		),
		metric = factor(
			metric,
			levels = c(
				"Weighted variance",
				"Zero frequency (n)",
				"Zero proportion (weighted)",
				"Pearson dispersion (var/mean)"
			)
		)
	)

# ---- g2 ----------------------------------------------------------------------
g2_weighted_distribution <- q4_2_distribution_data %>%
	ggplot(aes(x = days_absent, weight = .data[[weight_col]], fill = outcome)) +
	geom_histogram(position = "identity", alpha = 0.45, bins = 30) +
	labs(
		title = "Q4-2: Weighted distribution of absenteeism outcomes",
		subtitle = "Histogram weighted by pooled survey weights",
		x = "Days absent",
		y = "Weighted count"
	) +
	theme_minimal(base_size = 11)

ggsave(
	paste0(prints_folder, "g2_weighted_distribution.png"),
	g2_weighted_distribution,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- g21 ---------------------------------------------------------------------
g21_zero_frequency_and_share <- q4_2_zero_prop %>%
	select(outcome, weighted_zero_prop, unweighted_zero_n) %>%
	pivot_longer(
		cols = c(weighted_zero_prop, unweighted_zero_n),
		names_to = "metric",
		values_to = "value"
	) %>%
	mutate(
		metric = recode(
			metric,
			weighted_zero_prop = "Zero proportion (weighted)",
			unweighted_zero_n = "Zero frequency (n)"
		),
		label_value = if_else(
			metric == "Zero proportion (weighted)",
			percent(value, accuracy = 0.1),
			comma(round(value))
		)
	) %>%
	ggplot(aes(x = outcome, y = value, fill = outcome)) +
	geom_col(width = 0.6, alpha = 0.9) +
	geom_text(aes(label = label_value), vjust = -0.35, size = 3.1) +
	facet_wrap(~ metric, scales = "free_y") +
	labs(
		title = "Q4-2: Zero-value profile by outcome definition",
		subtitle = "Displays both zero frequency (n) and weighted zero proportion",
		x = NULL,
		y = NULL
	) +
	theme_minimal(base_size = 11) +
	theme(legend.position = "none")

ggsave(
	paste0(prints_folder, "g21_zero_frequency_and_share.png"),
	g21_zero_frequency_and_share,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- g22 ---------------------------------------------------------------------
g22_required_core_comparison <- q4_2_required_core_long %>%
	ggplot(aes(x = outcome, y = value, fill = outcome)) +
	geom_col(width = 0.6, alpha = 0.9) +
	geom_text(
		aes(label = number(value, accuracy = 0.01, big.mark = ",")),
		vjust = -0.35,
		size = 2.9
	) +
	facet_wrap(~ metric, scales = "free_y") +
	labs(
		title = "Q4-2: Core location and spread statistics by outcome",
		subtitle = "Weighted mean/median/quartiles, weighted SD, and maximum value",
		x = NULL,
		y = NULL
	) +
	theme_minimal(base_size = 11) +
	theme(legend.position = "none")

ggsave(
	paste0(prints_folder, "g22_required_core_comparison.png"),
	g22_required_core_comparison,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- g23 ---------------------------------------------------------------------
g23_required_diagnostic_comparison <- q4_2_required_diagnostic_long %>%
	ggplot(aes(x = outcome, y = value, fill = outcome)) +
	geom_col(width = 0.6, alpha = 0.9) +
	geom_text(
		aes(
			label = if_else(
				metric == "Zero proportion (weighted)",
				percent(value, accuracy = 0.1),
				number(value, accuracy = 0.01, big.mark = ",")
			)
		),
		vjust = -0.35,
		size = 2.9
	) +
	facet_wrap(~ metric, scales = "free_y") +
	labs(
		title = "Q4-2: Variance, zero-profile, and dispersion diagnostics",
		subtitle = "Side-by-side comparison of high-impact required diagnostic metrics",
		x = NULL,
		y = NULL
	) +
	theme_minimal(base_size = 11) +
	theme(legend.position = "none")

ggsave(
	paste0(prints_folder, "g23_required_diagnostic_comparison.png"),
	g23_required_diagnostic_comparison,
	width = 8.5,
	height = 5.5,
	dpi = 300
)

# ---- save-outputs ------------------------------------------------------------
arrow::write_parquet(q4_1_summary, file.path(data_private_derived, "q4_1_summary.parquet"))
arrow::write_parquet(q4_2_stats, file.path(data_private_derived, "q4_2_stats.parquet"))

# nolint end
