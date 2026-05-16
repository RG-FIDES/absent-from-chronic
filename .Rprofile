# Increase languageserver subprocess wait timeout (default ~120s is too short for large renv libraries).
# languageserver reads this option when calling callr::r_session$new(wait_timeout = ...).
options(languageserver.server_timeout = 300)

# Reduce renv startup overhead (suppress status messages that add initialization time).
options(renv.config.startup.quiet = TRUE)

source("renv/activate.R")
