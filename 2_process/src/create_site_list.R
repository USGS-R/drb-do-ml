create_site_list <- function(wqp_data,nwis_sites,nwis_daily_data,nwis_inst_data,hucs,crs_out="NAD83"){
  #' 
  #' @description Function to create one site list that contains unique site locations for modeling
  #'
  #' @param wqp_data data frame containing filtered data from the DRB harmonized water quality dataset for discrete samples.
  #' wqp_data must contain the following columns: c("LatitudeMeasure","LongitudeMeasure","ActivityStartDate","MonitoringLocationIdentifier",
  #' "MonitoringLocationName","OrganizationIdentifier")
  #' @param nwis_sites data frame containing all NWIS continuous sites identified
  #' @param nwis_daily_data data frame containing daily data for all NWIS daily sites
  #' @param nwis_inst_data data frame containing instantaneous data for all NWIS instantaneous sites
  #' @param crs_out character string indicating desired crs. Defaults to "NAD83", other options include "WGS84".
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
  wqp_retrieved_sites <- dataRetrieval::whatWQPsites(huc = hucs)
  
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
  
  # Clean up different coordinate reference systems within unique_sites data frame
  unique_sites_out <- unique_sites %>%
    split(.,.$datum) %>% 
    lapply(.,transform_site_locations,crs_out=crs_out) %>%
    do.call(rbind,.)
  
  
  return(unique_sites_out)
}


transform_site_locations <- function(site_list_df,crs_out){
  #' 
  #' @description Function to transform site locations to a consistent coordinate reference system
  #'
  #' @param site_list_df data frame containing site locations with a consistent crs
  #' @param crs_out character string indicating desired crs to transform spatial coordinates. Options include "NAD83" or "WGS84"
  #' 
  #' @examples 
  #' transform_site_locations(site_list,4326)
  
  # I'm getting some odd errors with sf::st_coordinates() if site_list_df is of class "grouped_df"
  x <- ungroup(site_list_df)
  
  # define input and output epsg codes
  # assume unknown crs (datum = "UNKNWN") are equal to wgs84:
  epsg_in <- case_when(x$datum[1] == "NAD83" ~ 4269,
                       x$datum[1] == "WGS84" ~ 4326,
                       x$datum[1] == "NAD27" ~ 4267,
                       x$datum[1] == "UNKWN" ~ 4326)
  
  epsg_out <- case_when(crs_out == "NAD83" ~ 4269,
                        crs_out == "WGS84" ~ 4326)
  
  # convert data frame to spatial object and transform to user-specified crs:
  if(!is.na(epsg_in)){
    site_list_transformed <- sf::st_as_sf(x,coords=c("lon","lat"),crs=epsg_in) %>%
      sf::st_transform(epsg_out) %>%
      mutate(lon_new = sf::st_coordinates(.)[,1],
             lat_new = sf::st_coordinates(.)[,2],
             datum_new = crs_out) %>%
      sf::st_drop_geometry() %>%
      select(site_id,site_name,count_days_nwis,count_days_discrete,count_days_total,lon_new,lat_new,datum_new,
             org_id,data_src_combined) %>%
      rename("lon"="lon_new","lat"="lat_new","datum"="datum_new")
    
  } else {
    site_list_transformed <- site_list_df
  }
  
  return(site_list_transformed) 
  
}
