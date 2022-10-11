#' @title Download files from ScienceBase
#'
#' @description 
#' Function to download file from ScienceBase.
#'
#' @param sb_id character string representing the id of the science base item.
#' @param file_name character string indicating the name of the file within 
#' the science base item to download.
#' @param out_dir character string indicating the file directory where
#' the file should be downloaded to.
#'
#' @returns 
#' character string representing the name of the output file, including file path and
#' extension.
#' 
download_sb_file <- function(sb_id, file_name, out_dir){

  out_path = file.path(out_dir, file_name)
  # Get the data from ScienceBase:
  sbtools::item_file_download(sb_id = sb_id,
                              names = file_name,
                              destinations = out_path,
                              overwrite_file = TRUE)
  
  return(out_path)
}
