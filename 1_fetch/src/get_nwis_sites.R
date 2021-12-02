get_nwis_sites <- function(hucs,pcodes_select,site_tp_select,stat_cd_select){
  #' 
  #' @description Function to return a table of NWIS sites within the area of interest that have data for the desired USGS parameter codes
  #'
  #' @param hucs a character vector containing the major or minor HUCs (hydrologic unit codes) over which to search.
  #'  A major HUC is 2 digits in length and a minor HUC is 8 digits in length. 
  #' @param pcodes_select a character vector containing the USGS parameter codes of interest
  #' @param site_tp_select a character vector containing the USGS site types to retain
  #' @param stat_cd_select a character vector containing the USGS stat codes to retain
  #'
  #' @return a data frame with site information. See ??readNWISdata for more information and column descriptions
  #' @examples 
  #' get_nwis_sites(hucs = "02040101",pcodes_select = "00095",site_tp_select = c("ST","SP","ST-CA","ES"))
  #' get_nwis_sites(hucs = c("02040101","02040102"),pcodes_select="00095",site_tp_select=c("ST"))
  
  # Search for sites separately by HUC8 region since calls to readNWISdata allow no more than 10 minor HUCs to be specified:
  nwis_sites_ls <- lapply(hucs,function(x)
    dataRetrieval::readNWISdata(huc=x,parameterCd=pcodes_select,service="site",seriesCatalogOutput=TRUE))
  
  # Return a data frame of NWIS sites that contain the parameter(s) of interest and the preferred site types:
  nwis_sites <- nwis_sites_ls %>% 
    do.call(rbind,.) %>%
    filter(parm_cd %in% pcodes_select,
           site_tp_cd %in% site_tp_select,
           (data_type_cd=="dv" & stat_cd %in% stat_cd_select)|data_type_cd=="uv"|data_type_cd=="qw")
  
  return(nwis_sites)
  
} 
