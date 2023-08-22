#' @title Append river distance
#' 
#' @description
#' Appends the downstream river distance (in km) to the sites_splits table
#' 
#' @param sites_splits data frame; must contain column "river_basin"
#' @param nhdv2_flines sf (MULTI)LINESTRING object; must contain columns "COMID",
#' "GNIS_NAME", and "LEVELPATHI"
#' 
#' @returns 
#' Returns the sites_splits data frame, with a new column, "river_dist_km"
#' 
append_river_km <- function(sites_splits, nhdv2_flines){
  
  lapply(split(sites_splits, 1:nrow(sites_splits)), function(x){
    
    if(x$river_basin == "Brandywine"){
      flines_sub <- filter(nhdv2_flines, grepl("brandywine", GNIS_NAME, ignore.case = TRUE))
    }
    if(x$river_basin == "Schuylkill"){
      flines_sub <- filter(nhdv2_flines, grepl("schuylkill", GNIS_NAME, ignore.case = TRUE))
    }
    if(x$river_basin == "Cobbs"){
      flines_sub <- filter(nhdv2_flines, LEVELPATHI == 200057760)
    }
    if(!x$river_basin %in% c("Brandywine", "Schuylkill", "Cobbs")){
      mutate(x, river_dist_km = NA_real_)
    } else {
      mutate(x, river_dist_km = get_river_km(x, flines_sub))
    }
  }) |>
    bind_rows()
  
}



#' @title Get downstream river length
#' 
#' @description 
#' Given a point location, subsets the river length downstream of the point and
#' returns the length in kilometers
#' 
#' @param pt sf POINT object; must contain column "COMID"
#' @param flines sf LINESTRING object; must contain column "COMID"
#' 
#' @returns 
#' Returns numeric length (in km) of the mainstem distance from the point 
#' location to the outlet.
#' 
get_river_km <- function(pt, flines){
  
  flines <- sf::st_transform(flines, 5070)
  pt <- sf::st_transform(pt, 5070)
  
  fline_pt <- filter(flines, COMID %in% pt$COMID)
  flines_down <- nhdplusTools::navigate_network(start = fline_pt$COMID, 
                                                mode = "DM", 
                                                network = flines, 
                                                distance_km = 1000)
  
  # for all flowlines downstream of point, sample linestring every 1 m, 
  # suppressing warnings about repeated attributes for sub-geometries
  fline_pts <- flines_down |>
    sf::st_segmentize(dfMaxLength = units::as_units(1, "m")) |>
    sf::st_cast("LINESTRING") |>
    sf::st_cast("POINT") |>
    arrange(desc(hydroseq)) |>
    suppressWarnings() 
  
  # find the flowline node that is closest to the pt 
  fline_nn_idx <- sf::st_nearest_feature(pt, fline_pts)
  
  # split the flowline at the nearest node and return downstream trace
  downstr_trace <- fline_pts[c(fline_nn_idx:nrow(fline_pts)),] |>
    group_by(comid) |>
    summarize(do_union = FALSE) |>
    sf::st_cast("LINESTRING") |>
    ungroup()
  
  # return length of downstream trace in km
  dist_m <- as.numeric(sum(sf::st_length(downstr_trace)))
  dist_km <- round((dist_m/1000), 2)
  
  return(dist_km)
}

