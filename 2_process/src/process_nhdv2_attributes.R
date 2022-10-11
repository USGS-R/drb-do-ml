#' @title Process NHDPlusv2 attribute tables
#' 
#' @description 
#' Function to read in and combine downloaded NHDv2 attribute data downloaded
#' from Wieczorek et al. data releases. Replace missing values (i.e., -9999 or
#' -9998) with NA.
#' 
#' @details 
#' This function was pulled and modified from the inland salinity ml project:
#' https://github.com/USGS-R/drb-inland-salinity-ml/blob/main/2_process/src/process_nhdv2_attr.R
#'
#' @param file_path file path of downloaded NHDv2 attribute data table, including 
#' file name and extension
#' @param cols character string indicating which columns to retain from downloaded 
#' attribute data; cols can take values "CAT", "ACC", or "TOT". Defaults to "CAT".
#' @param nlcd_reclass_table data frame containing the integer land cover values
#' used by NLCD as well as the preferred classifications. Must contain columns 
#' "nlcd_value" and "reclassified_group_name".
#'
process_attr_tables <- function(file_path, cols = c("CAT"), nlcd_reclass_table){
 
  # Read in downloaded data 
  # only specify col_type for COMID since cols will differ for each downloaded file
  dat <- read_csv(file_path, col_types = cols(COMID = "c"), show_col_types = FALSE)
    
  # Process downloaded data
  dat_proc <- dat %>%
    # retain desired columns ('CAT','ACC' or 'TOT')
    select(c(COMID, starts_with(cols)))
  
  # Flag columns with undesired flag values (e.g. -9999)
  flag_cols <- dat_proc %>%
    select(where(function(x) -9999 %in% x)) %>% 
    names()
  
  if(length(flag_cols) > 0){
    message(sprintf("Replacing -9999 values with NA for the following attributes:\n\n%s\n", 
                    paste(flag_cols, collapse = "\n")))
  }
  
  # For columns with undesired flag values, replace -9999 with NA, else use existing value
  dat_proc_clean <- dat_proc %>%
    mutate(across(all_of(flag_cols), ~case_when(. == -9999 ~ NA_real_, 
                                                TRUE ~ as.numeric(.))))
  
  # Apply special handling for NLCD land cover data by reclassifying land cover categories.
  # Ignore the processing steps below for NLCD impervious cover or for NLCD forest
  # cover within 100 m riparian buffer datasets.
  if(all(grepl("NLCD", file_path), 
         !grepl("BUFF100", names(select(dat_proc_clean,-COMID))), 
         !grepl("IMPV", names(select(dat_proc_clean,-COMID))))){

    dat_proc_out <- dat_proc_clean %>%
      # Format table to "long format" so that reclassified groups can be summarized:
      pivot_longer(!COMID, names_to = "old_class", values_to = "proportion") %>%
      mutate(nlcd_value = as.numeric(stringr::str_extract(old_class, "\\d+$"))) %>%
      # join data table with nlcd reclassification crosswalk table:
      left_join(y = nlcd_reclass_table[,c("nlcd_value","reclassified_group_name")], 
                by = "nlcd_value") %>%
      # replace integer value describing NLCD land cover class with name of reclassified group:
      mutate(new_class = stringr::str_replace(string = old_class, "\\d+$", reclassified_group_name)) %>%
      group_by(COMID, new_class) %>%
      # sum the proportion land cover for each COMID and reclassified group:
      summarize(proportion_reclassified = sum(proportion, na.rm = TRUE),
                .groups = "drop") %>%
      pivot_wider(names_from = new_class, values_from = proportion_reclassified)
    
  } else {
    dat_proc_out <- dat_proc_clean
  }

  return(dat_proc_out)
  
}



#' @title Subset NHDPlusv2 VAA tables
#' 
#' @description
#' Function to subset NHDPlusv2 value-added attribute (VAA) tables and
#' replace values denoting missing data (i.e., -9999 or -9998) with NA.
#' 
#' @param nhd_lines sf data frame containing NHDPlusV2 flowlines.
#' @param vaa_cols character string or vector of strings containing which
#' value-added attributes should be retained in nhd_lines.
#' 
process_nhdv2_vaa <- function(nhd_lines, vaa_cols){
  
  # Format vaa_cols so that entries are not case-sensitive
  vaa_cols <- toupper(vaa_cols)
  
  # Create data frame containing NHD value-added attributes
  nhd_vaa_df <- nhd_lines %>%
    rename_with(toupper) %>%
    sf::st_drop_geometry() %>%
    select(c("COMID", any_of(vaa_cols)))
  
  # Flag columns with undesired flag values (e.g. -9999, -9998)
  flag_cols <- nhd_vaa_df %>%
    select(where(function(x) -9999 %in% x | -9998 %in% x)) %>% 
    names()
  
  if(length(flag_cols) > 0){
    message(sprintf("Replacing -9999 and -9998 values with NA for the following attributes:\n\n%s\n", 
                    paste(flag_cols, collapse = "\n")))
  }
  
  # For columns with undesired flag values, replace -9999 with NA, else use existing value
  nhd_vaa_df_out <- nhd_vaa_df %>%
    mutate(across(all_of(flag_cols), ~case_when(. == -9998 ~ NA_real_,
                                                . == -9999 ~ NA_real_,
                                                TRUE ~ as.numeric(.))))
  
  return(nhd_vaa_df_out)
}



#' @title Combine NHDPlusv2 static attributes
#' 
#' @description 
#' Function to combine static attributes for selected NHDv2 flowline reaches.
#' 
#' @param nhd_vaa data frame containing NHDPlusv2 value-added attribute data.
#' Must contain column "COMID".
#' @param cat_attr_list list object containing different catchment attribute
#' data frames.
#' @param sites_w_segs data frame containing observation locations with 
#' their matched flowlines. Must contain column "COMID".
#'
combine_nhdv2_attr <- function(nhd_vaa, cat_attr_list, sites_w_segs){
  
  # Combine list object containing catchment attributes into a single data frame
  cat_attr_df <- cat_attr_list %>%
    Reduce(full_join, .) %>%
    # hide messages that data frames are being joined by 'COMID'
    suppressMessages()
  
  # Combine catchment attributes with NHD value-added attributes for
  # each flowline reach
  attr_data <- nhd_vaa %>%
    mutate(COMID = as.character(COMID)) %>%
    left_join(y = cat_attr_df, by = "COMID")
  
  # Subset attribute data to the flowline reaches with observations
  attr_data_sub <- attr_data %>%
    filter(COMID %in% unique(sites_w_segs$COMID))
    
  return(attr_data_sub)
  
}

