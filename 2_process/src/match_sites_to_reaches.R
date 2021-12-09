#' author: David Watkins
#' from https://code.usgs.gov/wwatkins/national-site-reach/-/blob/master/R/match_sites_reaches.R
#' Match each site with a reach (seg_id/COMID)
get_site_flowlines <- function(outind, reaches_direction_ind, sites, search_radius) {
  
  reaches_direction <- readRDS(as_data_file(reaches_direction_ind))
  #In NHDPlus, divergences cause duplicated segments to represent both downstream segments
  #drop to_seg here to avoid somewhat misleading network structure ignoring divergence
  #With geofabric, this should have no affect
  reaches_unique <- reaches_direction %>% 
    distinct(seg_id, .keep_all = TRUE) %>% 
    select(-to_seg)
  
  #set up NHDPlus fields used by get_flowline_index
  #TODO: logic to add fields if using geofabric in initial load step
  #could have function early on to check expected fields
  #nhdplusTools expects NHDPlus field names
  reaches_nhd_fields <- reaches_unique %>%
    select(COMID = seg_id, Shape, REACHCODE, ToMeas, FromMeas) %>%
    # mutate(REACHCODE = COMID, ToMeas = 100, FromMeas = 100) %>%
    st_as_sf()
  print(pryr::object_size(reaches_nhd_fields))
  
  sites_sf <- sites %>% rowwise() %>%
    filter(across(c(longitude, latitude), ~ !is.na(.x))) %>%
    mutate(Shape = list(st_point(c(longitude, latitude), dim = "XY"))) %>%
    st_as_sf() %>% st_set_crs(4326) %>%
    st_transform(st_crs(reaches_nhd_fields)) %>%
    st_geometry()
  message('matching flowlines with reaches...')
  flowline_indices <- nhdplusTools::get_flowline_index(flines = reaches_nhd_fields,
                                                       points = sites_sf,
                                                       max_matches = 1,
                                                       search_radius = search_radius)
  sites_sf_index <- tibble(Shape_site = sites_sf,
                           index = 1:length(sites_sf))
  message("rejoining with other geometries, adjusting matches for upstream proximity...")
  #rejoin to original reaches df, get up/downstream distance
  flowline_indices_joined <- flowline_indices %>%
    rename(seg_id = COMID) %>%
    left_join(reaches_unique, by = c("seg_id")) %>% 
    #select only needed fields here, so they are not duplicated later after 
    #checking dist to upstream and joining again to seg_id_reassign
    left_join(sites_sf_index, by = c(id = "index")) %>%
    select(id, seg_id, Shape, Shape_site, up_point, down_point, offset) %>%
    mutate(site_upstream_distance = st_distance(x = Shape_site, y = up_point,
                                                by_element = TRUE),
           site_downstream_distance = st_distance(x = Shape_site, y = down_point,
                                                  by_element = TRUE),
           down_up_ratio = as.numeric(site_downstream_distance / site_upstream_distance))
  
  sites_move_upstream <- flowline_indices_joined %>%
    rowwise() %>%
    mutate(seg_id_reassign = if_else(down_up_ratio > 1,
                                     true = check_upstream_reach(matched_seg_id = seg_id,
                                                                 down_up_ratio = down_up_ratio,
                                                                 reaches_direction = reaches_direction),
                                     false = list(seg_id),
                                     missing = list(seg_id))) %>%
    rename(seg_id_orig_match = seg_id) %>%
    unnest_longer(seg_id_reassign) %>% #handle when site matched to two reaches at intersection
    #contains clause for fields in geofabric, but not in NHDPlus
    #end_points
    select(-matches('seg_id_nhm|Version|shape_length|end_points|which_end_up'), 
           -Shape, -up_point, -down_point) %>%
    #drop columns and rejoin to get correct geometries for sites that were
    #moved upstream
    left_join(reaches_unique, by = c(seg_id_reassign = 'seg_id'))
  
  #make sure each site is matched to only one reach
  assert_that(class(sites_move_upstream$seg_id_reassign) == 'integer')
  assert_that(length(unique(sites_move_upstream$id)) == nrow(sites_move_upstream),
              msg = 'There are repeated site IDs in the site-reach matches')
  assert_that(sum(is.na(sites_move_upstream$seg_id_reassign)) == 0,
              msg = 'There are NAs in the matched reach column')
  if(nrow(sites) != nrow(sites_move_upstream)) {
    warning('The number of sites matched to reaches is different than the original number of sites.
            Maybe some sites were not matched?')
  }
  saveRDS(sites_move_upstream, file = as_data_file(outind))
  sc_indicate(outind)
}


#' get upstream reach: if multiple, return original match;
#' if only one upstream reach, return it
#'
#' Expects only reaches where up_down_ratio > 1
check_upstream_reach <- function(matched_seg_id, down_up_ratio, reaches_direction) {
  #if_else will replace this value
  if(down_up_ratio <= 1 || is.na(down_up_ratio)) {
    return(list(NA))
  }
  
  upstream_reaches <- filter(reaches_direction, to_seg == matched_seg_id)
  
  if(nrow(upstream_reaches) > 1 | nrow(upstream_reaches) == 0) { #upstream point is a confluence or source
    return(list(matched_seg_id))
  } else if(nrow(upstream_reaches) == 1){
    return(list(upstream_reaches$seg_id))
  }
}


sample_reaches <- function(matched_sites_ind, full_network) {
  
  matched_sites <- readRDS(as_data_file(matched_sites_ind))
  random_site_reaches_seg_ids <- matched_sites %>% select(seg_id_reassign) %>%
    distinct() %>% slice_sample(n = 100) %>% pull(seg_id_reassign)
  random_site_reaches <- matched_sites %>% filter(seg_id_reassign %in% random_site_reaches_seg_ids)
  longest_reaches <- matched_sites %>% slice_max(order_by = shape_length, n = 20)
  shortest_reaches <- matched_sites %>% slice_min(order_by = shape_length, n = 20)
  most_sites_reaches_seg_ids <- matched_sites %>% select(seg_id_reassign, id) %>%
    group_by(seg_id_reassign) %>%
    summarize(n_sites = n()) %>%
    slice_max(order_by = n_sites, n = 20) %>%
    pull(seg_id_reassign)
  most_sites_reaches <- matched_sites %>% filter(seg_id_reassign %in% most_sites_reaches_seg_ids)
  
  order_one_reach_ids <- get_first_order_reaches(matched_sites, full_network = full_network) %>%
    sample(size = min(c(20, length(.)))) #With NHDPlus in UCRB, < 20 sites matched to 1st order
  order_one_reaches <- matched_sites %>% filter(seg_id_reassign %in% order_one_reach_ids) 
  
  reaches_list <- list(random_site_reaches = random_site_reaches,
                       longest_reaches = longest_reaches,
                       shortest_reaches = shortest_reaches,
                       most_sites_reaches = most_sites_reaches,
                       order_one_reaches = order_one_reaches)
  return(reaches_list)
}

#' @param reaches has seg_id column, of segments with matched reaches
#' @param full_network has seg_id and to_seg columns of full network
#' The geofabric doesn't have a stream order field, but we can find the first order
#' reaches just by finding which reaches are missing from the to_seg column
get_first_order_reaches <- function(reaches, full_network) {
  network_first_order_reaches <- full_network %>%
    filter(!seg_id %in% to_seg) %>%
    pull(seg_id)
  reaches %>% filter(seg_id_reassign %in% network_first_order_reaches) %>%
    distinct() %>%
    pull(seg_id_reassign)
}
