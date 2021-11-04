library(targets)

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate","rmarkdown","dataRetrieval","knitr","leaflet","sf")) 

source("1_fetch.R")
source("2_process.R")
source("3_visualize.R")

dir.create("1_fetch/out/", showWarnings = FALSE)
dir.create("2_process/out/", showWarnings = FALSE)
dir.create("3_visualize/out/", showWarnings = FALSE)

# Define columns of interest for harmonized WQP data
select_wqp_vars <- c("MonitoringLocationIdentifier","MonitoringLocationName","LongitudeMeasure","LatitudeMeasure",
                     "MonitoringLocationTypeName","OrganizationIdentifier","ActivityStartDate","ActivityStartTime.Time",
                     "ActivityEndDate","CharacteristicName","param_group","param","USGSPCode","ActivityMediaName",
                     "ResultSampleFractionText","HydrologicCondition","HydrologicEvent","resultVal2","resultUnits2",
                     "ResultDetectionConditionText","ResultTemperatureBasisText","PrecisionValue","ResultStatusIdentifier",
                     "final")

# Define WQP CharacteristicNames of interest
CharNames_select = c("Dissolved oxygen (DO)","Dissolved oxygen saturation")
params_select = c("Dissolved oxygen","Dissolved oxygen saturation","Dissolved oxygen saturation, field",
                  "Dissolved oxygen, field","Dissolved oxygen, field, mean")
# others: "Dissolved oxygen saturation, field, max","Dissolved oxygen saturation, field, min","Dissolved oxygen, field, max","Dissolved oxygen, field, min")

# Define DO units of interest
units_select = c("mg/l")

# Define hydrologic event types in harmonized WQP data to exclude
omit_wqp_events <- c("Spill","Volcanic action")

# Define USGS dissolved oxygen parameter codes of interest
DO_pcodes <- c("00300") # other oxygen pcodes not of primary interest: c("00301","62971","72210","99977","99981","99985") 

# Define minor HUCs (hydrologic unit codes) that make up the DRB
drb_huc8s <- c("02040101","02040102","02040104","02040103","02040106","02040105",
               "02040203","02040201","02040202","02040205","02040206","02040207")

# Define USGS site types for which to download dissolved oxygen data (for now, we are interested in "Stream" and "Stream:Canal" sites)
site_tp_select <- c("ST","ST-CA") 


# Return the complete list of targets
c(p1_targets_list, p2_targets_list,p3_targets_list)

