#' Function to download NHDPlus flowlines given a set of COMIDs, HUC8 codes, or AOI
#' 
#' @param comid character string or vector of character strings containing
#' the common identifier (COMID) of the desired flowline(s). Defaults to NULL.
#' @param huc8 character string or vector of character strings containing
#' the HUC8 sub-basin(s) over which to fetch flowlines. Defaults to NULL.
#' @param aoi sf or sfc polygon object that represents the area of interest
#' over which to fetch flowlines. Defaults to NULL.
#' 
#' @details One of `comid`, `huc8`, or `aoi` should be NULL. In other words, the 
#' user should choose to download flowlines by COMID, HUC8 identifier, OR AOI.
#' 
#' 
download_nhdplus_flowlines <- function(comid = NULL, huc8 = NULL, aoi = NULL){
  
  check_args <- c(is.null(comid), is.null(huc8), is.null(aoi))
    
  if(length(check_args[check_args == TRUE]) < 2){
    stop("download_nhdplus_flowlines accepts arguments `comid` OR 
         `huc8` OR `aoi`, but only one of them should not be NULL.")
  }
  
  # Download flowlines by comid
  if(!is.null(comid)){
  
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
  } 
  
  # Download flowlines by HUC8
  if(!is.null(huc8)){
    flines_by_huc <- huc8 %>%
      lapply(.,function(x){
        # create spatial object of huc8 basin
        huc8_basin <- nhdplusTools::get_huc8(id=x)
        # download NHDPlusV2 flowlines within each huc8 bbox
        huc8_flines <- nhdplusTools::get_nhdplus(AOI = huc8_basin, 
                                                 realization = "flowline")
      })
    
    # Bind HUC8 flowlines together 
    flowlines <- flines_by_huc %>%
      bind_rows()
  }
  
  # Download flowlines by area of interest 
  if(!is.null(aoi)){
    flowlines <- nhdplusTools::get_nhdplus(AOI = aoi, 
                                           realization = "flowline")
  }
  
  # Reformat variable names to uppercase
  flowlines <- flowlines %>%
    rename_with(.,toupper,id:enabled)
  
  return(flowlines)
  
}

