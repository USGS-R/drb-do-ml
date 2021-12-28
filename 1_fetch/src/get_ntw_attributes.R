get_ntw_attributes <- function(save_path){
  #' 
  #' @description Function to download Delaware River Basin network attributes from ScienceBase
  #' @param save_path Path to save downloaded data
  #'
  #' @value returns a character string indicating the location of the downloaded network attributes
  #' @examples 
  #' get_ntw_attributes(save_path = "1_fetch/out/ntw_attributes")
  
  #' Data release, "Predicting temperature in the Delaware River Basin, Model Inputs" (https://www.sciencebase.gov/catalog/item/5f6a289982ce38aaa2449135)
  sb_item_id <- "5f6a289982ce38aaa2449135"
  
  # Download model input files to save_path
  ntw_attributes <- sbtools::item_file_download(sb_item_id, dest_dir=save_path,overwrite_file = TRUE)
  
  return(save_path)
  
}
  
