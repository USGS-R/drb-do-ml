source("2_process/src/filter_wqp_data.R")
source("2_process/src/subset_wqp_sites.R")
source("2_process/src/munge_inst_timeseries.R")
source("2_process/src/create_site_list.R")
source("2_process/src/summarize_site_list.R")
source("2_process/src/save_target_ind_files.R")
source("2_process/src/match_sites_reaches.R")
source("1_fetch/src/write_data.R")

p2_targets_list <- list(
  
  # Filter harmonized WQP data for DO data
  tar_target(
    p2_filtered_wqp_data,
    filter_wqp_data(p1_wqp_data,params_select,units_select,wqp_vars_select,omit_wqp_events)),
  
  # Subset harmonized WQP data to lower DRB
  tar_target(
    p2_filtered_wqp_data_subset,
    subset_wqp_sites(p2_filtered_wqp_data,drb_huc8s)),
  
  # Create and save indicator file for WQP data
  tar_target(
    p2_wqp_ind_csv,
    command = save_target_ind_files("2_process/log/wqp_data_ind.csv","p2_wqp_data_subset"),
    format = "file"),
  
  # Aggregate instantaneous DO data to daily min/mean/maxs
  tar_target(
    p2_inst_data_daily,
    aggregate_data_to_daily(p1_inst_data,p1_daily_data, min_daily_coverage=0.5, output_tz="America/New_York")),

  # Combine 1) daily DO data and 2) instantaneous DO data that has been aggregated to daily 
  tar_target(
    p2_daily_combined,
    bind_rows(p1_daily_data, p2_inst_data_daily)),
  
  # Create a list of unique site locations containing DO data  
  tar_target(
    p2_site_list,
    create_site_list(p2_filtered_wqp_data_subset,p1_nwis_sites,p1_daily_data,p1_inst_data,
                       hucs=drb_huc8s,crs_out="NAD83")
  ), 

  # Create and save log file containing data availability summary
  tar_target(
    p2_sitelist_summary_csv,
    summarize_site_list(p2_site_list,p1_daily_data,p1_inst_data,fileout = "2_process/log/sitelist_summary.csv"),
    format = "file"),

  # Match PRMS stream segments to observation site ids
  tar_target(
    p2_sites_w_segs,
    get_site_flowlines(
      p1_reaches_sf,
      p2_site_list,
      sites_crs = 4269,
      max_matches = 1,
      search_radius = 500
    )
  ),
  
  # Write the table with matched PRMS segment and observation sites to a csv file
  tar_target(
    p2_sites_w_segs_csv,
    write_to_csv(p2_sites_w_segs, "2_process/out/site_w_seg_ids.csv")
  ),
  
  # Add the segment ids as a new column to the daily combined data
  tar_target(
    p2_daily_with_seg_ids,
    {
      seg_and_site_ids <- p2_sites_w_segs %>% select(site_id, segidnat)
      left_join(p2_daily_combined, seg_and_site_ids, by=c("site_no" = "site_id")) %>%
      rename(site_id = site_no,
             date = Date,
             do_mean = Value,
             do_min = Value_Min,
             do_max = Value_Max
             )
    }  
  ), 
  
  # Save the daily combined data with segment ids to a csv file
  tar_target(
    p2_daily_with_seg_ids_csv,
    write_to_csv(p2_daily_with_seg_ids, "2_process/out/daily_do_data.csv"),
    format = "file"
  ),

  # make list of "well-observed" sites
  tar_target(
   p2_well_observed_sites,
   p2_sites_w_segs %>% filter(count_days_total > 300) %>% pull(site_id)
 )
  

)
