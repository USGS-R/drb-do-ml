#' @description Function to match reaches (NHDv2 flowlines) to point sites 
#' 
#' @param sites sf data frame containing site locations
#' @param sites_crs the crs of the sites table (i.e., 4269 for NAD83)
#' @param nhd_lines sf data frame containing NHDPlusV2 flowlines
#' @param max_matches the maximum number of segments that a point can match to
#' @param search_radius the maximum radius in meters to match a point to a segment;
#' segments outside of search_radius will not match
#'
#' @value A data frame that contains the same columns as the `sites` data,
#' with additional columns `COMID`, `bird_dist_to_comid_m` where 
#' `bird_dist_to_comid_m` is the distance (in meters) between the site and the
#' matched NHDv2 flowline.
#'
get_site_nhd_flowlines <- function(nhd_lines, sites, sites_crs,
                                   max_matches = 1, search_radius = 500){
  
  # Project reaches to Albers Equal Area Conic so that offsets returned by 
  # get_flowline_index are in meters rather than degrees
  nhd_lines_proj <- nhd_lines %>%
    sf::st_transform(5070)
  
  sites_sf <- sites %>% 
    rowwise() %>%
    filter(!is.na(lon), !is.na(lat)) %>%
    mutate(Shape = list(st_point(c(lon, lat), dim = "XY"))) %>%
    sf::st_as_sf() %>% 
    sf::st_set_crs(sites_crs) %>%
    sf::st_transform(sf::st_crs(nhd_lines_proj)) %>%
    sf::st_geometry()
  
  message('matching NHDv2 flowlines with reaches...')
  # Below, precision indicates the resolution of measure precision (in meters)
  # in the output; since we are interested in a more accurate estimate of the 
  # `offset` distance between a point and the matched reach, set precision to 1 m.
  # Conduct initial search using a larger radius (search_radius*2) than specified 
  # to account for any uncertainty in the RANN::nn2 nearest neighbor search. Then 
  # filter sites to include those within the specified search_radius.
  flowline_indices <- nhdplusTools::get_flowline_index(flines = nhd_lines_proj,
                                                       points = sites_sf,
                                                       max_matches = max_matches,
                                                       search_radius = search_radius*2,
                                                       precision = 1) %>% 
    select(COMID, id, offset) %>%
    rename(bird_dist_to_comid_m = offset) %>%
    filter(bird_dist_to_comid_m <= search_radius)
  
  # nhdplusTools returns an "id" column which is just an index from 1 to 
  # the number of sites. To later join to the site-ids, we need to add
  # a matching index column.
  sites <- rowid_to_column(sites, "id")
  
  # Rejoin flowline indices to original sites df
  sites_w_reach_ids <- sites %>%
    # only retain sites that got matched to flowlines and are 
    # within specified search_radius
    right_join(flowline_indices, by = "id") %>%
    mutate(across(c(COMID), as.character)) %>%
    select(-id)
  
  return(sites_w_reach_ids)
  
}



