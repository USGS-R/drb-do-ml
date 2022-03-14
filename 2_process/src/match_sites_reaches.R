#' original author: David Watkins
#' from https://code.usgs.gov/wwatkins/national-site-reach/-/blob/master/R/match_sites_reaches.R
#' modified by: Jeff Sadler
#' Match each site with a reach (seg_id/COMID)
get_site_flowlines <- function(reach_sf, sites, sites_crs, max_matches = 1, search_radius = 500) {
  #' 
  #' @description Function to match reaches (flowlines) to point sites 
  #'
  #' @param reach_sf sf object of reach polylines with column "subsegid" 
  #' @param sites dataframe with columns "lat" "lon"
  #' @param sites_crs the crs of the sites table (i.e., 4269 for NAD83)
  #' @param max_matches the maximum number of segments that a point can match to
  #' @param search_radius the maximum radius in meters to match a point to a segment;
  #' segments outside of search_radius will not match
  #'
  #' @value A data frame the same columns as the sites input dataframe with additional columns
  #' of "segidnat", "subsegid" and "bird_dist_to_subseg_m" where "bird_dist_to_subseg_m" is the 
  #' distance (in meters) between the point and matching flowline
  
  # set up NHDPlus fields used by get_flowline_index
  # Note: we are renaming the subsegid column to COMID because the nhdplusTools
  # function requires an sf object with a "COMID" column. This does not have anything
  # to do with the actual nhd COMIDs 
  # Note: the `ToMeas` and `FromMeas` are also required columns for the nhdplusTools 
  # function. Since we are using our own reaches and not the nhd, these do not have 
  # the same meaning as they would if we were using the nhd
  reaches_nhd_fields <- reach_sf %>%
    rename(COMID = subsegid) %>%
    mutate(REACHCODE = COMID, ToMeas = 100, FromMeas = 100) %>%
    # project reaches to Albers Equal Area Conic so that offsets returned by 
    # get_flowline_index are in meters rather than degrees
    st_transform(.,5070)
  
  sites_sf <- sites %>% rowwise() %>%
    filter(across(c(lon, lat), ~ !is.na(.x))) %>%
    mutate(Shape = list(st_point(c(lon, lat), dim = "XY"))) %>%
    st_as_sf() %>% st_set_crs(sites_crs) %>%
    st_transform(st_crs(reaches_nhd_fields)) %>%
    st_geometry()
  
  message('matching flowlines with reaches...')
  # Below, precision indicates the resolution of measure precision (in meters) in the output; 
  # since we are interested in a more accurate estimate of the `offset` distance between a 
  # point and the matched reach, set precision to 1 m.
  flowline_indices <- nhdplusTools::get_flowline_index(flines = reaches_nhd_fields,
                                                       points = sites_sf,
                                                       max_matches = max_matches,
                                                       search_radius = search_radius,
                                                       precision = 1) %>%
    select(COMID, id, offset) %>%
    rename(subsegid = COMID, bird_dist_to_subseg_m = offset)
  
  # nhdplusTools returns an "id" column which is just an index from 1 to 
  # the number of sites. To later join to the site-ids, we need to add
  # a matching index column.
  sites <- rowid_to_column(sites, "id")
  
  #rejoin to original reaches df
  message("rejoining with other geometries")
  sites_w_reach_ids <- sites %>%
    left_join(flowline_indices, by = "id") %>%
    select(-id) %>%
    # add `segidnat` column
    left_join(.,reach_sf %>%
                select(subsegid, segidnat) %>%
                sf::st_drop_geometry(),
              by = "subsegid")

  return(sites_w_reach_ids)
}


