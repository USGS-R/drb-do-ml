source("2_process/src/filter_wqp_data.R")
source("2_process/src/create_site_list.R")

p2_targets_list <- list(
  
  # Filter harmonized WQP data for DO data
  tar_target(
    p2_filtered_wqp_data,
    filter_wqp_data(p1_wqp_data,params_select,units_select,wqp_vars_select,omit_wqp_events)),
  
  # Create a list of unique site locations containing DO data  
  tar_target(
    p2_site_list_csv,
    create_site_list(p2_filtered_wqp_data,p1_nwis_sites,p1_daily_data,p1_inst_data,fileout = "2_process/out/DRB_DO_sitelist.csv"),
    format = "file")

)
