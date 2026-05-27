source("lib/ckan_helpers.R")


# Request log -------------------------------------------------------------

request_log <- tribble(
  ~time, 
  ~request_number, 
  ~offset,
  ~processed,
  ~updated,
  ~skipped,
  ~failed,
  ~response_time_seconds
)


# CKAN API call -----------------------------------------------------------

sync_usage_data <- function(offset = 0, limit = 20) {
  
  # Generic CKAN action helper
  response <- ckan_action(
    "yukon_matomo_sync_usage_data",
    body = list(
      limit = limit,
      offset = offset
    )
  )
  
  response
  
}

sync_all_usage_data <- function(starting_offset = 0) {
  
  has_more <- TRUE
  test_iteration_limit <- 200
  iteration <- 0
  next_offset <- starting_offset
  
  while(has_more == TRUE & iteration < test_iteration_limit) {
    
    add_log_entry("Request ", iteration, " starting at ", next_offset)
    
    request_start_time <- now()
    
    response <- jsonlite::fromJSON(sync_usage_data(next_offset))
    
    request_end_time <- now()
    response_time_seconds <- round(time_length(interval(request_start_time, request_end_time), "seconds"), digits = 2)
    
    add_log_entry(
      "  Processed ", 
      response$result$processed, 
      ". Updated ", 
      response$result$updated,
      ". Skipped ", 
      response$result$skipped,
      ". Failed ", 
      response$result$failed,
      "."
      )
    
    
    request_log <<- request_log |>
      bind_rows(
        tibble_row(
          time = now(),
          request_number = iteration,
          offset = next_offset,
          processed = response$result$processed,
          updated = response$result$updated,
          skipped = response$result$skipped,
          failed = response$result$failed,
          response_time_seconds = response_time_seconds
        )
      )
    
    # Determine whether to run again based on the previous response:
    next_offset <- response$result$next_offset
    has_more <- response$result$has_more
    
    iteration <- iteration + 1
    
    Sys.sleep(10)
    
  }
  
}


sync_all_usage_data()


# Export the run log ------------------------------------------------------

# End time logging --------------------------------------------------------

run_end_time <- now()
add_log_entry("End time was: ", run_end_time)
add_log_entry("Run duration: ", round(time_length(interval(run_start_time, run_end_time), "minutes"), digits = 2), " minutes")

run_log |> write_csv("log/run_log.csv")
request_log |> write_csv("log/request_log.csv")
# run_log |> View()
