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

if(file_exists(".env")) {
  readRenviron(".env")
  
  ckan_url <- Sys.getenv("ckan_url")
  
  ckanr_setup(
    url = ckan_url, 
    key = Sys.getenv("ckan_api_token")
  )
  
  add_log_entry("Using server ", ckan_url)
  
} else {
  stop("No .env file found, create it before running this script.")
}


