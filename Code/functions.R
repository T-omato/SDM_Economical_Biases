# Load libraries
library(tidycensus)
library(tidyverse)
library(sf)
library(ggplot2)
library(scales)
library(patchwork)
library(colorspace)
library(RColorBrewer)
library(biscale)

load_income_and_obs_data <- function(api_key,
                                     divshift_path,
                                     acs_year = 2022,
                                     acs_variable = "B19013_001") {
  
  # Set Census API key
  census_api_key(api_key, install = TRUE)
  readRenviron("~/.Renviron")
  
  # Load ACS variable metadata (optional)
  load_variables(acs_year, "acs5", cache = TRUE)
  
  # Download ACS median income data (with geometry)
  income_data <- get_acs(
    geography = "block group",
    variables = acs_variable,
    state = "CA",
    year = acs_year,
    geometry = TRUE,
    survey = "acs5"
  )
  
  # Load and transform DivShift observations
  df_ca <- read.csv(file.path(divshift_path, "filtered_results_California.csv")) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
    st_transform(crs = st_crs(income_data))
  
  # Join observations to census block groups
  joined <- st_join(df_ca, income_data %>% select(GEOID))
  obs_density <- joined %>%
    st_drop_geometry() %>%
    count(GEOID, name = "n_obs")
  
  # Parse NAME into separate fields
  new_income_data <- income_data %>%
    separate(NAME, into = c("block_group", "tract", "county", "state"),
             sep = "; ", remove = FALSE)
  
  # Return list of cleaned outputs
  list(
    income_data = income_data,
    df_ca = df_ca,
    obs_density = obs_density,
    new_income_data = new_income_data
  )
}