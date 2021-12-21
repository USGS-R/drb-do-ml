#' original author: David Watkins
#' from https://code.usgs.gov/wwatkins/national-site-reach/-/blob/master/R/match_sites_reaches.R
#' modified by: Jeff Sadler
#' Match each site with a reach (seg_id/COMID)
get_site_flowlines <- function(reach_sf, sites) {
  #' 
  #' @description Function to match reaches (flowlines) to point sites 
  #'
  #' @param reach_sf sf object of reach polylines with column "segidnat" and in WGS84
  #' @param sites dataframe with columns "lat" "lon"
  #'
  #' @value A data frame the same columns as the sites input dataframe with additional columns
  #' of "segidnat" and "offset" where "offset" is the distance (in degrees) between the point
  #' and matching flowline
  
  reaches_nhd_fields <- reach_sf %>%
    select(COMID = segidnat) %>%
    mutate(REACHCODE = COMID, ToMeas = 100, FromMeas = 100) %>%
    st_as_sf()
  print(pryr::object_size(reaches_nhd_fields))
  
  sites_sf <- sites %>% rowwise() %>%
    filter(across(c(lon, lat), ~ !is.na(.x))) %>%
    mutate(Shape = list(st_point(c(lon, lat), dim = "XY"))) %>%
    st_as_sf() %>% st_set_crs(4326) %>%
    st_transform(st_crs(reaches_nhd_fields)) %>%
    st_geometry()
  message('matching flowlines with reaches...')
  flowline_indices <- nhdplusTools::get_flowline_index(flines = reaches_nhd_fields,
                                                       points = sites_sf,
                                                       max_matches = 1,
                                                       search_radius = .1) %>%
    select(COMID, id, offset) %>%
    rename(segidnat = COMID)
  
  # nhdplusTools returns an "id" column which is just an index from 1 to 
  # the number of sites. To later join to the site-ids, we need to add
  # a matching index column.
  sites <- rowid_to_column(sites, "id")
  
  message("rejoining with other geometries")
  #rejoin to original reaches df
  sites_w_reach_ids <- sites %>%
    left_join(flowline_indices, by = "id") %>%
    select(-id)
  return(sites_w_reach_ids)
}


