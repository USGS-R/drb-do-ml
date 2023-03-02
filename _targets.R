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


# 1) CONFIGURE DATA PIPELINE INPUTS/VARIABLES

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
latest_date <- "2021-10-01"

# What is the minimum number of unique observation-days a site should have
# to be considered "well-observed" and therefore, included in the model?
# Note that if min_obs_days is changed from 100 below, you may want to 
# reconsider the train/test model splits. 
min_obs_days <- 100

# Change dummy date to force re-build of NWIS DO sites and data download
dummy_date <- "2023-03-02"


#2) CONFIGURE MODEL INPUTS/VARIABLES 

# Define test and validation sites
val_sites <- c("01472104", "01473500", "01481500")
tst_sites <- c("01475530", "01475548")

# Define train/val/test dates
train_start_date <- '1980-01-01'
train_end_date <- '2014-10-01'
val_start_date <- '2014-10-01'
val_end_date <- '2015-10-01'
test_start_date <- '2015-10-01'
test_end_date <- '2022-10-01'

# Define global model parameters for the "baseline" deep learning model
x_vars_global <- c("tmmn","tmmx","pr","srad","SLOPE","TOTDASQKM","CAT_BASIN_SLOPE",
                   "TOT_BASIN_SLOPE","CAT_ELEV_MEAN","CAT_RDX","CAT_BFI","CAT_EWT",
                   "CAT_TWI","CAT_PPT7100_ANN","TOT_PPT7100_ANN","CAT_RUN7100",
                   "CAT_CNPY11_BUFF100","CAT_IMPV11","TOT_IMPV11","CAT_NLCD11_wetland",
                   "TOT_NLCD11_wetland","CAT_SANDAVE","CAT_PERMAVE","TOT_PERMAVE",
                   "CAT_RFACT","CAT_WTDEP","TOT_WTDEP","CAT_NPDES_MAJ","CAT_NDAMS2010",
                   "CAT_NORM_STORAGE2010")

# Define model parameters and combine within a list that gets used to
# write a base model config file for the snakemake modeling workflow.
base_config_options <- list(
  out_dir = "../../../out/models",
  # random seed for training; If FALSE, no seed. Otherwise, specify the seed:
  seed = FALSE,
  num_replicates = 10,
  trn_offset = 1,
  tst_val_offset = 1,
  epochs = 100,
  hidden_size = 10,
  dropout = 0.2,
  recurrent_dropout = 0.2,
  finetune_learning_rate = 0.01,
  early_stopping = FALSE,
  # train/val/test split information is defined above:
  validation_sites = val_sites, 
  test_sites = tst_sites,
  train_start_date = train_start_date, 
  train_end_date = train_end_date, 
  val_start_date = val_start_date, 
  val_end_date = val_end_date,
  test_start_date = test_start_date, 
  test_end_date = test_end_date,
  x_vars = x_vars_global
  )

# Configure individual models. If different x_vars are desired, add
# `x_vars = [vector of attribute names]` to any of the config options
# lists below, which will override `x_vars_global` in `base_config_options`.

# Model 0: Create a list that contains inputs for the "baseline" deep learning model.
model_config_options <- list(
  y_vars = c("do_min","do_mean","do_max"),
  lambdas = c(1,1,1)
)

# Model 1: Create a list that contains inputs for the metab_multitask model
metab_multitask_config_options <- list(
  y_vars = c("do_min","do_mean","do_max","GPP","ER","K600","depth","temp.water"),
  lambdas = c(1, 1, 1, 1, 1, 1, 1, 1)
)

# Model 1a: Create a list that contains inputs for the 1a_metab_multitask model
metab_1a_multitask_config_options <- list(
  y_vars = c("do_min","do_mean","do_max","GPP","ER","K600","depth","temp.water"),
  lambdas = c(1, 1, 1, 1, 1, 0, 0, 0)
)

# Model 1b: Create a list that contains inputs for the 1b_metab_multitask model
metab_1b_multitask_config_options <- list(
  y_vars = c("do_min","do_mean","do_max","GPP","ER","K600","depth","temp.water"),
  lambdas = c(1, 1, 1, 1, 0, 0, 0, 0)
)

# Model 2: Create a list that contains inputs for the metab_dense model
multitask_dense_config_options <- list(
  y_vars = c("do_min","do_mean","do_max","GPP","ER","K600","depth","temp.water"),
  lambdas = c(1, 1, 1, 1, 1, 1, 1, 1)
)


# Return the complete list of targets
c(p1_targets_list, p2_targets_list, p2a_targets_list, p3_targets_list)

