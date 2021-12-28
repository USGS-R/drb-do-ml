

subset_seg_data_and_match_site_ids <-
  function(seg_data, sites_w_segs, sites_subset = NULL) {
    #'
    #' @description match site ids to segment data (e.g., met or attributes) and optionally subset to a certain list of sites
    #'
    #' @param seg_data a data frame of meterological data with column 'seg_id_nat'
    #' @param sites_w_segs a dataframe with both segment ids ('segidnat') and site ids ('site_id')
    #' @param sites_subset a vector of sites that the data should be subset too. If left NULL, data from all sites will
    #' be returned
    #'
    #' @value A data frame of seg data with site ids and optionally subset
    
    seg_and_site_ids <- sites_w_segs %>% select(site_id, segidnat)
    
    
    seg_data <- seg_data %>%
      left_join(seg_and_site_ids,
                by = c("seg_id_nat" = "segidnat"))
    
    if (!is.null(sites_w_segs)) {
      seg_data <- seg_data %>% filter(site_id %in% sites_subset)
    }
    
    return(seg_data)
  }

write_df_to_zarr <- function(df, index_cols, out_zarr) {
  #'
  #' @description use reticulate to write an R data frame to a Zarr data store (the file format river-dl currently takes)
  #'
  #' @param df a data frame of data
  #' @param index vector of strings - the column(s) that should be the index
  #' @param out_zarr where the zarr data will be written
  #'
  #' @value the out_zarr path
  
  # convert to a python (pandas) DataFrame so we have access to the object methods (set_index and to_xarray)
  py_df <- reticulate::r_to_py(df)
  
  # set the index so that when we convert to an xarray dataset it is indexed properly
  py_df  <- py_df$set_index(index_cols)
  
  # convert to an xarray dataset
  ds <- py_df$to_xarray()
  
  ds$to_zarr(out_zarr, mode = 'w')
  
  return(out_zarr)
  
}

