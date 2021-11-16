get_daily_nwis_data <- function(site_info,pcodes_select,stat_cd_select) {
  #' 
  #' @description Function to download NWIS daily data
  #'
  #' @param site_info data frame containing site info for NWIS daily site, including the variable "site_no"
  #' @param pcodes_select a character vector containing the USGS parameter codes of interest
  #' @param stat_cd_select a character vector containing the USGS stat codes to retain
  #'
  #' @value A data frame containing daily values and data quality codes for each stat code (e.g. min/max/mean)
  #' @examples 
  #' get_daily_nwis_data(site_info = daily_sites,pcodes_select="00300",stat_cd_select="00003")
  
  message(sprintf('Retrieving daily data for %s', site_info$site_no))

  # Download daily data
  site_data <- dataRetrieval::readNWISdv(
    siteNumbers = site_info$site_no,parameterCd=pcodes_select,statCd=stat_cd_select,startDate = "",endDate = "") %>%
    dataRetrieval::renameNWISColumns() 
  
  # Filter daily data
  site_data_out <- site_data %>%
           # omit rows with no data
    filter(!(is.na(DO) & is.na(DO_Max) & is.na(DO_Min)),
           # omit rows where daily mean > daily max; daily min > daily max; or daily min > daily mean
          (is.na(DO)|is.na(DO_Min)|is.na(DO_Max)|(!DO > DO_Max)),
          (is.na(DO)|is.na(DO_Min)|is.na(DO_Max)|(!DO_Min > DO_Max)),
          (is.na(DO)|is.na(DO_Min)|is.na(DO_Max)|(!DO_Min > DO)))
  
  return(site_data_out)
}
