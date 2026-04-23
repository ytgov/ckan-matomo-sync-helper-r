source("lib/ckan_helpers.R")

sync_usage_data <- function(offset = 0, limit = 25) {
  
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
  test_iteration_limit <- 8
  iteration <- 0
  next_offset <- starting_offset
  
  while(has_more == TRUE & iteration < test_iteration_limit) {
    
    add_log_entry("Request ", iteration, " starting at ", next_offset)
    
    response <- jsonlite::fromJSON(sync_usage_data(next_offset))
    has_more <- response$result$has_more
    next_offset <- response$result$next_offset
    
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
    
    iteration <- iteration + 1
    
    Sys.sleep(2)
    
  }
  
}

# x <- sync_usage_data(0)
sync_all_usage_data()


# Export the run log ------------------------------------------------------

# End time logging --------------------------------------------------------

run_end_time <- now()
add_log_entry("End time was: ", run_end_time)
add_log_entry("Run duration: ", round(time_length(interval(run_start_time, run_end_time), "minutes"), digits = 2), " minutes")

run_log |> write_csv("log/run_log.csv")
# run_log |> View()
