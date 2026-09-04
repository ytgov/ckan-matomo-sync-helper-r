library(tidyverse)
library(fs)
library(readxl)
library(rmarkdown)
library(janitor)
library(ckanr)
library(lubridate)
library(DescTools)

# The list of libraries above could be shortened; we're not going for efficiency here. :P 

# Logging helper ----------------------------------------------------------

run_log <- tribble(
  ~time, ~message
)

# Logging helper function
add_log_entry <- function(...) {
  
  log_text <- str_c(...)
  
  new_row = tibble_row(
    time = now(),
    message = log_text
  )
  
  run_log <<- run_log |>
    bind_rows(
      new_row
    )
  
  cat(log_text, "\n")
}

run_start_time <- now()
add_log_entry(str_c("Start time was: ", run_start_time))

# Credentials come from the process environment. Locally/RStudio, that means
# a gitignored .env file read via readRenviron(). In Docker, ckan_url and
# ckan_api_token are injected directly by the container runtime (e.g.
# `docker run --env-file`, compose `env_file:`/`environment:`, or a secrets
# manager) -- no .env file is ever baked into the image or needs to exist
# inside the container.
if(Sys.getenv("ckan_url") == "" && file_exists(".env")) {
  readRenviron(".env")
}

# Docker's --env-file / compose env_file (unlike R's readRenviron) does not
# strip surrounding quotes, so a value copied straight out of .env.example
# (e.g. ckan_url="https://open.yukon.ca/") arrives as a literal string with
# quote characters in it when injected that way. Strip them defensively so
# the same .env file works unmodified for both local/RStudio and Docker use.
strip_quotes <- function(x) gsub('^[\'"]|[\'"]$', "", x)

ckan_url <- Sys.getenv("ckan_url") |> strip_quotes()
ckan_api_token <- Sys.getenv("ckan_api_token") |> strip_quotes()

if(ckan_url == "" || ckan_api_token == "") {
  stop("ckan_url / ckan_api_token are not set. Provide a .env file (local/RStudio use) or inject them as environment variables (container use).")
}

ckanr_setup(
  url = ckan_url,
  key = ckan_api_token
)

add_log_entry("Using server ", ckan_url)


