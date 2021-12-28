

subset_met_data_and_match_site_ids <- function(met_data, sites_w_segs, sites_subset = NULL){
  #' 
  #' @description match site ids to meterological data and optionally subset to a certain list of sites
  #'
  #' @param met_data a data frame of meterological data indexed to seg_id_nats
  #' @param sites_w_segs a dataframe with both segment ids ('segidnat') and site ids ('site_id')
  #' @param sites_subset a vector of sites that the data should be subset too. If left NULL, data from all sites will 
  #' be returned
  #' 
  #' @value A data frame of met data with site ids 

    seg_and_site_ids <- sites_w_segs %>% select(site_id, segidnat)


    met_data <- met_data %>%
      left_join(
        seg_and_site_ids,
        by = c("seg_id_nat" = "segidnat")
      )

    if (!is.null(sites_w_segs)){
      met_data <- met_data %>% filter(site_id %in% sites_subset)
    }

    return(met_data)
}

