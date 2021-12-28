download_sb_file <- function(sb_id, file_name, out_dir){
  #'
  #' @description Function to download file from ScienceBase 
  #'
  #' @param sb_id string - the id of the science base item
  #' @param file_name string - the name of the file in the science base item to download
  #' @param out_dir string - the directory where you want the file downloaded to
  #'
  #' @value string the out_path

  out_path = file.path(out_dir, file_name)
  # Get the data from ScienceBase:
  sbtools::item_file_download(sb_id = sb_id,
                              names = c(file_name),
                              destinations = c(out_path),
                              overwrite_file = TRUE)
  
  return(out_path)
}
