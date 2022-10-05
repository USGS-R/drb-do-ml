library(targets)

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate", "rmarkdown", "knitr",
                            "dataRetrieval", "nhdplusTools", "sbtools",
                            "leaflet", "sf", "USAboundaries", "cowplot",
                            "ggspatial", "patchwork", "streamMetabolizer", 
                            "reticulate", "yaml"))

source("1_fetch.R")
source("2_process.R")
source("2a_model.R")
source("3_visualize.R")

dir.create("1_fetch/out/", showWarnings = FALSE)
dir.create("1_fetch/log/", showWarnings = FALSE)
dir.create("2_process/out/", showWarnings = FALSE)
dir.create("2a_model/out/", showWarnings = FALSE)
dir.create("2_process/log/", showWarnings = FALSE)
dir.create("3_visualize/out/", showWarnings = FALSE)
dir.create("3_visualize/out/nhdv2_attr_png/", showWarnings = FALSE)
dir.create("3_visualize/log/", showWarnings = FALSE)

# 1) Configure data pipeline inputs/variables

# Define columns of interest from harmonized WQP data
wqp_vars_select <- c("MonitoringLocationIdentifier", "MonitoringLocationName",
                     "LongitudeMeasure","LatitudeMeasure","MonitoringLocationTypeName",
                     "OrganizationIdentifier","ActivityStartDate","ActivityStartTime.Time",
                     "ActivityEndDate","CharacteristicName","param_group","param",
                     "USGSPCode","ActivityMediaName","ResultSampleFractionText",
                     "HydrologicCondition","HydrologicEvent","resultVal2","resultUnits2",
                     "ResultDetectionConditionText","ResultTemperatureBasisText",
                     "PrecisionValue","ResultStatusIdentifier","final")

# Define WQP CharacteristicNames of interest
# others: "Dissolved oxygen saturation, field, max", "Dissolved oxygen saturation, field, min", 
# "Dissolved oxygen, field, max", and "Dissolved oxygen, field, min")
CharNames_select = c("Dissolved oxygen (DO)","Dissolved oxygen saturation")
params_select = c("Dissolved oxygen","Dissolved oxygen saturation",
                  "Dissolved oxygen saturation, field", "Dissolved oxygen, field",
                  "Dissolved oxygen, field, mean")

# Define DO units of interest in WQP data
units_select = c("mg/l")

# Define hydrologic event types in harmonized WQP data to exclude
omit_wqp_events <- c("Spill","Volcanic action")

# Define USGS parameter codes of interest
# 00300 = "dissolved oxygen, in milligrams per liter"
pcode_select <- c("00300") 

# Define minor HUCs (hydrologic unit codes) that make up the DRB
# Lower Delaware: 020402 accounting code 
drb_huc8s <- c("02040201","02040202","02040203","02040204","02040205","02040206","02040207")

# Define USGS site types for which to download NWIS data 
# (https://maps.waterdata.usgs.gov/mapper/help/sitetype.html)
site_tp_select <- c("ST","ST-CA","SP") 

# Omit undesired sites
# sites 01412350, 01484272 coded as site type "ST" but appear to be tidally-influenced
omit_nwis_sites <- c("01412350","01484272", "01477050", "01467200", "014670261", "01464600")

# Define USGS stat codes for continuous sites that only report daily statistics 
# (https://help.waterdata.usgs.gov/stat_code) 
stat_cd_select <- c("00001","00002","00003")

# Define earliest startDate and latest endDate for NWIS data retrievals
earliest_date <- "1979-10-01"
latest_date <- "2021-12-31"

# What is the minimum number of unique observation-days a site should have
# to be considered "well-observed" and therefore, included in the model?
# Note that if min_obs_days is changed from 100 below, you may want to 
# reconsider the train/test model splits. 
min_obs_days <- 100

# Change dummy date to force re-build of NWIS DO sites and data download
dummy_date <- "2022-06-15"


#2) Configure model inputs/variables 

# Define test and validation sites
val_sites <- c("01472104", "01473500", "01481500")
tst_sites <- c("01475530", "01475548")

train_start_date <- '1980-01-01'
train_end_date <- '2014-10-01'
val_start_date <- '2014-10-01'
val_end_date <- '2015-10-01'
test_start_date <- '2015-10-01'
test_end_date <- '2022-10-01'

# Define model parameters and combine within a list that gets
# used to write a model config file that gets passed to the 
# snakemake modeling workflow.
base_config_options <- list(
  out_dir = "../../../out/models",
  # random seed for training; If FALSE, no seed. Otherwise, specify the seed:
  seed = FALSE,
  num_replicates = 1,
  trn_offset = 1,
  tst_val_offset = 1,
  epochs = 100,
  hidden_size = 10,
  dropout = 0.2,
  recurrent_dropout = 0.2,
  finetune_learning_rate = 0.01,
  early_stopping = FALSE,
  # train/val/test split information is defined above:
  val_sites = val_sites, 
  test_sites = tst_sites,
  train_start_date = train_start_date, 
  train_end_date = train_end_date, 
  val_start_date = val_start_date, 
  val_end_date = val_end_date,
  test_start_date = test_start_date, 
  test_end_date = test_end_date
  )

model_config_options <- list(
  x_vars = c("pr","SLOPE","tmmx","tmmn","srad","CAT_BASIN_SLOPE","CAT_ELEV_MEAN",
             "CAT_BASIN_AREA","CAT_IMPV11","CAT_CNPY11_BUFF100","CAT_TWI"),
  y_vars = c("do_min","do_mean","do_max"),
  lambdas = c(1,1,1)
)

# Return the complete list of targets
c(p1_targets_list, p2_targets_list, p2a_targets_list, p3_targets_list)

