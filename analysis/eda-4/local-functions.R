# nolint start
# Custom functions for EDA-4 analysis
# Sourced from ./analysis/eda-4/eda-4.R via: base::source(paste0(local_root, "local-functions.R"))

# ---- weighted utilities -----------------------------------------------------
weighted_moments <- function(x, w) {
  keep <- !is.na(x) & !is.na(w) & w > 0
  x <- x[keep]
  w <- w[keep]

  if (length(x) == 0 || sum(w) <= 0) {
    return(list(
      n_obs = 0L,
      w_sum = NA_real_,
      n_eff = NA_real_,
      mean_w = NA_real_,
      var_w = NA_real_,
      sd_w = NA_real_,
      se_mean_w = NA_real_
    ))
  }

  w_sum <- sum(w)
  wn <- w / w_sum
  mean_w <- sum(wn * x)
  var_w <- sum(wn * (x - mean_w)^2)
  sd_w <- sqrt(var_w)
  n_eff <- (w_sum^2) / sum(w^2)
  se_mean_w <- sqrt(var_w / n_eff)

  list(
    n_obs = length(x),
    w_sum = w_sum,
    n_eff = n_eff,
    mean_w = mean_w,
    var_w = var_w,
    sd_w = sd_w,
    se_mean_w = se_mean_w
  )
}

safe_extract <- function(x, candidates) {
  hit <- intersect(candidates, names(x))
  if (length(hit) == 0) return(NA_real_)
  as.numeric(x[[hit[1]]])[1]
}

# ---- plotly export helper ---------------------------------------------------
save_plotly_widget <- function(plot_obj,
                               file_stem,
                               prints_folder,
                               width = 1200,
                               height = 780,
                               try_png = TRUE) {
  stopifnot(dir.exists(prints_folder))

  html_path <- file.path(prints_folder, paste0(file_stem, ".html"))
  htmlwidgets::saveWidget(
    widget = plot_obj,
    file = html_path,
    selfcontained = FALSE
  )

  png_path <- file.path(prints_folder, paste0(file_stem, ".png"))

  if (isTRUE(try_png) && requireNamespace("plotly", quietly = TRUE)) {
    try({
      plotly::save_image(plot_obj, file = png_path, width = width, height = height)
    }, silent = TRUE)
  }

  invisible(list(html = html_path, png = png_path))
}

# ---- summarize_missingness --------------------------------------------------
summarize_missingness <- function(data) {
  stopifnot(is.data.frame(data))

  tibble::tibble(
    variable = names(data),
    n_missing = vapply(data, function(x) sum(is.na(x)), numeric(1)),
    n_complete = vapply(data, function(x) sum(!is.na(x)), numeric(1)),
    n_total = nrow(data)
  ) %>%
    dplyr::mutate(
      pct_missing = ifelse(n_total > 0, n_missing / n_total, NA_real_),
      pct_complete = ifelse(n_total > 0, n_complete / n_total, NA_real_)
    ) %>%
    dplyr::arrange(dplyr::desc(pct_missing), variable)
}

# ---- littles_mcar_test ------------------------------------------------------
littles_mcar_test <- function(data) {
  stopifnot(is.data.frame(data))

  if (ncol(data) < 2) {
    return(tibble::tibble(
      test_used = "Little's MCAR",
      statistic = NA_real_,
      df = NA_real_,
      p_value = NA_real_,
      n_rows = nrow(data),
      n_variables = ncol(data),
      interpretation = "Insufficient variables for MCAR test",
      note = "Need at least two variables."
    ))
  }

  prepped <- data %>%
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      ~ if (is.factor(.x) || is.character(.x) || is.logical(.x)) as.numeric(factor(.x)) else as.numeric(.x)
    ))

  keep_vars <- names(prepped)[vapply(prepped, function(x) {
    n_non_miss <- sum(!is.na(x))
    n_non_miss > 1 && stats::var(x, na.rm = TRUE) > 0
  }, logical(1))]

  prepped <- prepped[, keep_vars, drop = FALSE]

  if (ncol(prepped) < 2) {
    return(tibble::tibble(
      test_used = "Little's MCAR",
      statistic = NA_real_,
      df = NA_real_,
      p_value = NA_real_,
      n_rows = nrow(prepped),
      n_variables = ncol(prepped),
      interpretation = "Insufficient non-constant variables for MCAR test",
      note = "After filtering constants/all-missing columns, fewer than two variables remained."
    ))
  }

  test_obj <- tryCatch(
    naniar::mcar_test(prepped),
    error = function(e) e
  )

  if (inherits(test_obj, "error")) {
    return(tibble::tibble(
      test_used = "Little's MCAR",
      statistic = NA_real_,
      df = NA_real_,
      p_value = NA_real_,
      n_rows = nrow(prepped),
      n_variables = ncol(prepped),
      interpretation = "MCAR test unavailable",
      note = conditionMessage(test_obj)
    ))
  }

  p_value <- safe_extract(test_obj, c("p.value", "p_value", "pval", "p"))
  statistic <- safe_extract(test_obj, c("statistic", "chi.square", "chisq"))
  df <- safe_extract(test_obj, c("df", "degrees.of.freedom"))

  interpretation <- dplyr::case_when(
    is.na(p_value) ~ "MCAR result could not be interpreted",
    p_value >= 0.05 ~ "Fail to reject MCAR (pattern compatible with MCAR)",
    TRUE ~ "Reject MCAR (pattern likely not MCAR)"
  )

  tibble::tibble(
    test_used = "Little's MCAR",
    statistic = statistic,
    df = df,
    p_value = p_value,
    n_rows = nrow(prepped),
    n_variables = ncol(prepped),
    interpretation = interpretation,
    note = NA_character_
  )
}

