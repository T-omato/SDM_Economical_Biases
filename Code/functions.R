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
library(patchwork)
library(tigris)

load_income_and_obs_data <- function(api_key,
                                     divshift_path,
                                     acs_year = 2022,
                                     acs_variable = "B19013_001") {
  ###################
  # Set Census API key
  census_api_key(api_key, install = TRUE, overwrite = TRUE)
  #readRenviron("~/.Renviron")
  
  
  ###################
  # Download ACS Data for Median Household Income in the Past 12 Months (in Inflation-Adjusted Dollars)
  ###################
  
  # Download ACS median income data at the block level to analyze individual household income
  income_data <- get_acs(
    geography = "block group",
    variables = acs_variable,
    state = "CA",
    year = acs_year,
    geometry = TRUE,
    survey = "acs5"
  ) %>%
    separate(NAME, into = c("block_group", "tract", "county", "state"),
             sep = "; ", remove = FALSE)

  #Download ACS median income data at the county level to compare individual household income to county levels
  AMI_data <- get_acs(
    geography = "county",  
    variables = acs_variable,
    state = "CA",
    year = 2022,
    geometry = TRUE,
    survey = "acs5"
  ) %>%
    separate(NAME, 
             into = c("county", "state"),
             sep = ", ",
             remove = F) 
  
  AMI <- AMI_data %>%
    st_drop_geometry() %>%
    select(county, AMI_estimate = estimate)
  
  ###################
  # Load and Project DivShift Data
  ###################
  
  # Load and transform DivShift observations
  df_ca <- read.csv(file.path(divshift_path, "filtered_results_California.csv")) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
    st_transform(crs = st_crs(income_data))

  ###################
  # Join Observations to Block Groups, Count Density
  ###################
    
  # Join observations from df_ca to census block groups from income_data using unique ID (GEOID)
  # GEOID column from income_data allows to know which block group each point falls into.
  # Label each df_ca observation with the GEOID of each block group
  joined <- st_join(df_ca, income_data %>% select(GEOID))
  
  # Count how many points fall within each GEOID.
  obs_density <- joined %>%
    st_drop_geometry() %>%
    count(GEOID, name = "n_obs")
  
  ###################
  # Classify Income by Area Median Income (AMI)
  ###################
  
  # Merge block group income with county AMI
  
  classified_income <- income_data %>%
    # Join the county level value to each block group's according county 
    # left_join instead of inner_join to add NA where no matches found instead of dropping the row
    left_join(AMI, by = "county") %>%
    #Create new column for percentage of area median income (pct_ami)
    mutate(
      pct_ami = estimate / AMI_estimate,
      # Create qualitative categories defined by HUD based on how a block group's income compares to county AMI
      income_bracket = factor(case_when(
        is.na(estimate) ~ "No Income Data",
        pct_ami <= 0.30 ~ "Extremely Low",
        pct_ami <= 0.50 ~ "Very Low",
        pct_ami <= 0.80 ~ "Low",
        pct_ami <= 1.20 ~ "Moderate",
        pct_ami >  1.20 ~ "Above Moderate"
      ),
      levels = c(
        "Extremely Low",
        "Very Low",
        "Low",
        "Moderate",
        "Above Moderate",
        "No Income Data"
      ))
    )
  
  ################
  # Define Region by County (Colloquial Areas)
  ################
  
    
  region_map <- function(county) { # Region map is for colloquial areas
    case_when(
      county %in% c("San Francisco County", "San Mateo County", "Santa Clara County",
                    "Alameda County", "Contra Costa County", "Marin County",
                    "Napa County", "Solano County", "Sonoma County") ~ "Bay Area",
      county %in% c("Los Angeles County", "Orange County", "Riverside County",
                    "San Bernardino County", "Ventura County") ~ "Greater LA",
      county %in% c("El Dorado County", "Placer County", "Sacramento County", "Yolo County") ~ "Sacramento MSA",
      TRUE ~ "Other"
    )
  }
  
  classified_income$region <- region_map(classified_income$county)
  
  ################
  # Define MSA by Place (City-Level)
  ################
  
  ca_places <- places(state = "CA", cb = TRUE, year = 2022) %>%
    st_as_sf() %>%
    st_transform(crs = st_crs(classified_income))

  # Join places to both DivShift points and block groups
  df_ca_with_place <- st_join(df_ca, ca_places %>% select(PLACE_NAME = NAME))
  classified_income_with_place <- st_join(classified_income, ca_places %>% select(PLACE_NAME = NAME))
  
  city_to_msa <- function(city) {
    case_when(
      city %in% c("Los Angeles", "Long Beach", "Glendale") ~ "LA–Long Beach–Glendale",
      city %in% c("Santa Ana", "Irvine", "Anaheim") ~ "Anaheim–Santa Ana–Irvine",
      city %in% c("San Mateo", "Redwood City", "San Francisco") ~ "SF–San Mateo–Redwood City",
      city %in% c("Oakland", "Fremont", "Berkeley") ~ "Oakland-Fremont-Berkeley",
      city %in% c("San Rafael") ~ "San Rafael",
      TRUE ~ NA_character_
    )
  }
  
  df_ca_with_place$msa_city_region <- city_to_msa(df_ca_with_place$PLACE_NAME)
  classified_income_with_place$msa_city_region <- city_to_msa(classified_income_with_place$PLACE_NAME)
  
  
  ###################
  # Return Processed Data
  ###################
  return(list(
    income_data = income_data,
    AMI = AMI,
    df_ca = df_ca_with_place,  # With city + region tags
    obs_density = obs_density,
    classified_income = classified_income_with_place
  ))
}

