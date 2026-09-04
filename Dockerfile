FROM rocker/tidyverse:4.5.1

# System deps: git is needed for remotes::install_github (ckanr dev build).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libgsl-dev \
    && rm -rf /var/lib/apt/lists/*

# ckan_action() requires the development version of ckanr (0.8.1+), not the
# CRAN release (0.7.0) -- see CLAUDE.md "Setup and running" step 4.
RUN install2.r --error --skipinstalled \
        fs \
        readxl \
        janitor \
        lubridate \
        DescTools \
        remotes \
    && Rscript -e 'remotes::install_github("ropensci/ckanr")'

WORKDIR /app

COPY lib/ ./lib/
COPY matomo_sync_usage_data.R test_connection.R ./
COPY ckan-matomo-sync-helper-r.Rproj ./

RUN mkdir -p log

# ckan_url / ckan_api_token are read from the container's environment
# (injected via `docker run --env-file` / compose `env_file:` / secrets),
# never from a .env file baked into the image. See lib/ckan_helpers.R.
CMD ["Rscript", "matomo_sync_usage_data.R"]
