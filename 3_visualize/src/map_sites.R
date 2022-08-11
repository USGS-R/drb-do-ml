#' @title Save map of site locations
#' 
#' @description 
#' Function to map site locations within the area of interest
#' and save as a png file.
#' 
#' @param flowlines sf object containing the river flowlines. Must contain
#' columns "REACHCODE" and "STREAMORDE".
#' @param matched_sites data frame containing site locations and the flowline
#' reach identifier ("COMID") that the site has been matched to. Must contain
#' columns "lon", "lat", "datum", and "COMID".
#' @param out_file character string indicating the name of the saved file, 
#' including file path and extension.
#' @param huc6_select vector of character string(s) indicating the HUC6 basins that
#' should be displayed on the map. Defautls to "020402" to map the lower
#' Delaware River Basin.
#' @param basin_bbox vector indicating xmin, ymin, xmax, and ymax to use for defining
#' the basin for plotting.
#' @param epsg_out integer indicating the coordinate reference system that 
#' should be used when creating the inset map. Defaults to EPSG 3857, pseudo-
#' mercator: https://epsg.io/3857.
#' @param lat_breaks numeric sequence indicating the breaks to use when plotting
#' latitude. By default, includes lat_breaks that are focused on the lower 
#' Delaware River Basin.
#' @param lon_breaks numeric sequence indicating the breaks to use when plotting
#' longitude. By default, includes lon_breaks that are focused on the lower 
#' Delaware River Basin.
#' @param site_type_colors vector of character strings indicating the colors to use
#' when plotting train, validation, and test sites.
#' @param fig_width_inches numeric value indicating the width of the saved figure
#' in inches
#' @param fig_height_inches numeric value indicating the height of the saved figure
#' in inches
#' 
#' @returns 
#' returns a png file containing the site locations
#' 
map_sites <- function(flowlines, 
                      matched_sites, 
                      out_file,
                      huc6_select = "020402", 
                      basin_bbox = c(xmin = -76.39556, ymin = 39.5, xmax = -74.37121, ymax = 40.89106),
                      epsg_out = 3857, 
                      lat_breaks = seq(from = 39.6, to = 41, by = 0.4),
                      lon_breaks = seq(from = -74.5, to = -76, by = -0.5),
                      site_type_colors = c("#E69F00","#56B4E9","#009E73"),
                      fig_width_inches = 7.8, fig_height_inches = 6.5){
  
  # Fetch EPSG code of matched_sites; assume unknown crs (datum equals "UNKNWN", "OTHER") 
  # correspond with WGS84
  epsg_in <- case_when(unique(matched_sites$datum) == "NAD83" ~ 4269,
                       unique(matched_sites$datum) == "WGS84" ~ 4326,
                       unique(matched_sites$datum) == "NAD27" ~ 4267,
                       unique(matched_sites$datum) == "UNKWN" ~ 4326,
                       unique(matched_sites$datum) == "OTHER" ~ 4326)
  
  # Create sf object containing site locations
  sites <- matched_sites %>%
    sf::st_as_sf(., coords = c("lon","lat"), crs = epsg_in)
  
  # Create bbox/spatial extent of sites used in the model
  subset_bbox <-  sf::st_bbox(basin_bbox) %>%
    sf::st_as_sfc() %>%
    sf::st_set_crs(4326) %>%
    sf::st_as_sf() %>%
    sf::st_transform(crs = epsg_out)
  
  # Download HUC12 boundaries and dissolve them to get HUC6 boundaries
  # corresponding with the watershed of interest
  basin_boundary <- nhdplusTools::get_huc12(AOI = subset_bbox) %>%
    mutate(huc6 = str_sub(huc12,0,6)) %>%
    filter(huc6 == huc6_select) %>%
    sf::st_buffer(0) %>%
    sf::st_union() %>%
    sf::st_as_sf() %>%
    sf::st_transform(crs = epsg_out) %>%
    # crop the watershed to the sites bounding box
    sf::st_crop(subset_bbox) 

  # Subset the flowlines that should be mapped within the basin boundary
  flowlines_in_basin <- flowlines %>%
    mutate(huc8 = str_sub(REACHCODE,0,8),
           huc6 = str_sub(REACHCODE,0,6)) %>%
    filter(huc6 == huc6_select) %>%
    sf::st_transform(crs = epsg_out) %>%
    # crop the flowlines to the sites bounding box
    sf::st_crop(subset_bbox) %>% 
    # ignore warnings about attribute variables assumed spatially constant
    suppressWarnings() %>%
    # make sure that all flowlines have a positive stream order
    filter(STREAMORDE > 0) 
    
  # Create site map
  sites_map <- ggplot() + 
    geom_sf(data = basin_boundary, fill = 'gray80', color = NA, alpha = .6) +
    # adjust line width so that flow direction is more intuitive
    geom_sf(data = flowlines_in_basin, aes(size = STREAMORDE/5), color = "slategray4") +
    # scale_size_identity needed to provide line width as an aesthetic
    scale_size_identity() +
    geom_sf(data = sites, aes(color = site_type), size = 3.5) +
    scale_fill_identity() +
    coord_sf() +
    scale_y_continuous(breaks = lat_breaks) +
    scale_x_continuous(breaks = lon_breaks) + 
    scale_color_manual(breaks = c("train","validation","test"), 
                       values = site_type_colors,
                       name = "site type")+
    theme_bw() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(),
          axis.title = element_blank()) +
    ggspatial::annotation_north_arrow(
      location = "br", which_north = "true",
      pad_x = unit(1, 'cm'), pad_y = unit(0.5, 'cm'),
      height = unit(0.9, 'cm'),
      width = unit(0.75, 'cm'),
      style = ggspatial::north_arrow_orienteering(
        fill = c("grey70", "white"),
        line_col = "grey20",
        text_size = 9)) + 
    ggspatial::annotation_scale(bar_cols = c("gray70","white"))
  
  # create inset map
  inset_map <- map_drb_watershed(sites)
  
  # grab legend 
  legend <- cowplot::get_legend(sites_map)
  
  # modify sites_map to plot without legend
  sites_map2 <- sites_map + theme(legend.position = 'none')
  
  # create and save combined map
  do_sites_map <- cowplot::ggdraw() + 
    cowplot::draw_plot(sites_map2) + 
    cowplot::draw_plot(inset_map, x = 0.66, y = 0.63, width = 0.35, height = 0.35) + 
    cowplot::draw_plot(legend, x = -0.3, y = -0.2)

  ggsave(out_file, 
         plot = do_sites_map,
         width = fig_width_inches, height = fig_height_inches, units = c("in"),
         dpi = 300)
  
  # return save directory
  return(out_file)

}


