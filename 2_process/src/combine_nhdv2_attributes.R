#' @description Function to read in and combine downloaded NHDv2 attribute data.
#' Any values of -9999 are replaced with NA. 
#' 
#' @details This function was pulled and modified from the inland salinity ml project:
#' https://github.com/USGS-R/drb-inland-salinity-ml/blob/main/2_process/src/process_nhdv2_attr.R
#'
#' @param file_path file path of downloaded NHDv2 attribute data table, including 
#' file name and extension
#' @param cols character string indicating which columns to retain from downloaded 
#' attribute data; cols can take values "CAT", "ACC", or "TOT". Defaults to "CAT".
#'
process_attr_tables <- function(file_path, cols = c("CAT")){
 
  # Read in downloaded data 
  # only specify col_type for COMID since cols will differ for each downloaded file
  dat <- read_csv(file_path, col_types = cols(COMID = "c"), show_col_types = FALSE)
    
  # Process downloaded data
  dat_proc <- dat %>%
    # retain desired columns ('CAT','ACC' or 'TOT')
    select(c(COMID,starts_with(cols)))
  
  # Flag columns with undesired flag values (e.g. -9999)
  flag_cols <- dat_proc %>%
    select(where(function(x) -9999 %in% x)) %>% 
    names()
  
  if(length(flag_cols) > 0){
    message(sprintf("Replacing -9999 values with NA for the following attributes:\n\n%s\n", 
                    paste(flag_cols, collapse = "\n")))
  }
  
  # For columns with undesired flag values, replace -9999 with NA, else use existing value
  dat_proc_out <- dat_proc %>%
    mutate(across(all_of(flag_cols), ~case_when(. == -9999 ~ NA_real_, 
                                                TRUE ~ as.numeric(.))))

  return(dat_proc_out)
  
}



#' @description Function to combine static attributes for selected NHDv2
#' flowline reaches
#' 
#' @param nhd_lines sf data frame containing NHDPlusV2 flowlines
#' @param cat_attr_list list object containing different catchment 
#' attribute data frames
#' @param vaa_cols character string or vector of strings containing which
#' value-added attributes should be retained in nhd_lines
#' @param sites_w_segs data frame containing observation locations with 
#' their matched flowlines. Must contain column "COMID".
#'
combine_attr_data <- function(nhd_lines, cat_attr_list, vaa_cols, sites_w_segs){
  
  # Format vaa_cols so that entries are not case-sensitive
  vaa_cols <- toupper(vaa_cols)
  
  # Combine list object containing catchment attributes into a single data frame
  cat_attr_df <- cat_attr_list %>%
    Reduce(full_join, .) %>%
    # hide messages that data frames are being joined by 'COMID'
    suppressMessages()
  
  # Combine catchment attributes with NHD value-added attributes for
  # each flowline reach
  attr_data <- nhd_lines %>%
    rename_with(toupper) %>%
    sf::st_drop_geometry() %>%
    select(c("COMID", any_of(vaa_cols))) %>%
    mutate(COMID = as.character(COMID)) %>%
    left_join(y = cat_attr_df, by = "COMID")
  
  # Subset attribute data to the flowline reaches with observations
  attr_data_sub <- attr_data %>%
    filter(COMID %in% unique(sites_w_segs$COMID))
    
  return(attr_data_sub)
  
}

