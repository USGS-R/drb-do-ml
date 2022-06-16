library(targets)

Sys.setenv(
           AWS_PROFILE = "default",
           AWS_REGION = 'us-west-2'
               )

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate","rmarkdown","dataRetrieval",
                            "knitr","leaflet","sf","sbtools","ggplot2",
                            "streamMetabolizer"),
               resources = tar_resources(
                             aws = tar_resources_aws(bucket = "drb-do")))

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
dir.create("3_visualize/log/", showWarnings = FALSE)

# Define columns of interest from harmonized WQP data
wqp_vars_select <- c("MonitoringLocationIdentifier","MonitoringLocationName","LongitudeMeasure","LatitudeMeasure",
                     "MonitoringLocationTypeName","OrganizationIdentifier","ActivityStartDate","ActivityStartTime.Time",
                     "ActivityEndDate","CharacteristicName","param_group","param","USGSPCode","ActivityMediaName",
                     "ResultSampleFractionText","HydrologicCondition","HydrologicEvent","resultVal2","resultUnits2",
                     "ResultDetectionConditionText","ResultTemperatureBasisText","PrecisionValue","ResultStatusIdentifier",
                     "final")

# Define WQP CharacteristicNames of interest
# others: "Dissolved oxygen saturation, field, max","Dissolved oxygen saturation, field, min","Dissolved oxygen, field, max","Dissolved oxygen, field, min")
CharNames_select = c("Dissolved oxygen (DO)","Dissolved oxygen saturation")
params_select = c("Dissolved oxygen","Dissolved oxygen saturation","Dissolved oxygen saturation, field",
                  "Dissolved oxygen, field","Dissolved oxygen, field, mean")

# Define DO units of interest
units_select = c("mg/l")

# Define hydrologic event types in harmonized WQP data to exclude
omit_wqp_events <- c("Spill","Volcanic action")

# Define USGS parameter codes
pcode_select <- c("00300") 

# Define minor HUCs (hydrologic unit codes) that make up the DRB
# Lower Delaware: 020402 accounting code 
drb_huc8s <- c("02040201","02040202","02040203","02040204","02040205","02040206","02040207")

# Define USGS site types for which to download NWIS data (https://maps.waterdata.usgs.gov/mapper/help/sitetype.html)
site_tp_select <- c("ST","ST-CA","SP") 

# Omit undesired sites
# sites 01412350, 01484272 coded as site type "ST" but appear to be tidally-influenced
omit_nwis_sites <- c("01412350","01484272", "01477050", "01467200", "014670261", "01464600")

# Define USGS stat codes for continuous sites that only report daily statistics (https://help.waterdata.usgs.gov/stat_code) 
stat_cd_select <- c("00001","00002","00003")

# Define earliest startDate for NWIS data retrievals
earliest_date <- "1979-10-01"

# Change dummy date to force re-build of NWIS DO sites and data download
dummy_date <- "2021-12-19"

# test and validation sites
val_sites <- c("01472104", "01473500", "01481500")
tst_sites <- c("01475530", "01475548")

train_start_date <- '1980-01-01'
train_end_date <- '2017-01-01'
val_start_date <- '2017-01-01'
val_end_date <- '2019-01-01'
test_start_date <- '2019-01-01'
test_end_date <- '2022-01-01'

# Return the complete list of targets
c(p1_targets_list, p2_targets_list, p2a_targets_list, p3_targets_list)

