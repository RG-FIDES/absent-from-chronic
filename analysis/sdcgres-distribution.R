rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magrittr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(forcats)
library(scales)

if (requireNamespace("httpgd", quietly = TRUE)) {
  tryCatch(httpgd::hgd(), error = function(e) message("httpgd: ", conditionMessage(e)))
}

# ---- load-sources ------------------------------------------------------------
base::source("./scripts/common-functions.R")

# ---- declare-globals ---------------------------------------------------------
config       <- config::get()
path_ferry   <- config$database$cchs$ferry_sqlite
path_ellis   <- config$database$cchs$ellis_sqlite
path_codebook_values <- "./data-private/derived/codebook-value-labels.csv"

VAR_RAW      <- "SDCGRES"   # name in Ferry tables (upper-case)
VAR_RAW2     <- "SDCFIMM"   # immigrant flag (YES/NO) — Ferry only, not in Ellis
VAR_ELLIS    <- "immigration_status"

# ---- load-data ---------------------------------------------------------------
# -- Codebook: value labels for SDCGRES (from codebook-value-labels.csv)
codebook_values <- readr::read_csv(path_codebook_values, show_col_types = FALSE)

sdcgres_labels <- codebook_values %>%
  dplyr::filter(variable_name == VAR_RAW) %>%
  dplyr::distinct(value_code, value_label) %>%
  dplyr::rename(value = value_code, label = value_label) %>%
  dplyr::mutate(value = as.integer(value))

sdcfimm_labels <- codebook_values %>%
  dplyr::filter(variable_name == VAR_RAW2) %>%
  dplyr::distinct(value_code, value_label) %>%
  dplyr::rename(value = value_code, label = value_label) %>%
  dplyr::mutate(value = as.integer(value))

# -- Pre-Ellis: pool both CCHS cycles from the Ferry SQLite (both variables)
con_ferry <- DBI::dbConnect(RSQLite::SQLite(), path_ferry)
ds_2010_raw <- DBI::dbGetQuery(
  con_ferry,
  sprintf("SELECT %s, %s FROM cchs_2010", VAR_RAW, VAR_RAW2)
)
ds_2014_raw <- DBI::dbGetQuery(
  con_ferry,
  sprintf("SELECT %s, %s FROM cchs_2014", VAR_RAW, VAR_RAW2)
)
DBI::dbDisconnect(con_ferry)

ds_pre <- dplyr::bind_rows(ds_2010_raw, ds_2014_raw) %>%
  dplyr::rename(sdcgres = dplyr::all_of(VAR_RAW),
                sdcfimm = dplyr::all_of(VAR_RAW2)) %>%
  dplyr::mutate(
    sdcgres = as.integer(sdcgres),
    sdcfimm = as.integer(sdcfimm)
  )

# -- Post-Ellis: analytic table from Ellis SQLite
con_ellis <- DBI::dbConnect(RSQLite::SQLite(), path_ellis)
ds_post <- DBI::dbGetQuery(
  con_ellis,
  sprintf("SELECT %s FROM cchs_analytic", VAR_ELLIS)
)
DBI::dbDisconnect(con_ellis)

# ---- tweak-data-0 ------------------------------------------------------------
# Helper: attach codebook labels and compute freq table for one integer column
freq_table <- function(df, col, labels_df) {
  df %>%
    dplyr::rename(value = dplyr::all_of(col)) %>%
    dplyr::left_join(labels_df, by = "value") %>%
    dplyr::mutate(
      label = dplyr::if_else(is.na(label),
                             dplyr::if_else(is.na(value), "NA (system missing)",
                                            paste0("Code ", value, " (unlabelled)")),
                             label)
    ) %>%
    dplyr::count(value, label, name = "n") %>%
    dplyr::arrange(value) %>%
    dplyr::mutate(pct = n / sum(n))
}

# Marginal distributions pre-Ellis
dist_pre_gres <- freq_table(dplyr::select(ds_pre, sdcgres), "sdcgres", sdcgres_labels)
dist_pre_imm  <- freq_table(dplyr::select(ds_pre, sdcfimm), "sdcfimm", sdcfimm_labels)