## Plot functions

plot_block_groups <- function(data){
  # Plot all CA block groups shaded by income (optional)
  ggplot(data) +
    geom_sf(aes(fill = estimate), color = NA) +
    scale_fill_viridis_c(option = "magma", na.value = "gray90", name = "Median Income") +
    labs(
      title = "ACS Block Groups in California",
      subtitle = "Shaded by Median Household Income (2022)",
      caption = "Data: tidycensus ACS 5-Year Estimates"
    ) +
    theme_minimal()
}
plot_classified_income <- function(data){
  ggplot(data) +
    geom_sf(aes(fill = income_bracket), color = NA) +
    scale_fill_manual(
      values = c(
        "Extremely Low" = "#0571b0",
        "Very Low" = "#92c512",
        "Low" = "#bdbdbd",
        "Moderate" = "#f4a582",
        "Above Moderate" = "#ca0020",
        "No Income Data" = "black"
      ),
      name = "Income Category"
    ) +
    labs(
      title = "Household Income Brackets relative to AMI",
      subtitle = "California Block Groups (ACS 2022 + HCD AMI)",
      caption = "Income data: ACS 2022 | AMI: CA HCD 2022"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.caption = element_text(size = 9, face = "italic", hjust = 1)
    )
}
plot_observation_density <- function(data){
  
  # Join classified_income (with geometry) to observation counts
  map_data <- income_data %>%
    left_join(data, by = "GEOID") %>%
    mutate(n_obs = ifelse(is.na(n_obs), 0, n_obs)) %>%  # Set NA obs to 0
    mutate(log_obs = log10(n_obs + 1))
  
    ggplot(map_data) +
      geom_sf(aes(fill = log_obs), color = NA, size = 0) +
      scale_fill_viridis_c(
        name = "Log10(Observations + 1)",
        option = "mako",
        direction = 1,
        na.value = "red",
        breaks = c(0, 1, 2, 3, 4),
        labels = rev(c(0, 1, 2, 3, 4))  # Reverse the order of the labels
      ) +
    labs(
      title = "DivShift Observation Density by Census Block Group",
      subtitle = "Log-transformed count of DivShift records within ACS 2018–2022 block group boundaries",
      caption = "Data: DivShift (2022), ACS 5-Year Estimates (2018–2022)"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      plot.title = element_text(face = "bold"),
      axis.title = element_text(size = 10, margin = margin(t = 5, r = 5)),
      axis.text = element_text(size = 8),
      plot.caption = element_text(size = 8, hjust = 1, face = "italic"),
      legend.title = element_text(size = 9),
      legend.text = element_text(size = 8)
    ) 
}
bivariate_observation_income_map <- function(classified_data, 
                                             obs_data, 
                                             title = "Bivariate Map: Observation Density vs. Income", 
                                             subtitle = NULL,
                                             region_filter = NULL,
                                             msa_filter = NULL) {
  
  map_data <- classified_data
  
  # Apply region or MSA filters if provided
  if (!is.null(region_filter)) {
    map_data <- map_data %>% filter(region == region_filter)
  }
  if (!is.null(msa_filter)) {
    map_data <- map_data %>% filter(msa_city_region == msa_filter)
  }
  
  # Join observation counts by GEOID
  map_data <- map_data %>%
    left_join(obs_data, by = "GEOID") %>%
    mutate(
      n_obs = replace_na(n_obs, 0),
      log_obs = log1p(n_obs),
      income_bracket = case_when(
        is.na(estimate) & n_obs > 0 ~ "Natural Reserve",
        is.na(estimate) ~ "No Income Data",
        pct_ami <= 0.30 ~ "Extremely Low",
        pct_ami <= 0.50 ~ "Very Low",
        pct_ami <= 0.80 ~ "Low",
        pct_ami <= 1.20 ~ "Moderate",
        pct_ami >  1.20 ~ "Above Moderate"
      ),
      income_bracket = factor(
        income_bracket,
        levels = c(
          "Extremely Low", 
          "Very Low", 
          "Low", 
          "Moderate",
          "Above Moderate", 
          "Natural Reserve", 
          "No Income Data"
        )
      )
    )
  
  # Plot
  p <- ggplot(map_data) +
    geom_sf(aes(fill = log_obs, color = income_bracket), size = 0.05) +
    scale_fill_viridis_c(
      name = "Log(Observations + 1)",
      option = "mako",
      direction = 1,
      na.value = "gray90",
      limits = c(0, 4),
      oob = squish,
      breaks = c(0, 1, 2, 3, 4),
      labels = rev(c(0, 1, 2, 3, 4))
    ) +
    scale_color_manual(
      name = "Income Bracket",
      values = c(
        "Extremely Low"     = "#a233ff", 
        "Very Low"          = "#fd33ff", 
        "Low"               = "#fff333",  
        "Moderate"          = "#ffae33",  
        "Above Moderate"    = "#ff3345",  
        "Natural Reserve"   = "#006400",  
        "No Income Data"    = "gray60"
      ),
      guide = guide_legend(override.aes = list(fill = NA))
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      caption = "DivShift observations + ACS 2022"
    ) +
    theme_minimal(base_size = 10) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.caption = element_text(size = 8, face = "italic", hjust = 1),
      legend.position = "right"
    )
  
  return(p)
}
