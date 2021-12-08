source("2_process/src/filter_wqp_data.R")
source("2_process/src/subset_wqp_sites.R")
source("2_process/src/munge_inst_timeseries.R")
source("2_process/src/create_site_list.R")

p2_targets_list <- list(
  
  # Filter harmonized WQP data for DO data
  tar_target(
    p2_filtered_wqp_data,
    filter_wqp_data(p1_wqp_data,params_select,units_select,wqp_vars_select,omit_wqp_events)),
  
  # Subset harmonized WQP data to lower DRB
  tar_target(
    p2_filtered_wqp_data_subset,
    subset_wqp_sites(p1_lowerdrb_boundary,p2_filtered_wqp_data)),
  
  # Aggregate instantaneous DO data to hourly averages
  tar_target(
    p2_inst_data_hourly,
    aggregate_data_to_hourly(p1_inst_data,output_tz = "UTC"),
    pattern = map(p1_inst_data)),
  
  # Aggregate instantaneous DO data to daily min/mean/maxs
  tar_target(
    p2_inst_data_daily,
    aggregate_data_to_daily(p1_inst_data,p1_daily_data)),

  # Combine 1) daily DO data and 2) instantaneous DO data that has been aggregated to daily 
  tar_target(
    p2_daily_combined,
    bind_rows(p1_daily_data, p2_inst_data_daily)),
  
  # Create a list of unique site locations containing DO data  
  tar_target(
    p2_site_list_csv,
    create_site_list(p2_filtered_wqp_data_subset,p1_lowerdrb_boundary,p1_nwis_sites,p1_daily_data,p2_inst_data_hourly,fileout = "2_process/out/DRB_DO_sitelist.csv"),
    format = "file")

)