# Post-Ellis: count the recoded factor
dist_post <- ds_post %>%
  dplyr::count(!!rlang::sym(VAR_ELLIS), name = "n") %>%
  dplyr::rename(label = dplyr::all_of(VAR_ELLIS)) %>%
  dplyr::mutate(
    value = NA_integer_,
    label = as.character(label),
    pct   = n / sum(n)
  )

# Joint distribution SDCFIMM × SDCGRES (pre-Ellis)
dist_joint <- ds_pre %>%
  dplyr::left_join(sdcfimm_labels %>% dplyr::rename(sdcfimm = value, imm_label = label),
                   by = "sdcfimm") %>%
  dplyr::left_join(sdcgres_labels %>% dplyr::rename(sdcgres = value, res_label = label),
                   by = "sdcgres") %>%
  dplyr::mutate(
    imm_label = dplyr::if_else(is.na(imm_label),
                               dplyr::if_else(is.na(sdcfimm), "NA (sys. missing)",
                                              paste0("Code ", sdcfimm)),
                               imm_label),
    res_label = dplyr::if_else(is.na(res_label),
                               dplyr::if_else(is.na(sdcgres), "NA (sys. missing)",
                                              paste0("Code ", sdcgres)),
                               res_label)
  ) %>%
  dplyr::count(imm_label, res_label, name = "n") %>%
  dplyr::mutate(pct_total = n / sum(n))

# Print frequency tables
cat("\n===  Pre-Ellis: raw SDCGRES codes  ===\n")
dist_pre_gres %>%
  dplyr::mutate(pct = scales::percent(pct, accuracy = 0.1)) %>%
  print()

cat("\n===  Pre-Ellis: raw SDCFIMM codes  ===\n")
dist_pre_imm %>%
  dplyr::mutate(pct = scales::percent(pct, accuracy = 0.1)) %>%
  print()

cat("\n===  Pre-Ellis: joint SDCFIMM x SDCGRES  ===\n")
dist_joint %>%
  dplyr::mutate(pct_total = scales::percent(pct_total, accuracy = 0.1)) %>%
  print()

cat("\n===  Post-Ellis: immigration_status  ===\n")
dist_post %>%
  dplyr::select(label, n, pct) %>%
  dplyr::mutate(pct = scales::percent(pct, accuracy = 0.1)) %>%
  print()

# ---- helper: marginal bar plot ----------------------------------------------
plot_marginal <- function(dist_df, title_str, fill_col = "#4E79A7") {
  dist_df %>%
    dplyr::mutate(
      lbl = paste0(dplyr::if_else(is.na(value), "NA", as.character(value)), ": ", label),
      lbl = forcats::fct_inorder(lbl)
    ) %>%
    ggplot2::ggplot(ggplot2::aes(x = lbl, y = n)) +
    ggplot2::geom_col(fill = fill_col) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(pct, accuracy = 0.1)),
      hjust = -0.1, size = 3
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(
      labels = scales::comma,
      expand = ggplot2::expansion(mult = c(0, 0.15))
    ) +
    ggplot2::labs(
      title    = title_str,
      subtitle = "Pooled CCHS 2010 + 2014 Ferry output; labels from codebook-value-labels.csv",
      x        = NULL,
      y        = "Count (unweighted)"
    ) +
    ggplot2::theme_bw(base_size = 12)
}

# ---- plot-pre-ellis ----------------------------------------------------------
g_pre_gres <- plot_marginal(dist_pre_gres, "SDCGRES — Raw distribution (pre-Ellis)")
print(g_pre_gres)

# ---- plot-sdcfimm ------------------------------------------------------------
g_pre_imm <- plot_marginal(dist_pre_imm, "SDCFIMM (Immigrant flag) — Raw distribution (pre-Ellis)",
                           fill_col = "#59A14F")
print(g_pre_imm)