# ---- create_weighted_table --------------------------------------------------
create_weighted_table <- function(data, design, var_name, stratify_by = NULL) {
  stopifnot(is.data.frame(data))
  stopifnot(var_name %in% names(data))

  x <- forcats::fct_na_value_to_level(as.factor(data[[var_name]]), level = "(Missing)")
  tmp <- data.frame(.x = x)

  if (is.null(stratify_by)) {
    dsg <- update(design, .x = x)
    unweighted <- as.data.frame(table(tmp$.x), stringsAsFactors = FALSE)
    names(unweighted) <- c("level", "unweighted_n")
    weighted_tab <- as.data.frame(survey::svytable(~ .x, dsg))
    names(weighted_tab) <- c("level", "weighted_n")

    out <- dplyr::left_join(unweighted, weighted_tab, by = "level") %>%
      dplyr::mutate(
        unweighted_prop = unweighted_n / sum(unweighted_n),
        weighted_prop = weighted_n / sum(weighted_n),
        variable = var_name,
        group = "Overall"
      ) %>%
      dplyr::select(variable, level, group, unweighted_n, unweighted_prop, weighted_n, weighted_prop)

    return(out)
  }

  stopifnot(stratify_by %in% names(data))
  s <- as.factor(data[[stratify_by]])
  dsg <- update(design, .x = x, .s = s)

  unweighted <- as.data.frame(table(tmp$.x, s), stringsAsFactors = FALSE)
  names(unweighted) <- c("level", "group", "unweighted_n")
  weighted_tab <- as.data.frame(survey::svytable(~ .x + .s, dsg))
  names(weighted_tab) <- c("level", "group", "weighted_n")

  dplyr::left_join(unweighted, weighted_tab, by = c("level", "group")) %>%
    dplyr::group_by(group) %>%
    dplyr::mutate(
      unweighted_prop = unweighted_n / sum(unweighted_n),
      weighted_prop = weighted_n / sum(weighted_n)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(variable = var_name) %>%
    dplyr::select(variable, level, group, unweighted_n, unweighted_prop, weighted_n, weighted_prop)
}

# ---- create_table1_categorical ----------------------------------------------
create_table1_categorical <- function(data, design, categorical_vars, cycle_col = "cycle_f") {
  purrr::map_dfr(categorical_vars, function(v) {
    overall <- create_weighted_table(data, design, var_name = v, stratify_by = NULL)
    by_cycle <- create_weighted_table(data, design, var_name = v, stratify_by = cycle_col)
    dplyr::bind_rows(overall, by_cycle)
  })
}

# ---- create_outcome_stats ---------------------------------------------------
create_outcome_stats <- function(data, design, outcome_vars, cycle_col = "cycle_f") {
  cycle_levels <- unique(as.character(data[[cycle_col]]))
  cycle_levels <- cycle_levels[!is.na(cycle_levels)]
  design <- update(design, .cycle_tmp = as.character(get(cycle_col)))

  purrr::map_dfr(outcome_vars, function(outcome) {
    pooled_mean <- survey::svymean(stats::as.formula(paste0("~", outcome)), design, na.rm = TRUE)
    pooled_var <- survey::svyvar(stats::as.formula(paste0("~", outcome)), design, na.rm = TRUE)

    pooled_row <- tibble::tibble(
      outcome = outcome,
      group = "Overall",
      unweighted_n = sum(!is.na(data[[outcome]])),
      unweighted_mean = mean(data[[outcome]], na.rm = TRUE),
      unweighted_sd = stats::sd(data[[outcome]], na.rm = TRUE),
      weighted_mean = as.numeric(coef(pooled_mean)[1]),
      weighted_se = as.numeric(sqrt(vcov(pooled_mean))[1]),
      weighted_variance = as.numeric(coef(pooled_var)[1]),
      weighted_sd = sqrt(as.numeric(coef(pooled_var)[1]))
    )

    by_cycle_rows <- purrr::map_dfr(cycle_levels, function(g) {
      dsg_g <- subset(design, .cycle_tmp == g)
      mu <- survey::svymean(stats::as.formula(paste0("~", outcome)), dsg_g, na.rm = TRUE)
      vv <- survey::svyvar(stats::as.formula(paste0("~", outcome)), dsg_g, na.rm = TRUE)

      tibble::tibble(
        outcome = outcome,
        group = g,
        unweighted_n = sum(!is.na(data[[outcome]]) & as.character(data[[cycle_col]]) == g),
        unweighted_mean = mean(data[[outcome]][as.character(data[[cycle_col]]) == g], na.rm = TRUE),
        unweighted_sd = stats::sd(data[[outcome]][as.character(data[[cycle_col]]) == g], na.rm = TRUE),
        weighted_mean = as.numeric(coef(mu)[1]),
        weighted_se = as.numeric(sqrt(vcov(mu))[1]),
        weighted_variance = as.numeric(coef(vv)[1]),
        weighted_sd = sqrt(as.numeric(coef(vv)[1]))
      )
    })

    dplyr::bind_rows(pooled_row, by_cycle_rows)
  })
}

# ---- document_data_structure ------------------------------------------------
document_data_structure <- function(data, cycle_col = "cycle_f", id_col = "adm_rno") {
  tibble::tibble(
    n_rows = nrow(data),
    n_columns = ncol(data),
    n_unique_id = dplyr::n_distinct(data[[id_col]]),
    n_cycle_levels = dplyr::n_distinct(data[[cycle_col]])
  )
}

# nolint end
