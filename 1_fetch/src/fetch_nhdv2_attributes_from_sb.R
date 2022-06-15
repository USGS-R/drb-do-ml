#' Function to download segment and catchment attribute data from ScienceBase
#' 
#' @description This function downloads zipped files from ScienceBase. By calling 
#' unzip_and_clip_sb_data(), this function also unzips the downloaded zipped files, 
#' reads in the unzipped data table, and filters the CONUS-scale data to retain 
#' the NHDPlusV2 COMID's of interest.
#' 
#' @details This function was pulled and modified from the inland salinity ml project:
#' https://github.com/USGS-R/drb-inland-salinity-ml/blob/main/1_fetch/src/fetch_nhdv2_attributes_from_sb.R
#' 
#' @param vars_item rows from vars of interest table containing the sb item to download
#' @param save_dir character string indicting the file path to save the unzipped data
#' @param comids vector of COMIDs to retain from CONUS-scale datasets
#' @param delete_local_copies logical, indicates whether to delete CONUS-scale 
#' zipped/unzipped data copies from save_dir. Defaults to TRUE.
#' 
fetch_nhdv2_attributes_from_sb <- function(vars_item, save_dir, comids, 
                                           delete_local_copies = TRUE){

  message(sprintf("Downloading %s from ScienceBase...",
                  unique(vars_item$SB_dataset_name)))
  
  # 1) Select items associated with ScienceBase ID to download
  item_names <- sbtools::item_list_files(sb_id = unique(vars_item$sb_id)) %>%
    filter(!grepl(".xml", fname)) %>%
    pull(fname)
  
  # 2) Download data from ScienceBase
  out_file <- download_sb_file(sb_id = unique(vars_item$sb_id),
                               file_name = c(item_names),
                               out_dir = save_dir)
  
  # 3) Select desired column names to be retained from original downloaded data
  col_names <- vars_item %>%
    split(., .$attribute_name) %>%
    lapply(., function(x){
      names <- c("COMID",
        paste0("CAT_", x$attribute_name),
        paste0("TOT_", x$attribute_name),
        paste0("ACC_", x$attribute_name))
    }) %>% 
    do.call("c",.) %>%
    unique()
  
  message(sprintf("Subsetting %s data to requested COMID's...",
                  unique(vars_item$SB_dataset_name)))
  
  # 4) Unzip out_files, filter to COMIDs of interest, and return combined data frame
  data_out <- lapply(out_file, unzip_and_clip_sb_data,
                     col_names = col_names,
                     comids = comids,
                     save_dir = save_dir,
                     delete_local_copies = delete_local_copies) %>%
    Reduce(full_join,.) %>% 
    suppressMessages() %>%
    suppressWarnings()
  
  # 5) Save file
  data_out_path <- paste0(save_dir,"/",unique(vars_item$SB_dataset_name),".csv")
  write_csv(data_out,file = data_out_path)
  
  return(data_out_path)
  
}



#' @description This function unzips zipped files downloaded from ScienceBase, 
#' reads in the unzipped data table, and filters the CONUS-scale data to 
#' retain the NHDPlusV2 COMID's of interest.
#' 
#' @param out_file character string indicating the file path of the zipped data
#' @param col_names string vector containing the columns to return.
#' @param comids vector of COMIDs to retain from CONUS-scale datasets
#' @param save_dir character string indicting the file path to save the unzipped data
#' @param delete_local_copies logical, indicates whether to delete CONUS-scale 
#' zipped/unzipped data copies from save_dir. Defaults to TRUE.
#' 
unzip_and_clip_sb_data <- function(out_file, col_names, comids, save_dir, 
                                   delete_local_copies = TRUE){

  # Unzip downloaded file
  unzip(zipfile = out_file, exdir = save_dir, overwrite = TRUE)
  
  # Parse name of unzipped file
  file_name <- basename(out_file)
  file_name_sans_ext <- tools::file_path_sans_ext(file_name)
  
  # Special handling 
  # in the future consider replacing with fuzzy string matching to create file_name_new
  if(file_name_sans_ext == "NHDV2_TMEAN7100_ANN_CONUS"){
    file_name_sans_ext <- "TMEAN7100_ANN_CONUS"
  }
  
  # this line finds the files within the desired directory that share file_name 
  # but are not zip files
  file_name_new <- grep(file_name_sans_ext,
                        grep(list.files(save_dir), 
                             pattern = "\\.zip$", value = TRUE, invert = TRUE),
                        value=TRUE)
  file_path <- paste0(save_dir,"/",file_name_new)
  
  # Read in data and filter to retain COMID's of interest
  dat <- read_delim(file_path, show_col_types = FALSE) %>%
    filter(COMID %in% comids) %>%
    select(any_of(col_names))
  
  # Remove files
  if(delete_local_copies == "TRUE"){
    file.remove(out_file)
    file.remove(file_path)
  }
  
  return(dat)
}

