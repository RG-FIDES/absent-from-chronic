# Purpose: Copy redirected EDA HTML and required EDA-3 figure assets into _site.
# Registered as: post-render
# Why needed: REDIRECT page targets and figure links originate outside edited_content.

suppressWarnings({
  base_dir <- normalizePath('.', winslash = '/', mustWork = TRUE)
  repo_root <- normalizePath(file.path(base_dir, '..'), winslash = '/', mustWork = TRUE)

  source_html <- file.path(repo_root, 'analysis', 'eda-3', 'eda-3.html')
  target_html_dir <- file.path(base_dir, '_site', 'edited_content', 'analysis')
  target_html <- file.path(target_html_dir, 'eda-3.html')

  dir.create(target_html_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(source_html)) {
    file.copy(source_html, target_html, overwrite = TRUE)
  }

  source_fig_dir <- file.path(repo_root, 'analysis', 'eda-3', 'figure-png-iso')
  target_fig_dir <- file.path(base_dir, '_site', 'analysis', 'eda-3', 'figure-png-iso')

  if (dir.exists(source_fig_dir)) {
    dir.create(target_fig_dir, recursive = TRUE, showWarnings = FALSE)
    figs <- list.files(source_fig_dir, pattern = '\\.png$', full.names = TRUE)
    if (length(figs) > 0) {
      file.copy(figs, target_fig_dir, overwrite = TRUE)
    }
  }
})
