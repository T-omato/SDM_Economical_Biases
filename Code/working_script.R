#I've created an R project within the virtual environment and call my functions fromt there
source("~CA_income_analysis/functions.R")

# Call ACS data and create working variables
data_out <- load_income_and_obs_data(
  api_key = "Use your key here",
  divshift_path = "~datasets--elenagsierra--DivShift-NAWC/snapshots/776597b7e97e19b4d27fedd3583046d2f2c53c1a"
)

# Access outputs

income_data = data_out$income_data
obs_density = data_out$obs_density
AMI = data_out$AMI
classified_income = data_out$classified_income 
df_ca = data_out$df_ca

# Visualize household income brackets relative to AMI per county
ACS_plot = plot_block_groups(income_data)
ACS_plot
#Visualize income classified as per HUD
classified_income_plot = plot_classified_income(classified_income)
classified_income_plot
# Visualize density of observations
observation_density_plot = plot_observation_density(obs_density)
observation_density_plot
# Visualize the differences in observations between income groups
bivar_plot = bivariate_observation_income_map(classified_income,
                                              obs_density,
                                              region_filter = NULL)
# Obsservation by income group in the bay area
bivar_plot_bay = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = "Bay Area",
  title = "Bivariate Map: Observation Density vs. Income - Bay Area"
)
# Obsservation by income group in the Greater LA area
bivar_plot_LA = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = "Greater LA",
  title = "Bivariate Map: Observation Density vs. Income - Greater LA"
)
# Obsservation by income group in the Sacramento MSA area
bivar_plot_SacramentoMSA = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = "Sacramento MSA",
  title = "Bivariate Map: Observation Density vs. Income - Sacramento MSA"
)

# Obsservation by income group in the different Metropolitan Divisions

# MD1 = Los Angeles–Long Beach–Glendale 
bivar_plot_MD1 = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = NULL,
  title = "Bivariate Map: Observation Density vs. Income",
  subtitle = "MSA : Los Angeles–Long Beach–Glendale",
  msa_filter = "LA–Long Beach–Glendale"
)

# MD2 = Anaheim–Santa Ana–Irvine
bivar_plot_MD2 = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = NULL,
  title = "Bivariate Map: Observation Density vs. Income",
  subtitle = "MSA :  Anaheim–Santa Ana–Irvine",
  msa_filter = "Anaheim–Santa Ana–Irvine"
)
# MD3 = SF–San Mateo–Redwood City
bivar_plot_MD3 = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = NULL,
  title = "Bivariate Map: Observation Density vs. Income",
  subtitle = "MSA : SF–San Mateo–Redwood City",
  msa_filter = "SF–San Mateo–Redwood City"
)
#MD4 = Oakland–Fremont–Berkeley
bivar_plot_MD4 = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = NULL,
  title = "Bivariate Map: Observation Density vs. Income",
  subtitle = "MSA : Oakland–Fremont–Berkeley",
  msa_filter = "Oakland–Fremont–Berkeley"
)
# MD5 = San Rafael
bivar_plot_MD5 = bivariate_observation_income_map(
  classified_income,
  obs_density,
  region_filter = NULL,
  title = "Bivariate Map: Observation Density vs. Income",
  subtitle = "MSA : San Rafael",
  msa_filter = "San Rafael"
)


