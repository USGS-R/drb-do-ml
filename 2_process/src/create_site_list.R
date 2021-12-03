create_site_list <- function(wqp_data,ws_boundary,nwis_sites,nwis_daily_data,nwis_inst_data,fileout){
  #' 
  #' @description Function to create one site list that contains unique site locations for modeling
  #'
  #' @param wqp_data data frame containing filtered data from the DRB harmonized water quality dataset for discrete samples.
  #' wqp_data must contain the following columns: c("LatitudeMeasure","LongitudeMeasure","ActivityStartDate","MonitoringLocationIdentifier",
  #' "MonitoringLocationName","OrganizationIdentifier")
  #' @param ws_boundary an sf object representing the area of interest AOI (used to retrieve original data CRS information for WQP sites)
  #' @param nwis_sites data frame containing all NWIS continuous sites identified
  #' @param nwis_daily_data data frame containing daily data for all NWIS daily sites
  #' @param nwis_inst_data data frame containing instantaneous data for all NWIS instantaneous sites
  #' @param fileout file path and name for output data, including the file extension
  #'
  #' @value A data frame containing the id, name, data coverage, spatial coordinates, and data source for each unique data-site location.

  # Check for the following columns in the discrete WQP data
  req_cols <- c("LatitudeMeasure","LongitudeMeasure","ActivityStartDate","MonitoringLocationIdentifier","MonitoringLocationName",
                "OrganizationIdentifier")
  flag_cols <- req_cols[which(req_cols %in% names(wqp_data)=="FALSE")]
  if(length(flag_cols)>0) stop("WQP data is missing one or more required columns: LatitudeMeasure,LongitudeMeasure,ActivityStartDate,
                               MonitoringLocationIdentifier,MonitoringLocationName,OrganizationIdentifier")
  
  # For the discrete WQP data, fetch missing CRS information from WQP:
  wqp_retrieved_sites <- dataRetrieval::whatWQPsites(bBox = sf::st_bbox(ws_boundary))
  
  # For the discrete WQP data, filter unique site identifier, summarize number of observation-days, and harmonize column names  
  wqp_unique_sites <- wqp_data %>%
    group_by(MonitoringLocationIdentifier) %>%
    mutate(count_obs = n(),
           count_days = length(unique(ActivityStartDate))) %>%
    slice(1) %>%
    # append missing CRS information:
    left_join(.,wqp_retrieved_sites[,c("MonitoringLocationIdentifier","HorizontalCoordinateReferenceSystemDatumName")],
              by="MonitoringLocationIdentifier") %>%
    mutate(site_id = if(grepl("USGS",MonitoringLocationIdentifier)) substr(MonitoringLocationIdentifier, 6,100) else MonitoringLocationIdentifier) %>%
    ungroup() %>%
    select(site_id,MonitoringLocationName,count_days,LongitudeMeasure,LatitudeMeasure,
           HorizontalCoordinateReferenceSystemDatumName,OrganizationIdentifier) %>%
    rename("site_name" = "MonitoringLocationName","lon"="LongitudeMeasure","lat"="LatitudeMeasure",
           "datum" = "HorizontalCoordinateReferenceSystemDatumName",
           "org_id" = "OrganizationIdentifier","count_days_discrete" = "count_days") %>%
    mutate(data_src = "Harmonized_WQP_data") 
  
  # For NWIS sites, summarize number of observation-days and harmonize column names
  nwis_inst_sites <- nwis_inst_data %>%
    mutate(Date = lubridate::date(dateTime)) %>%
    group_by(site_no) %>% 
    summarize(count_obsdays=length(unique(Date))) %>%
    left_join(.,
              nwis_sites %>% group_by(site_no) %>% slice(1),
              by="site_no") %>%
    select(site_no,station_nm,count_obsdays,dec_long_va,dec_lat_va,dec_coord_datum_cd,agency_cd) %>%
    rename("site_id" = "site_no","site_name" = "station_nm","lon"="dec_long_va","lat"="dec_lat_va",
           "datum"="dec_coord_datum_cd","org_id"="agency_cd","count_days_nwis" = "count_obsdays") %>%
    mutate(data_src = "NWIS_instantaneous")
  
  nwis_daily_sites <- nwis_daily_data %>%
    group_by(site_no) %>%
    summarize(count_obsdays = length(unique(Date))) %>%
    left_join(.,
              nwis_sites %>% group_by(site_no) %>% slice(1),
              by="site_no") %>%
    select(site_no,station_nm,count_obsdays,dec_long_va,dec_lat_va,dec_coord_datum_cd,agency_cd) %>%
    rename("site_id" = "site_no","site_name" = "station_nm","lon"="dec_long_va","lat"="dec_lat_va",
           "datum"="dec_coord_datum_cd","org_id"="agency_cd","count_days_nwis" = "count_obsdays") %>%
    mutate(data_src = "NWIS_daily")
  
  # For NWIS sites, select nwis service containing more observation-days
  nwis_sites_combined <- bind_rows(nwis_inst_sites,nwis_daily_sites) %>%
    group_by(site_id) %>%
    arrange(desc(count_days_nwis)) %>%
    slice(1)
  
  # Combine WQP and NWIS data frames into a single site list
  unique_sites <- bind_rows(nwis_sites_combined,wqp_unique_sites) %>%
    select(site_id,site_name,count_days_nwis,count_days_discrete,lon,lat,datum,org_id,data_src) %>% 
    group_by(site_id) %>% 
    mutate(count_days_discrete_combined = sum(count_days_discrete,na.rm=TRUE),
           count_days_total_combined = sum(count_days_discrete,count_days_nwis,na.rm=TRUE),
           data_src_combined = paste(data_src, collapse = "/")) %>%
    slice(1) %>%
    select(site_id,site_name,count_days_nwis,count_days_discrete_combined,count_days_total_combined,lon,lat,datum,org_id,data_src_combined) %>%
    rename("count_days_discrete" = "count_days_discrete_combined",
           "count_days_total" = "count_days_total_combined")
  
  # Save site list
  write_csv(unique_sites, file = fileout)
  
  return(fileout)
  
}