#' @title Create watershed inset map
#' 
#' @description 
#' Function to create an inset map that shows surrounding states,
#' the watershed of interest, and a bounding box containing modeled
#' sites.
#' 
#' @param sites sf object containing the site locations.
#' @param huc8 vector of character string(s) indicating the HUC8 basins that
#' make up the watershed of interest. By default, the HUC8 basins that make up
#' the Delaware River Basin will be used.
#' @param states vector of character string(s) indicating which states should
#' be included in the inset map, using two-letter postal code abbreviations for 
#' each state. By default, the states surrounding the Delaware River Basin will
#' be downloaded, including "NY", "PA", "NJ", "DE", and "MD".
#' @param epsg_out integer indicating the coordinate reference system that 
#' should be used when creating the inset map. Defaults to EPSG 3857, pseudo-
#' mercator: https://epsg.io/3857
#' 
#' @returns 
#' Returns an inset map as a ggplot object.
#'
map_drb_watershed <- function(sites,
                              huc8 = c("02040101","02040102","02040103",
                                       "02040104","02040105","02040106",
                                       "02040201","02040202","02040203",
                                       "02040204","02040205","02040206",
                                       "02040207"),
                              states = c("NY","PA","NJ","DE","MD"),
                              epsg_out = 3857){
  
  # Download shapefiles for states that encompass the watershed of interest
  states_shp <- USAboundaries::us_states(resolution = "high", states = states)
  
  # Download HUC8 boundaries associated with watershed boundary
  boundary <- nhdplusTools::get_huc8(id = huc8) %>%
    sf::st_union()
  
  # Create bbox/spatial extent of sites used in the model
  sites_bbox <-  sf::st_bbox(sites) %>%
    sf::st_as_sfc() %>%
    sf::st_as_sf() %>%
    sf::st_transform(crs = epsg_out)
  
  # Create inset map
  inset_map <- ggplot() +
    geom_sf(data = states_shp, fill = 'gray70', color = 'gray90', size = 0.4) + 
    geom_sf(data = boundary, fill = 'gray30', color = NA) +
    geom_sf(data = sites_bbox, color = 'black', fill = NA, size = 1) + 
    coord_sf(crs = epsg_out) +
    theme_void()
  
  return(inset_map)
  
}


#' @title Create leaflet map of site locations

#' @description 
#' Function to map unique site id's within the area of interest.
#'
#' @param site_list data frame containing the site locations. The site 
#' list file should contain the columns "datum", "data_src_combined", 
#' and "count_days_total".
#' 
#' @returns 
#' returns a leaflet map containing the site locations colored by
#' the data source (i.e., discrete grab samples, instantaneous NWIS
#' data, or daily NWIS data).
#' 
map_sites_leaflet <- function(site_list) {

  # check for required columns in the site list
  req_cols <- c("datum", "data_src_combined","count_days_total")
  flag_cols <- req_cols[which(req_cols %in% names(site_list)=="FALSE")]
  if(length(flag_cols)>0) stop("site_list_csv file is missing one or more required columns: datum, data_src_combined,count_days_total")
  
  # convert data frame to spatial object:
  site_list_sp <- sf::st_as_sf(site_list,coords=c("lon","lat"),crs=site_list$datum[1]) %>%
    sf::st_transform(4326) %>%
    mutate(group = as.factor(case_when(data_src_combined == "NWIS_daily/Harmonized_WQP_data" ~ "daily",
                                       data_src_combined == "NWIS_instantaneous/Harmonized_WQP_data" ~ "instantaneous",
                                       data_src_combined == "Harmonized_WQP_data" ~ "discrete",
                                       data_src_combined == "NWIS_instantaneous" ~ "instantaneous",
                                       data_src_combined == "NWIS_daily" ~ "daily")))

  # define color palette for circle markers:
  pal <- colorFactor(palette = c("blue","orange","green"),domain=site_list_sp$group)
  
  # plot sites:
  map <- leaflet() %>%
    addProviderTiles("CartoDB.DarkMatter", group = "CartoDB") %>%
    addCircleMarkers(data=site_list_sp,radius = ~sqrt(count_days_total/40),color = ~pal(group),
                     stroke = FALSE, fillOpacity = 0.5,popup=paste("Site:", site_list_sp$site_id,"<br>",
                                                                   "n_observation-days:", site_list_sp$count_days_total)) %>%
    addLegend("bottomright", colors = c("orange","green","blue"), labels = c("discrete","instantaneous","daily")) 
  
  return(map)
  
}
