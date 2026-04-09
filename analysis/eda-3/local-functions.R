# local-functions.R
# Analysis-specific helper functions for EDA-3.

# Weighted quantile using cumulative normalized weights
weighted_quantile <- function(x, w, probs = c(0.25, 0.5, 0.75)) {
	keep <- !is.na(x) & !is.na(w) & w > 0
	x <- x[keep]
	w <- w[keep]

	if (length(x) == 0 || sum(w) <= 0) {
		out <- rep(NA_real_, length(probs))
		names(out) <- paste0("q", probs * 100)
		return(out)
	}

	ord <- order(x)
	x <- x[ord]
	w <- w[ord]
	cw <- cumsum(w) / sum(w)

	q <- vapply(probs, function(p) {
		idx <- which(cw >= p)[1]
		x[idx]
	}, numeric(1))

	names(q) <- paste0("q", probs * 100)
	q
}

# Weighted moments with Kish effective sample size for SE(mean)
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

summarize_outcome_stats <- function(data, outcome_col, weight_col = "wts_m_pooled", outcome_label = NULL) {
	if (is.null(outcome_label)) outcome_label <- outcome_col

	x <- data[[outcome_col]]
	w <- data[[weight_col]]

	moms <- weighted_moments(x, w)
	qs <- weighted_quantile(x, w, probs = c(0.25, 0.5, 0.75))

	keep <- !is.na(x) & !is.na(w) & w > 0
	x2 <- x[keep]
	w2 <- w[keep]

	zero_unweighted_n <- sum(x2 == 0)
	zero_weighted_prop <- if (length(x2) > 0 && sum(w2) > 0) {
		sum(w2[x2 == 0]) / sum(w2)
	} else {
		NA_real_
	}

	tibble::tibble(
		outcome = outcome_label,
		n_obs_non_missing = moms$n_obs,
		weighted_mean = moms$mean_w,
		weighted_se_mean = moms$se_mean_w,
		weighted_q1 = qs[["q25"]],
		weighted_median = qs[["q50"]],
		weighted_q3 = qs[["q75"]],
		weighted_variance = moms$var_w,
		weighted_sd = moms$sd_w,
		zero_frequency_unweighted = zero_unweighted_n,
		zero_proportion_weighted = zero_weighted_prop,
		maximum_value = if (length(x2) > 0) max(x2) else NA_real_,
		pearson_dispersion = if (!is.na(moms$mean_w) && moms$mean_w > 0) moms$var_w / moms$mean_w else NA_real_,
		effective_n = moms$n_eff
	)
}
