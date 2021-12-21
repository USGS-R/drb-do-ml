aggregate_data_to_hourly <- function(inst_data,output_tz){
  #' 
  #' @description Function to aggregate instantaneous NWIS data collected at sub-hourly (e.g. 15/5/30 min) intervals to hourly averages
  #'
  #' @param inst_data a data frame containing the downloaded time series for NWIS instantaneous site. 
  #' inst_data must include the following columns: c("Value_Inst","Value_Inst_cd","dateTime","agency_cd","site_no","time_zone",and "Parameter")
  #' @param output_tz character string to set display attribute of dateTime. Possible values to provide are "UTC",
  #' "America/New_York","America/Chicago", "America/Denver","America/Los_Angeles", "America/Anchorage", 
  #' as well as the following which do not use daylight savings time: "America/Honolulu", "America/Jamaica",
  #' "America/Managua","America/Phoenix", and "America/Metlakatla"
  #'
  #' @value A data frame containing hourly average values for the hour and original data quality codes for the parameter of interest
  #' @examples 
  #' aggregate_data_to_hourly(inst_data = filter(p1_nwis_sites,site_no=="01484272"))
  
  message(sprintf('Estimating hourly average values for %s', inst_data$site_no[1]))
  
  # Check that inst_data contains required columns
  req_cols <- c("Value_Inst","Value_Inst_cd","dateTime","agency_cd","site_no","time_zone","Parameter")
  flag_cols <- req_cols[which(req_cols %in% names(inst_data)=="FALSE")]
  if(length(flag_cols)>0) stop("Input data is missing one or more required columns: dateTime,agency_cd,site_no,time_zone,Parameter,Value_Inst,Value_Inst_cd")

  # Aggregate values to hourly averages:
  data_hourly <- inst_data %>%
    # first clean timestamps by rounding to nearest 5 min interval (e.g. 10:59:00 becomes 11:00:00) then create new hourly timestamp:
    mutate(dateTime_round = lubridate::round_date(dateTime,unit="5 minutes"),
           Date = lubridate::date(dateTime_round),
           Hour = lubridate::hour(dateTime_round),
           dateTime_aggr = as.POSIXct(paste(Date,paste0(Hour,":45"),sep=" "),tz=time_zone[1])) %>%
    group_by(dateTime_aggr,agency_cd,site_no,time_zone,Parameter) %>%
    summarize(Value_Inst_hourly = mean(Value_Inst,na.rm=TRUE),
              Value_Inst_cd = unique(Value_Inst_cd),
              n_subhourly_obs = sum(!is.na(Value_Inst)),
              .groups="keep") %>%
    ungroup() %>% 
    select(agency_cd,site_no,dateTime_aggr,Parameter,Value_Inst_hourly,time_zone,Value_Inst_cd,n_subhourly_obs)
  
  # Pad time series:
  data_complete_ts <- data_hourly %>%
    tidyr::complete(dateTime_aggr = seq.POSIXt(min(dateTime_aggr),max(dateTime_aggr),by="1 hour"),
                    fill=list(agency_cd=.$agency_cd[1],
                              site_no=.$site_no[1],
                              Parameter=.$Parameter[1],
                              time_zone=.$time_zone[1],
                              n_subhourly_obs = 0))
  
  # Format timestamps according to desired time zone:
  data_out <- data_complete_ts %>%
    mutate(dateTime_out = lubridate::with_tz(dateTime_aggr,tzone = output_tz),
           time_zone = lubridate::tz(dateTime_out)) %>%
    select(agency_cd,site_no,dateTime_out,Parameter,Value_Inst_hourly,Value_Inst_cd,n_subhourly_obs,time_zone) %>%
    rename("dateTime" = "dateTime_out")
  
  return(data_out)

}



aggregate_data_to_daily <- function(inst_data, daily_data, min_daily_coverage, output_tz){
  #' 
  #' @description Function to aggregate instantaneous NWIS data collected at sub-hourly (e.g. 15/5/30 min) intervals to hourly min/mean/maxs
  #'
  #' @param inst_data a data frame containing the downloaded time series for NWIS instantaneous site. 
  #' inst_data must include the following columns: c("Value_Inst","dateTime","site_no")
  #' @param daily_data a data frame the downloaded daily time series of DO data. This is used so that if a site is already in 
  #'  the daily sites, we won't do the aggregating here
  #' @param min_daily_coverage - float 0-1, minimum coverage needed to return daily summaries.
  #' A min_daily_coverage of 0.5 means that summary stats will be calculated for 
  #' days with at least 50% coverage. Coverage is calculated on a daily basis
  #'  as (num_non_na_vals/(num_non_na_vals + num_na_vals))
  #' 
  #' @param output_tz character string to set display attribute of dateTime. Possible values to provide are "UTC",
  #' "America/New_York","America/Chicago", "America/Denver","America/Los_Angeles", "America/Anchorage", 
  #' as well as the following which do not use daylight savings time: "America/Honolulu", "America/Jamaica",
  #' "America/Managua","America/Phoenix", and "America/Metlakatla"
  #'
  #' @value A data frame containing daily min, mean, and max values the parameter of interest
  
  
  only_inst_data = setdiff(inst_data$site_no, daily_data$site_no)
  
  daily_values <- inst_data %>%
    filter(site_no %in% only_inst_data) %>%
    mutate(dateTime_local = lubridate::with_tz(dateTime,tzone=output_tz),
           Date = lubridate::date(dateTime_local)) %>%
    group_by(site_no, Date, agency_cd, Parameter) %>%
    summarise(Value = mean(Value_Inst, na.rm=TRUE), 
              Value_Min = min(Value_Inst, na.rm=TRUE), 
              Value_Max = max(Value_Inst,na.rm=TRUE), 
              na_count=sum(is.na(Value_Inst)), 
              value_count=sum(!is.na(Value_Inst)),
              Value_cd = first(Value_Inst_cd),
              Value_Max_cd = first(Value_Inst_cd),
              Value_Min_cd = first(Value_Inst_cd),
              .groups="keep") %>%
    mutate(percent_coverage=value_count/(value_count + na_count)) %>%
    filter(percent_coverage >= min_daily_coverage) %>%
    select(-c(na_count, value_count, percent_coverage))
  
  return(daily_values)
}

