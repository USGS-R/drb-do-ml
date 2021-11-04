source("2_process/src/filter_wqp_data.R")
source("2_process/src/munge_cont_DO_data.R")

p2_targets_list <- list(
  # Filter harmonized WQP data for DO data
  tar_target(
    p2_filtered_wqp_csv,
    filter_wqp_data(p1_wqp_data,params_select,units_select,select_wqp_vars,omit_wqp_events,fileout="2_process/out/DRB_WQP_DO_data.csv")),
  # Clean and save continuous DO data 
  tar_target(
    p2_cont_DO_csv,
    combine_cont_DO_data(p1_cont_DO_data_ls,fileout="2_process/out/DRB_cont_DO_data.csv"))
)
