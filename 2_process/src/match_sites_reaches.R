#' original author: David Watkins
#' from https://code.usgs.gov/wwatkins/national-site-reach/-/blob/master/R/match_sites_reaches.R
#' modified by: Jeff Sadler
#' Match each site with a reach (seg_id/COMID)
get_site_flowlines <- function(reach_sf, sites, sites_crs, max_matches = 1, search_radius = 0.1) {
  #' 
  #' @description Function to match reaches (flowlines) to point sites 
  #'
  #' @param reach_sf sf object of reach polylines with column "subsegid" and in WGS84
  #' @param sites dataframe with columns "lat" "lon"
  #' @param sites_crs the crs os the sites table (i.e., 4269 for NAD83)
  #' @param max_matches the maximum number of segments that a point can match to
  #' @param search_radius the maximum radius in same units as sf object
  #' within which a segment will match (segments outside of the radius will not match)
  #'
  #' @value A data frame the same columns as the sites input dataframe with additional columns
  #' of "segidnat", "subsegid" and "offset" where "offset" is the distance (in degrees) between the point
  #' and matching flowline
  
  # set up NHDPlus fields used by get_flowline_index
  # Note: that we are renaming the subsegid column to COMID because the nhdplusTools
  # function requires an sf object with a "COMID" column. This does not have anything
  # to do with the actual nhd COMIDs 
  # Note: the `ToMeas` and `FromMeas` are also required columns for the nhdplusTools 
  # function. Since we are using our own reaches and not the nhd, these do not have 
  # the same meaning as they would if we were using the nhd
  reaches_nhd_fields <- reach_sf %>%
    rename(COMID = subsegid) %>%
    mutate(REACHCODE = COMID, ToMeas = 100, FromMeas = 100) %>%
    st_as_sf()
  
  sites_sf <- sites %>% rowwise() %>%
    filter(across(c(lon, lat), ~ !is.na(.x))) %>%
    mutate(Shape = list(st_point(c(lon, lat), dim = "XY"))) %>%
    st_as_sf() %>% st_set_crs(sites_crs) %>%
    st_transform(st_crs(reaches_nhd_fields)) %>%
    st_geometry()
  message('matching flowlines with reaches...')
  flowline_indices <- nhdplusTools::get_flowline_index(flines = reaches_nhd_fields,
                                                       points = sites_sf,
                                                       max_matches = max_matches,
                                                       search_radius = search_radius) %>%
    select(COMID, id, offset) %>%
    rename(subsegid = COMID)
  
  # nhdplusTools returns an "id" column which is just an index from 1 to 
  # the number of sites. To later join to the site-ids, we need to add
  # a matching index column.
  sites <- rowid_to_column(sites, "id")
  
  message("rejoining with other geometries")
  #rejoin to original reaches df
  sites_w_reach_ids <- sites %>%
    left_join(flowline_indices, by = "id") %>%
    select(-id)

  # add `segidnat` column
  sites_w_reach_ids <- sites_w_reach_ids %>%
    left_join(select(reach_sf, c(subsegid, segidnat))) %>%
    select(-geometry)

  return(sites_w_reach_ids)
}


