source("2_process/src/filter_wqp_data.R")
source("2_process/src/subset_wqp_sites.R")
source("2_process/src/munge_inst_timeseries.R")
source("2_process/src/create_site_list.R")
source("2_process/src/summarize_site_list.R")
source("2_process/src/save_target_ind_files.R")
source("2_process/src/match_sites_reaches.R")
source("2_process/src/calc_daily_light.R")
source("2_process/src/metab_utils.R")
source("2_process/src/combine_nhdv2_attributes.R")
source("1_fetch/src/write_data.R")

# Explicitly attach sf package to handle geometry data when mapping over `p1_reaches_sf`
library(sf)

p2_targets_list <- list(
  
  # Filter harmonized WQP data for DO data
  tar_target(
    p2_filtered_wqp_data,
    filter_wqp_data(p1_wqp_data, params_select, units_select, wqp_vars_select, omit_wqp_events)
  ),
  
  # Subset harmonized WQP data to lower DRB
  tar_target(
    p2_filtered_wqp_data_subset,
    subset_wqp_sites(p2_filtered_wqp_data, drb_huc8s)
  ),
  
  # Create and save indicator file for WQP data
  tar_target(
    p2_wqp_ind_csv,
    command = save_target_ind_files("2_process/log/wqp_data_ind.csv","p2_wqp_data_subset"),
    format = "file"
  ),
  
  # Aggregate instantaneous DO data to daily min/mean/maxs
  tar_target(
    p2_inst_data_daily,
    aggregate_data_to_daily(inst_data = p1_inst_data,
                            daily_data = p1_daily_data, 
                            min_daily_coverage = 0.5, 
                            output_tz = "America/New_York")
  ),

  # Combine 1) daily DO data and 2) instantaneous DO data that has been aggregated to daily 
  tar_target(
    p2_daily_combined,
    bind_rows(p1_daily_data, p2_inst_data_daily)
  ),
  
  # Create a list of unique site locations containing DO data  
  tar_target(
    p2_site_list,
    create_site_list(wqp_data = p2_filtered_wqp_data_subset,
                     nwis_sites = p1_nwis_sites,
                     nwis_daily_data = p1_daily_data,
                     nwis_inst_data = p1_inst_data,
                     hucs = drb_huc8s,
                     crs_out="NAD83")
  ), 

  # Create and save log file containing data availability summary
  tar_target(
    p2_sitelist_summary_csv,
    summarize_site_list(p2_site_list, p1_daily_data, p1_inst_data,
                        fileout = "2_process/log/sitelist_summary.csv"),
    format = "file"
  ),

  # Match NHDPlusv2 flowlines to observation site ids and return subset of sites 
  # within the distance specified by search_radius (in meters)
  tar_target(
    p2_sites_w_segs,
    {
      
    # Flowlines with no catchments do not have any associated climate driver data, 
    # so omit any flowlines where AREASQKM == 0 before matching sites to reaches.
      nhd_reaches_w_cats <- p1_nhd_reaches_sf %>%
        filter(AREASQKM > 0)
      sites_w_segs <- get_site_nhd_flowlines(nhd_lines = nhd_reaches_w_cats, 
                                             sites = p2_site_list, 
                                             sites_crs = 4269, 
                                             max_matches = 1,
                                             search_radius = 500)
      
      # update site to reach matches based on p1_ref_gages_manual
      sites_w_segs_QC <- sites_w_segs %>%
        left_join(y = p1_ref_gages_manual[,c("id","COMID_QC")], 
                  by = c("site_id" = "id")) %>%
        mutate(COMID_updated = ifelse(site_id %in% p1_ref_gages_manual$id,
                                      COMID_QC, COMID)) %>%
        filter(!is.na(COMID_updated)) %>% 
        select(-c(COMID, bird_dist_to_comid_m, COMID_QC)) %>%
        rename(COMID = COMID_updated)
    }
    ),

  # Add the segment ids as a new column to the daily combined data
  tar_target(
    p2_daily_with_seg_ids,
    {
      seg_and_site_ids <- p2_sites_w_segs %>% 
        select(site_id, COMID)
      
      left_join(p2_daily_combined, seg_and_site_ids, 
                by=c("site_no" = "site_id")) %>%
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
   p2_sites_w_segs %>% 
     filter(count_days_total > 300) %>% 
     pull(site_id)
 ),
 
 # filter p1_reaches_sf to segments with "well-observed" sites
 tar_target(   
   p2_well_observed_reaches,
   {
   well_obs_reach_ids <- p2_sites_w_segs %>%
     filter(site_id %in% p2_well_observed_sites) %>% 
     pull(COMID)
   p1_nhd_reaches_sf %>% filter(COMID %in% well_obs_reach_ids)
   }
 ),
 
 # make list of "moderately-observed" sites
 tar_target(
   p2_med_observed_sites,
   p2_sites_w_segs %>%
     filter(count_days_nwis >= 100) %>%
     pull(site_id)
 ),
 
 # filter p1_reaches_sf to segments with "well-observed" sites
 tar_target(   
   p2_med_observed_reaches,
   {
     med_obs_reach_ids <- p2_sites_w_segs %>%
       filter(site_id %in% p2_med_observed_sites) %>% 
       pull(COMID)
     p1_nhd_reaches_sf %>% filter(COMID %in% med_obs_reach_ids)
   }
 ),
 
 # Estimate daily (normalized) max-light
 tar_target(
   p2_daily_max_light,
   { 
     calc_seg_light_ratio(p2_med_observed_reaches, 
                          start_date = earliest_date, 
                          end_date = latest_date)
   },
   pattern = map(p2_med_observed_reaches)
 ),

 # Filter daily metabolism estimates based on model diagnostics
 tar_target(
   p2_metab_filtered,
   filter_metab_sites(p1_metab,p1_metab_diagnostics,
                      sites = p2_daily_with_seg_ids$site_id,
                      model_conf_vals = c("H"),
                      cutoff_ER_K_corr = 0.4)
 ),
 
 # Read in the individual catchment attribute tables, replace any -9999 values
 # with NA, and combine into a list.
 tar_target(
   p2_cat_attr_list,
   process_attr_tables(p1_sb_attributes_downloaded_csvs,
                     cols = c("CAT")),
   pattern = map(p1_sb_attributes_downloaded_csvs),
   iteration = "list"
 ),
 
 # Loop through the catchment attribute list and join individual data frames by 
 # COMID. Combine catchment attributes with NHDPlusv2 value-added attributes (vaa)
 # and subset the data frame to the COMIDs included in the site list.
 tar_target(
   p2_seg_attr_data,
   combine_attr_data(nhd_lines = p1_nhd_reaches_sf, 
                     cat_attr_list = p2_cat_attr_list,
                     vaa_cols = c("SLOPE"),
                     sites_w_segs = p2_sites_w_segs)
 ),
 
 # Subset the DRB meteorological data to only include the NHDPlusv2 catchments (COMID)
 # that correspond with observation locations. 
 tar_target(
   p2_met_data_at_obs_sites,
   {
     reticulate::source_python("2_process/src/subset_nc_to_comid.py")
     subset_nc_to_comids(p1_drb_nhd_gridmet, p2_med_observed_reaches$COMID) %>%
       as_tibble() %>%
       relocate(c(COMID,time), .before = "tmmx")
   }
 )

)
