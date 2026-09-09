source("lib/ckan_helpers.R")


# Tunables ------------------------------------------------------------------

batch_limit <- 20
request_sleep_seconds <- 5
iteration_limit <- 200

# Retry tuning: the CKAN/Matomo backend occasionally returns a transient
# 500 for a single batch. Retry that batch up to retry_max_attempts times
# (with a short delay between attempts) before giving up on it and moving
# on to the next offset. If max_consecutive_batch_failures batches in a row
# each exhaust their retries, further requests are almost certainly futile
# (e.g. the backend is down), so the run aborts instead of grinding through
# the remaining iterations.
retry_max_attempts <- 3
retry_delay_seconds <- 5
max_consecutive_batch_failures <- 3


# Request log -------------------------------------------------------------

request_log <- tribble(
  ~time,
  ~request_number,
  ~offset,
  ~processed,
  ~updated,
  ~skipped,
  ~failed,
  ~response_time_seconds,
  ~status,
  ~attempts
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

# Retries a single batch request up to max_attempts times, logging and
# sleeping between failed attempts. Returns a list with `ok`, and either
# the parsed `response` (ok = TRUE) or the last `error` (ok = FALSE),
# plus how many `attempts` it took.
sync_usage_data_with_retry <- function(offset, limit, max_attempts, delay_seconds) {

  for (attempt in seq_len(max_attempts)) {

    attempt_result <- tryCatch(
      list(ok = TRUE, response = jsonlite::fromJSON(sync_usage_data(offset, limit))),
      error = function(e) list(ok = FALSE, error = e)
    )

    if (attempt_result$ok) {
      return(c(attempt_result, attempts = attempt))
    }

    add_log_entry(
      "  Attempt ", attempt, "/", max_attempts,
      " failed at offset ", offset, ": ", conditionMessage(attempt_result$error)
    )

    if (attempt < max_attempts) {
      Sys.sleep(delay_seconds)
    }

  }

  c(attempt_result, attempts = max_attempts)

}

sync_all_usage_data <- function(starting_offset = 0) {

  has_more <- TRUE
  iteration <- 0
  next_offset <- starting_offset
  consecutive_batch_failures <- 0
  aborted <- FALSE

  while(has_more == TRUE & iteration < iteration_limit) {

    add_log_entry("Request ", iteration, " starting at ", next_offset)

    request_start_time <- now()

    result <- sync_usage_data_with_retry(next_offset, batch_limit, retry_max_attempts, retry_delay_seconds)

    request_end_time <- now()
    response_time_seconds <- round(time_length(interval(request_start_time, request_end_time), "seconds"), digits = 2)

    if (result$ok) {

      consecutive_batch_failures <- 0
      response <- result$response

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
            response_time_seconds = response_time_seconds,
            status = "success",
            attempts = result$attempts
          )
        )

      # Determine whether to run again based on the previous response:
      next_offset <- response$result$next_offset
      has_more <- response$result$has_more

    } else {

      consecutive_batch_failures <- consecutive_batch_failures + 1

      add_log_entry(
        "  Batch at offset ", next_offset, " gave up after ", result$attempts,
        " attempts (", consecutive_batch_failures, " consecutive batch failures): ",
        conditionMessage(result$error)
      )

      request_log <<- request_log |>
        bind_rows(
          tibble_row(
            time = now(),
            request_number = iteration,
            offset = next_offset,
            processed = NA_integer_,
            updated = NA_integer_,
            skipped = NA_integer_,
            failed = NA_integer_,
            response_time_seconds = response_time_seconds,
            status = "failed",
            attempts = result$attempts
          )
        )

      if (consecutive_batch_failures >= max_consecutive_batch_failures) {
        add_log_entry(
          "  Aborting: ", max_consecutive_batch_failures,
          " consecutive batches failed after ", retry_max_attempts, " attempts each."
        )
        aborted <- TRUE
        break
      }

      # The failed request never told us next_offset/has_more, so step
      # forward by one batch manually rather than retrying the same offset
      # forever.
      next_offset <- next_offset + batch_limit
      has_more <- TRUE

    }

    iteration <- iteration + 1

    Sys.sleep(request_sleep_seconds)

  }

  list(aborted = aborted)

}


sync_result <- sync_all_usage_data()


# Export the run log ------------------------------------------------------

# End time logging --------------------------------------------------------

run_end_time <- now()
add_log_entry("End time was: ", run_end_time)
add_log_entry("Run duration: ", round(time_length(interval(run_start_time, run_end_time), "minutes"), digits = 2), " minutes")

run_log |> write_csv("log/run_log.csv")
request_log |> write_csv("log/request_log.csv")
# run_log |> View()

if (sync_result$aborted) {
  stop("Sync run aborted after repeated consecutive batch failures; see log above and log/request_log.csv.")
}
