# Increase languageserver subprocess wait timeout (default ~120s is too short for large renv libraries).
# languageserver reads this option when calling callr::r_session$new(wait_timeout = ...).
options(languageserver.server_timeout = 300)

# Reduce renv startup overhead: suppress status messages and skip sync check.
# synchronized.check = FALSE skips the lockfile comparison that adds ~2s to startup,
# keeping total renv activation under callr's 3-second session wait_timeout.
options(
  renv.config.startup.quiet     = TRUE,
  renv.config.synchronized.check = FALSE
)

# Load VS Code R session helpers when available.
# Disabled due to PowerShell execution conflicts in R extension 2.8.8
# vscode_init <- file.path(
#   Sys.getenv(if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"),
#   ".vscode-R",
#   "init.R"
# )
#
# if (file.exists(vscode_init)) {
#   source(vscode_init)
# }

# Prefer httpgd pane plotting in interactive VS Code sessions.
if (interactive() && Sys.getenv("TERM_PROGRAM") == "vscode") {
  if (requireNamespace("httpgd", quietly = TRUE)) {
    options(vsc.plot = FALSE)
    options(device = function(...) {
      httpgd::hgd(silent = TRUE)
      .vsc.browser(httpgd::hgd_url(history = FALSE), viewer = "Beside")
    })
  }
}


source("renv/activate.R")
