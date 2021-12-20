get_daily_nwis_data <- function(site_info,parameter,stat_cd_select,start_date = "",end_date = "") {
  #' 
  #' @description Function to download NWIS daily data
  #'
  #' @param site_info data frame containing site info for NWIS daily site, including the variable "site_no"
  #' @param parameter a character vector containing the USGS parameter codes of interest
  #' @param stat_cd_select a character vector containing the USGS stat codes to retain
  #' @param start_date character string indicating the starting date for data retrieval (YYYY-MM-DD). 
  #' Default value is "" to indicate retrieval for the earliest possible record.
  #' @param end_date character string indicating the ending date for data retrieval (YYYY-MM-DD).
  #' Default value is "" to indicate retrieval for the latest possible record. 
  #'
  #' @value A data frame containing daily values and data quality codes for each stat code (e.g. min/max/mean)
  #' @examples 
  #' get_daily_nwis_data(site_info = daily_sites,parameter="00300",stat_cd_select="00003")
  #' get_daily_nwis_data(site_info = daily_sites,parameter="00095",stat_cd_select="00003",start_date = "2020-10-01",end_date="2021-09-30")
  
  message(sprintf('Retrieving daily data for %s', site_info$site_no))

  # Download daily data
  site_data <- dataRetrieval::readNWISdv(
    siteNumbers = site_info$site_no,parameterCd=parameter,statCd=stat_cd_select,startDate = start_date,endDate = end_date) %>%
    dataRetrieval::renameNWISColumns(p00300="Value",p00095="Value")
  
  # Munge column names for some sites with different or unusually-named value columns
  if(length(grep("Value_cd",names(site_data)))>1){
    if(parameter == '00300') {
      site_data <- switch(
        site_info$site_no[1],
        # 01467200: Potential relocation of sensors; multiple time series include ~6-month co-deployment that shows comparability of 
        # time series ('Value_Inst' and 'ISM.Test.Bed.'). Select 'Value' data when available, otherwise select ISM.Test.Bed':
        "01467200" = site_data %>%
          mutate(Value_merged = coalesce(`Value`,`ISM.Test.Bed...ISM.barge._Value`),
                 Value_cd_merged = coalesce(`Value_cd`,`ISM.Test.Bed...ISM.barge._Value_cd`)) %>%
          select(agency_cd,site_no,Date,Value_merged,Value_cd_merged,Value_Max,Value_Max_cd,Value_Min,Value_Min_cd) %>%
          rename("Value"="Value_merged","Value_cd"="Value_cd_merged"))
    }
  }
  
  # If no min/max value reported, create empty column(s):
  if(!('Value_Max' %in% names(site_data))){
    site_data <- site_data %>%
      add_column(Value_Max = NA,
                 Value_Max_cd = NA)
  }
  if(!('Value_Min' %in% names(site_data))){
    site_data <- site_data %>%
      add_column(Value_Min = NA,
                 Value_Min_cd = NA)
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
          !(grepl("eqp|mnt",Value_cd,ignore.case = TRUE)),
          !(grepl("eqp|mnt",Value_Min_cd,ignore.case = TRUE)),
          !(grepl("eqp|mnt",Value_Max_cd,ignore.case = TRUE))) %>%
    mutate(Parameter=c("00095"="SpecCond","00300"="DO")[parameter]) %>%
    select(agency_cd,site_no,Date,Parameter,Value,Value_cd,Value_Max,Value_Max_cd,Value_Min,Value_Min_cd)
  
  return(site_data_out)
}
