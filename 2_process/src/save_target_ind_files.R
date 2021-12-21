save_target_ind_files <- function(fileout,target_names) {
  #' 
  #' @description Function to save indicator files to track data changes over time
  #'
  #' @param fileout a character string that indicates the name of the file to be saved, including path and file extension 
  #' @param target_names a character string or vector of strings containing the target names of interest
  #'
  #' @value Returns a csv file containing the target metadata
  
  # Create indicator table
  ind_tbl <- tar_meta(all_of(target_names)) %>%
    select(tar_name = name, hash = data) 
  
  # Save indicator table
  readr::write_csv(ind_tbl, fileout)
  return(fileout)
}