# ---- plot-joint --------------------------------------------------------------
# Tile heatmap: SDCFIMM (rows) × SDCGRES (cols), cell = % of total sample
g_joint <- dist_joint %>%
  dplyr::mutate(
    imm_label = forcats::fct_rev(forcats::fct_inorder(imm_label)),
    res_label = forcats::fct_inorder(res_label)
  ) %>%
  ggplot2::ggplot(ggplot2::aes(x = res_label, y = imm_label)) +
  ggplot2::geom_tile(ggplot2::aes(fill = pct_total), colour = "white", linewidth = 0.5) +
  ggplot2::geom_text(
    ggplot2::aes(
      label = dplyr::if_else(n > 0,
                             paste0(scales::comma(n), "\n",
                                    scales::percent(pct_total, accuracy = 0.1)),
                             "")
    ),
    size = 2.8, lineheight = 1.1
  ) +
  ggplot2::scale_fill_gradient(low = "#f7fbff", high = "#2171b5",
                               labels = scales::percent_format(accuracy = 1),
                               name = "% of\ntotal sample") +
  ggplot2::labs(
    title    = "Joint distribution: SDCFIMM × SDCGRES (pre-Ellis, pooled Ferry)",
    subtitle = "Cell = unweighted count + % of pooled sample; NA = SPSS system missing",
    x        = "SDCGRES (length of time in Canada)",
    y        = "SDCFIMM (immigrant flag)"
  ) +
  ggplot2::theme_bw(base_size = 11) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(angle = 25, hjust = 1)
  )

print(g_joint)

# ---- plot-post-ellis ---------------------------------------------------------
g_post <- dist_post %>%
  dplyr::mutate(
    label = forcats::fct_reorder(label, n, .desc = FALSE)
  ) %>%
  ggplot2::ggplot(ggplot2::aes(x = label, y = n)) +
  ggplot2::geom_col(fill = "#F28E2B") +
  ggplot2::geom_text(
    ggplot2::aes(label = scales::percent(pct, accuracy = 0.1)),
    hjust = -0.1, size = 3
  ) +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(
    labels = scales::comma,
    expand = ggplot2::expansion(mult = c(0, 0.15))
  ) +
  ggplot2::labs(
    title    = "immigration_status — Distribution after Ellis transformation",
    subtitle = "cchs_analytic table; NA = codes 7/8/9 + missing code-6 respondents",
    x        = NULL,
    y        = "Count (unweighted)"
  ) +
  ggplot2::theme_bw(base_size = 12)

print(g_post)

# ---- plot-comparison ---------------------------------------------------------
# Side-by-side summary: what fraction of total sample each post-Ellis category
# represents (NA shown explicitly to surface the known code-6 gap)
dist_post_full <- ds_post %>%
  dplyr::mutate(
    !!VAR_ELLIS := dplyr::if_else(
      is.na(!!rlang::sym(VAR_ELLIS)), "(NA — not recoded)", as.character(!!rlang::sym(VAR_ELLIS))
    )
  ) %>%
  dplyr::count(!!rlang::sym(VAR_ELLIS), name = "n") %>%
  dplyr::rename(label = dplyr::all_of(VAR_ELLIS)) %>%
  dplyr::mutate(
    pct   = n / sum(n),
    label = forcats::fct_reorder(label, n, .desc = FALSE)
  )

g_compare <- dist_post_full %>%
  ggplot2::ggplot(ggplot2::aes(x = label, y = pct)) +
  ggplot2::geom_col(
    ggplot2::aes(fill = label == "(NA — not recoded)"),
    show.legend = FALSE
  ) +
  ggplot2::geom_text(
    ggplot2::aes(label = scales::percent(pct, accuracy = 0.1)),
    hjust = -0.1, size = 3
  ) +
  ggplot2::scale_fill_manual(values = c("FALSE" = "#76B7B2", "TRUE" = "#E15759")) +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(
    labels = scales::percent_format(accuracy = 1),
    expand = ggplot2::expansion(mult = c(0, 0.12))
  ) +
  ggplot2::labs(
    title    = "immigration_status — Share of analytic sample (post-Ellis)",
    subtitle = "Red = NA; investigate whether code 6 (Non-immigrant) is correctly captured",
    x        = NULL,
    y        = "% of analytic sample"
  ) +
  ggplot2::theme_bw(base_size = 12)

print(g_compare)

cat("\nDone. Check printed tables and three plots above.\n")
