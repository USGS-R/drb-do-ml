#' @title Plot segment and catchment attributes
#' 
#' @description 
#' This function visualizes each of the NHDPlusv2 attribute variables across
#' all river segments within the network.
#' 
#' @details 
#' This function was originally developed as part of the drb-inland-salinity-ml 
#' project:
#' https://github.com/USGS-R/drb-inland-salinity-ml/blob/synoptic_site_viz/3_visualize/src/plot_nhdv2_attr.R
#'
#' @param attr_data data frame containing the processed NHDv2 attribute data; 
#' must include column "COMID".
#' @param network_geometry sf object containing the network flowline geometry; 
#' must include columns "COMID" and "geometry".
#' @param save_dir character string indicating where the directory where the
#' output plots should be saved.
#' @param plot_sites logical; indicates whether or not to plot sampling sites.
#' @param sites tbl with the sampling sites and columns for the corresponding "COMID".
#' @param sites_epsg integer indicating the epsg code in the sites table 
#' (i.e., 4269 for NAD83).
#'
#' @returns 
#' Saves a png file containing a violin plot showing the distribution of each 
#' NHDv2 attribute variable and returns the file path of the saved file. 
#' 
plot_nhdv2_attr <- function(attr_data,
                            network_geometry,
                            save_dir,
                            plot_sites = FALSE, 
                            sites = NULL, 
                            sites_epsg = NULL){

  if(plot_sites){
    if (is.null(sites)){
      stop('sites must be specified when plot_sites = TRUE')
    }
    if (is.null(sites_epsg)){
      stop('sites CRS (as epsg code) must be specified when plot_sites = TRUE')
    }
    # Create spatial dataframe
    sites_sf <- sf::st_as_sf(sites, coords = c('lon', 'lat'), crs = sites_epsg) 
    
    # add indicator to attr_data for reaches that have sites
    attr_data_ind <- attr_data %>%
      mutate(site_reaches = case_when(COMID %in% sites_sf$COMID ~ 1,
                                      TRUE ~ 0))
  }
  
  message("Plotting individual NHDv2 attribute variables...")
  
  plot_names <- vector('character', length = 0L)
  
  # For each column/attribute variable, plot the distribution of the data 
  # across all NHDPlusv2 segments
  attr_names <- names(attr_data)[names(attr_data) != "COMID"]
  
  for(i in seq_along(attr_names)){
    col_name <- attr_names[i]
    subset_cols <- c("COMID", col_name, "site_reaches")
    
    if(plot_sites){
      dat_subset <- attr_data_ind %>%
        select(any_of(subset_cols))

      # plot the distribution of attr values on a linear scale
      attr_plot <- dat_subset %>%
        ggplot(aes(x = "", y = .data[[col_name]])) + 
        geom_violin(draw_quantiles = c(0.5)) +
        geom_jitter(data = dat_subset[dat_subset$site_reaches == 0,],
                    height = 0, 
                    size = 0.5,
                    color = "steelblue",
                    alpha = 0.1, width = 0.2) +
        geom_jitter(data = dat_subset[dat_subset$site_reaches == 1,],
                    height = 0, 
                    color = "red",
                    alpha = 0.4, width = 0.2) +
        labs(x="") + 
        theme_bw() + 
        theme(plot.margin = unit(c(0,0,0,0), "cm"))
      
      # plot the spatial variation
      attr_plot_spatial <- dat_subset %>% 
        mutate(COMID = as.integer(COMID)) %>%
        left_join(.,network_geometry[,c("COMID","geometry")],by=c("COMID"="COMID")) %>%
        sf::st_as_sf() %>%
        ggplot() + 
        geom_sf(aes(color=.data[[col_name]]), size = 0.3) + 
        scale_color_viridis_c(option="plasma") + 
        theme_bw() + 
        theme(plot.margin = unit(c(0,0,0,2), "cm"),
              axis.text.x = element_text(size = 6),
              legend.title = element_text(size = 10)) +
        geom_sf(data = sites_sf, size = 0.3)
    } else {
      dat_subset <- attr_data %>%
        select(any_of(subset_cols))
      
      # plot the distribution of attr values on a linear scale
      attr_plot <- dat_subset %>%
        ggplot(aes(x = "", y = .data[[col_name]])) + 
        geom_violin(draw_quantiles = c(0.5)) +
        geom_jitter(height = 0, color = "steelblue", size = 0.5, alpha = 0.4, width = 0.2) +
        labs(x="") + 
        theme_bw() + 
        theme(plot.margin = unit(c(0,0,0,0), "cm"))
      
      # plot the spatial variation
      attr_plot_spatial <- dat_subset %>% 
        mutate(COMID = as.integer(COMID)) %>%
        left_join(.,network_geometry[,c("COMID","geometry")],by = c("COMID" = "COMID")) %>%
        sf::st_as_sf() %>%
        ggplot() + 
        geom_sf(aes(color = .data[[col_name]]), size = 0.3) + 
        scale_color_viridis_c(option="plasma") + 
        theme_bw() + 
        theme(plot.margin = unit(c(0,0,0,2), "cm"),
              axis.text.x = element_text(size = 6),
              legend.title = element_text(size = 10))
    }
    
    # create combined plot showing violin plot and spatial distribution
    attr_plot_combined <- attr_plot + attr_plot_spatial + patchwork::plot_layout(ncol=2)
    
    plot_name <- paste0(save_dir,"/",col_name,".png")
    plot_names <- c(plot_names,plot_name)
    
    suppressWarnings(ggsave(plot_name,plot = attr_plot_combined,width = 7,height = 4,device = "png"))
  }
  
  return(plot_names)
}

