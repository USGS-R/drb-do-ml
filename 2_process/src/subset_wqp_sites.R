subset_wqp_sites <- function(ws_boundary,wqp_data){
  #' 
  #' @description Function to subset discrete sample locations for the lower DRB
  #'
  #' @param ws_boundary sf object containing the watershed boundary of interest
  #' @param wqp_data a data frame containing discrete water quality data. Data frame must contain columns "LongitudeMeasure" and "LatitudeMeasure".
  #'
  #' @value Outputs a data frame containing the subset of discrete water quality data for which the point locations intersect the watershed of interest
  #' 
  # Create spatial objects and project data
  wqp_data_proj <- wqp_data %>% 
    mutate(lon = LongitudeMeasure,
           lat = LatitudeMeasure) %>%
    sf::st_as_sf(.,coords=c("lon","lat"),crs=4269) %>%
    sf::st_transform(5070)
  ws_boundary_proj <- ws_boundary %>%
    sf::st_as_sf() %>%
    sf::st_transform(5070)
  
  # Find point locations that intersect watershed boundary and subset
  wqp_data_subset <- wqp_data_proj %>%
    filter(st_intersects(geometry, ws_boundary_proj, sparse = FALSE)) %>% 
    st_drop_geometry()
  
  return(wqp_data_subset)
  
}
