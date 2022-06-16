#' @description Function to download NWIS instantaneous data
#'
#' @param site_info a data frame containing site info for NWIS instantaneous site; 
#' must include the variable "site_no"
#' @param parameter a character vector containing the USGS parameter code of interest
#' @param start_date character string indicating the starting date for data retrieval
#' (YYYY-MM-DD). Default value is "" to indicate retrieval for the earliest possible record.
#' @param end_date character string indicating the ending date for data retrieval 
#' (YYYY-MM-DD). Default value is "" to indicate retrieval for the latest possible record.
#'
#' @value A data frame containing instantaneous values and data quality codes for 
#' the parameter of interest
#' 
#' @examples 
#' get_inst_nwis_data(site_info = data.frame(site_no="01484272"),parameter="00300")
#' get_inst_nwis_data(site_info = data.frame(site_no="01484272"), parameter="00095", 
#'                   start_date = "2020-10-01", end_date="2021-09-30")
#'                   
get_inst_nwis_data <- function(site_info, parameter, start_date = "", end_date = "") {

  message(sprintf('Retrieving instantaneous data for %s', site_info$site_no))

  # Download instantaneous data
  # use default time zone = "UTC" to avoid issues with daylight savings time
  site_data <- dataRetrieval::readNWISuv(siteNumbers = site_info$site_no, 
                                         parameterCd=parameter,
                                         startDate = start_date,
                                         endDate = end_date,
                                         tz = "UTC") %>%
    dataRetrieval::renameNWISColumns(p00300="Value",p00095="Value") 
  
  # Munge column names for some sites with different or unusually-named value columns
  if(length(grep("Value_Inst_cd",names(site_data)))>1){
    if(parameter == '00300') {
      site_data <- switch(
        site_info$site_no[1],
        # 01467200: Potential relocation of sensors; multiple time series include ~6-month 
        # co-deployment that shows comparability of time series ('Value_Inst' and 'ISM.Test.Bed.'). 
        # Select 'ISM.Test.Bed' when data are available, otherwise select 'Value_Inst' data:
        "01467200" = site_data %>%
          mutate(Value_Inst_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst`,`Value_Inst`),
                 Value_Inst_cd_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst_cd`,`Value_Inst_cd`)) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"),
        # 01482537: No site remarks given to indicate preferred time series, therefore, select 
        # longer ts (ts_id = 290960, "at.0.5.ft.depth_Value_Inst"):
        "01482537" = site_data %>%
          mutate(Value_Inst_merged = at.0.5.ft.depth_Value_Inst,
                 Value_Inst_cd_merged = at.0.5.ft.depth_Value_Inst_cd) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"))
    }
    if(parameter == "00095") {
      site_data <- switch(
        site_info$site_no[1],
        # 01434498: Returned data contains time series from 'Side.Channel' and multiple piezometers. 
        # Select data that are representative of the main river channel:
        "01434498" = site_data %>%
          select(agency_cd,site_no,dateTime,Value_Inst,Value_Inst_cd,tz_cd),
        # 01435000: Returned data contains time series from 'Intake' and multiple piezometers. 
        # Select data that are representative of the main river channel:
        "01435000" = site_data %>%
          mutate(Value_Inst_merged = Channel.WQ_Value_Inst,
                 Value_Inst_cd_merged = Channel.WQ_Value_Inst_cd) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"),
        # 01467200: Potential sensor relocation; multiple time series include co-deployment period 
        # that shows comparability of time series ('Value_Inst', 'ISM.Test.Bed.'). Select 'ISM.Test.Bed' 
        # when data are available, otherwise select 'Value_Inst' data:
        "01467200" = site_data %>%
          mutate(Value_Inst_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst`,`Value_Inst`),
                 Value_Inst_cd_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst_cd`,`Value_Inst_cd`)) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"),
        # 01482537: No site remarks given to indicate preferred time series, therefore, select 
        # longer ts (ts_id = 290960, "at.0.5.ft.depth_Value_Inst"):
        "01482537" = site_data %>%
          mutate(Value_Inst_merged = at.0.5.ft.depth_Value_Inst,
                 Value_Inst_cd_merged = at.0.5.ft.depth_Value_Inst_cd) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"))
    }
  }

  # Return instantaneous data
  site_data_out <- site_data %>%
    # omit rows with undesired data quality codes
    filter(!(grepl("eqp|mnt", Value_Inst_cd, ignore.case = TRUE))) %>%
    mutate(Parameter = c("00095" = "SpecCond", "00300" = "DO")[parameter]) %>%
    rename("time_zone" = "tz_cd") %>%
    select(agency_cd, site_no, dateTime, Parameter, Value_Inst, Value_Inst_cd, time_zone)
    
  return(site_data_out)
}
