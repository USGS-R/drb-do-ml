filter_wqp_data <- function(data,params_select,units_select,select_wqp_vars,omit_wqp_events,fileout,exclude_tidal=TRUE){
  
  # params are values to keep from the param column of the harmonized wqp data
  # select_wqp_vars are columns of data to keep from the harmonized wqp data
  # omit_wqp_events are values to omit from HydrologicEvent column of the harmonized wqp data
  # exclude_tidal logical, defaults to TRUE. If TRUE, rows containing "tidal" within the MonitoringLocationTypeName column of the harmonized wqp data are omitted
  
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
  
  write_csv(data_subset, file = fileout)
  
  return(fileout)
  
}


