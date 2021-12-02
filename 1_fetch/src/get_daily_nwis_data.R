get_daily_nwis_data <- function(site_info,parameter,stat_cd_select) {
  #' 
  #' @description Function to download NWIS daily data
  #'
  #' @param site_info data frame containing site info for NWIS daily site, including the variable "site_no"
  #' @param parameter a character vector containing the USGS parameter codes of interest
  #' @param stat_cd_select a character vector containing the USGS stat codes to retain
  #'
  #' @value A data frame containing daily values and data quality codes for each stat code (e.g. min/max/mean)
  #' @examples 
  #' get_daily_nwis_data(site_info = daily_sites,parameter="00300",stat_cd_select="00003")
  
  message(sprintf('Retrieving daily data for %s', site_info$site_no))

  # Download daily data
  site_data <- dataRetrieval::readNWISdv(
    siteNumbers = site_info$site_no,parameterCd=parameter,statCd=stat_cd_select,startDate = "",endDate = "") %>%
    dataRetrieval::renameNWISColumns(p00300="Value",p00095="Value")
  
  # If no max value reported, create empty column:
  if(!('Value_Max' %in% names(site_data))){
    site_data <- site_data %>%
      add_column(Value_Max = NA,
                 Value_Max_cd = NA)
  }
  
  # Filter daily data
  site_data_out <- site_data %>%
           # omit rows with no data
    filter(!(is.na(Value) & is.na(Value_Max) & is.na(Value_Min)),
           # omit rows where daily mean > daily max; daily min > daily max; or daily min > daily mean
          (is.na(Value)|is.na(Value_Max)|(!Value > Value_Max)),
          (is.na(Value_Min)|is.na(Value_Max)|(!Value_Min > Value_Max)),
          (is.na(Value)|is.na(Value_Min)|(!Value_Min > Value)),
          # omit rows with undesired data quality codes
          !(Value_cd %in% c("P Eqp","P Mnt")),
          !(Value_Max_cd %in% c("P Eqp","P Mnt")),
          !(Value_Min_cd %in% c("P Eqp","P Mnt"))) %>%
    mutate(Parameter=c("00095"="SpecCond","00300"="DO")[parameter]) %>%
    select(agency_cd,site_no,Date,Parameter,Value,Value_cd,Value_Max,Value_Max_cd,Value_Min,Value_Min_cd)
  
  return(site_data_out)
}
