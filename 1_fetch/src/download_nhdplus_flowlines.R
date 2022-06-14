#' Function to download NHDPlus flowlines given a set of COMIDs or HUC8 codes
#' 
#' @param comid character string or vector of character strings containing
#' the common identifier (COMID) of the desired flowline(s). Defaults to NULL.
#' @param huc8 character string or vector of character strings containing
#' the HUC8 sub-basin(s) over which to fetch flowlines. Defaults to NULL.
#' 
#' @details One of `comid` or `huc8` should be NULL. In other words, the 
#' user should choose to download flowlines by COMID or HUC8.
#' 
#' 
download_nhdplus_flowlines <- function(comid = NULL, huc8 = NULL){
  
  if(!is.null(comid) & !is.null(huc8)){
    stop("download_nhdplus_flowlines accepts arguments `comid` or 
         `huc8` but not both.")
  }
  
  if(!is.null(comid)){
    
    # Download flowlines by comid
  
    # Chunk desired COMIDs into groups, where each group has no more than
    # 50 COMID's to avoid timeout errors when downloading nhdplus subsets
    # using helper functions from nhdplusTools
    comid_df <- tibble(COMID = comid) %>%
      mutate(comid_n = row_number(),
             download_grp = ((comid_n -1) %/% 50) + 1)
    
    # Download flowlines associated with desired COMIDs and return an sf
    # data frame containing the linestrings and value-added attributes 
    flowlines <- comid_df %>%
      split(., .$download_grp) %>%
      lapply(., function(x){
        flines_sub <- nhdplusTools::get_nhdplus(comid = x$COMID, 
                                                realization = "flowline")
        # format certain columns to allow merging chunked flowlines into a single
        # data frame
        flines_sub_out <- flines_sub %>%
          mutate(across(c(lakefract, surfarea, rareahload,hwnodesqkm), as.character))
        }) %>%
      bind_rows()
    
  } else {
    
    # Download flowlines by area of interest/HUC8
    flines_by_huc <- huc8 %>%
      lapply(.,function(x){
        # create spatial object of huc8 basin
        huc8_basin <- suppressMessages(nhdplusTools::get_huc8(id=x))
        # download NHDPlusV2 flowlines within each huc8 bbox
        huc8_flines <- suppressMessages(nhdplusTools::get_nhdplus(AOI = huc8_basin,
                                                                  realization="flowline"))
      })
    
    # Bind HUC8 flowlines together 
    flowlines <- flines_by_huc %>%
      bind_rows() %>%
      # Reformat variable names to uppercase
      rename_with(.,toupper,id:enabled)
  }
  
  return(flowlines)
  
}

