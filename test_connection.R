source("lib/ckan_helpers.R")

# Cheap, side-effect-free checks before trusting a full sync run:
# 1. Does the token authenticate at all, and as a sysadmin?
# 2. Does the yukon_matomo_sync_usage_data action authorize for this token?
# (CKAN runs authorization before the action body executes, so a dry_run
# failure here means nothing gets touched.)

ckan_username <- Sys.getenv("ckan_username")

if (ckan_username != "") {
  user_res <- jsonlite::fromJSON(ckan_action("user_show", query = list(id = ckan_username), verb = "GET"))
  add_log_entry("user_show for '", ckan_username, "' succeeded. sysadmin = ", isTRUE(user_res$result$sysadmin))
} else {
  add_log_entry("ckan_username not set; skipping user_show sysadmin check.")
}

action_res <- jsonlite::fromJSON(ckan_action(
  "yukon_matomo_sync_usage_data",
  body = list(limit = 1, offset = 0, dry_run = TRUE)
))

add_log_entry("yukon_matomo_sync_usage_data dry_run succeeded against ", ckan_url)
print(action_res$result)
