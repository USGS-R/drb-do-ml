get_inst_nwis_data <- function(site_info,parameter) {
  #' 
  #' @description Function to download NWIS instantaneous data
  #'
  #' @param site_info a data frame containing site info for NWIS instantaneous site. site_info must include the variable "site_no"
  #' @param parameter a character vector containing the USGS parameter codes of interest
  #'
  #' @value A data frame containing instantaneous values and data quality codes for the parameter of interest
  #' @examples 
  #' get_inst_nwis_data(site_info = data.frame(site_no="01484272"),parameter="00300")
  
  message(sprintf('Retrieving instantaneous data for %s', site_info$site_no))

  # Download instantaneous data
  site_data <- dataRetrieval::readNWISuv(
    siteNumbers = site_info$site_no,parameterCd=parameter,startDate = "",endDate = "",tz="America/New_York") %>%
    dataRetrieval::renameNWISColumns(p00300="Value",p00095="Value") 
  
  # Munge column names for some sites with different or unusually-named value columns
  if(length(grep("Value_Inst_cd",names(site_data)))>1){
    if(parameter == '00300') {
      site_data <- switch(
        site_info$site_no[1],
        "01467200" = site_data %>%
          mutate(Value_Inst_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst`,`Value_Inst`),
                 Value_Inst_cd_merged = coalesce(`ISM.Test.Bed...ISM.Test.Bed..barge.._Value_Inst_cd`,`Value_Inst_cd`)) %>%
          select(agency_cd,site_no,dateTime,Value_Inst_merged,Value_Inst_cd_merged,tz_cd) %>%
          rename("Value_Inst"="Value_Inst_merged","Value_Inst_cd"="Value_Inst_cd_merged"))
    }
  }

  # Return instantaneous data
  site_data_out <- site_data %>%
    mutate(Parameter=c("00095"="SpecCond","00300"="DO")[parameter]) %>%
    rename("time_zone" = "tz_cd") %>%
    select(agency_cd,site_no,dateTime,Parameter,Value_Inst,Value_Inst_cd,time_zone)
    
  return(site_data_out)
}
