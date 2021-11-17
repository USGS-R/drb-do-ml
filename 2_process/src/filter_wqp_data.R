filter_wqp_data <- function(data,params_select,units_select,select_wqp_vars,omit_wqp_events,exclude_tidal=TRUE){
  #' 
  #' @description Function to filter the DRB multisource surface-water-quality dataset for desired parameters, units, and variables  
  #'
  #' @param data a data frame containing the downloaded DRB multisource surface-water-quality dataset
  #' @param params_select a character vector containing the desired parameter values from the data column "param". 
  #' See Shoda et al. 2019 (https://doi.org/10.5066/P9PX8LZO) for more information.  
  #' @param units_select a character vector containing the desired parameter units
  #' @param select_wqp_vars a character vector indicating which data columns to retain from the DRB multisource dataset
  #' @param omit_wqp_events a character vector indicating which values to omit from the "HydrologicEvent" column within the DRB multisource dataset
  #' @param exclude_tidal logical, defaults to TRUE. If TRUE, rows containing "tidal" within the "MonitoringLocationTypeName" column of the
  #' DRB multisource dataset will be omitted. 
  #'
  #' @value A data frame containing discrete water quality samples from the Delaware River Basin for the parameters of interest
  #' @examples 
  #' filter_wqp_data(data = DRB_WQdata,params_select=c("Dissolved oxygen"),select_wqp_vars=c("MonitoringLocationIdentifier","MonitoringLocationName"),
  #' omit_wqp_events=c("Volcanic action"),fileout="./data/out/filtered_wqp_data.csv")

  data_subset <- data %>% filter(param %in% params_select,
                        # Filter for desired units:
                        resultUnits2==units_select,
                        # Filter for sites that have lat/lon:
                        (!is.na(LongitudeMeasure)),(!is.na(LatitudeMeasure)),
                        # Filter out any sediment samples and samples representing hydrologic events that are not of interest: 
                        ActivityMediaName!="Sediment",!(HydrologicEvent %in% omit_wqp_events),
                        # Filter out any samples from LocationType = ditch:
                        (is.na(MonitoringLocationTypeName)|MonitoringLocationTypeName != "Stream: Ditch"),
                        # Keep QA/QC'ed data deemed reliable:
                        final=="retain") %>%
    # Filter out any tidal samples if exclude_tidal = TRUE:
    {if(exclude_tidal==TRUE){
      filter(.,!grepl("tidal", MonitoringLocationTypeName,ignore.case = TRUE))
      } else {.}
    } %>% 
    select(all_of(select_wqp_vars))
  
  return(data_subset)
  
}


