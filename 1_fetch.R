source("1_fetch/src/fetch_harmonized_wqp_data.R")
source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/get_daily_nwis_data.R")
source("1_fetch/src/get_inst_nwis_data.R")
source("1_fetch/src/write_data.R")

p1_targets_list <- list(
  
  # Get watershed boundary data
  tar_target(
    p1_lowerdrb_boundary,
    nhdplusTools::get_huc8(id = drb_huc8s,t_srs=4269) %>% sf::st_union() %>% sf::st_make_valid()
  ),
  
  # Load harmonized WQP data product for discrete samples
  tar_target(
    p1_wqp_data,
    fetch_harmonized_wqp_data("1_fetch/out")),
  
  # Identify NWIS sites with DO data 
  tar_target(
    p1_nwis_sites,
    {
      dummy <- dummy_date
      get_nwis_sites(drb_huc8s,pcode_select,site_tp_select,stat_cd_select)
    }
  ),
  
  # Subset daily NWIS sites
  tar_target(
    p1_nwis_sites_daily,
    p1_nwis_sites %>%
      # retain "dv" sites that contain data records after user-specified {earliest_date}
      filter(data_type_cd=="dv",!(site_no %in% omit_nwis_sites),end_date > earliest_date) %>%
      # for sites with multiple time series (ts_id), retain the most recent time series for site_info
      group_by(site_no) %>% arrange(desc(end_date)) %>% slice(1)),
  
  # Download NWIS daily data
  tar_target(
    p1_daily_data,
    get_daily_nwis_data(p1_nwis_sites_daily,pcode_select,stat_cd_select,start_date=earliest_date,end_date=dummy_date),
    pattern = map(p1_nwis_sites_daily)),
  
  # Save NWIS daily data
  tar_target(
    p1_daily_data_csv,
    write_to_csv(p1_daily_data, outfile="1_fetch/out/daily_do_data.csv"),
    format = "file"
  ),
  
  # Subset NWIS sites with instantaneous (sub-daily) data
  tar_target(
    p1_nwis_sites_inst,
    p1_nwis_sites %>%
      # retain "uv" sites that contain data records after user-specified {earliest_date}
      filter(data_type_cd=="uv",!(site_no %in% omit_nwis_sites),end_date > earliest_date) %>%
      # for sites with multiple time series (ts_id), retain the most recent time series for site_info
      group_by(site_no) %>% arrange(desc(end_date)) %>% slice(1)),
  
  # Create log file to track sites with multiple time series
  tar_target(
    p1_nwis_sites_inst_multipleTS_csv,
    p1_nwis_sites %>%
      # retain "uv" sites that contain data records after user-specified {earliest_date}
      filter(data_type_cd=="uv",!(site_no %in% omit_nwis_sites),end_date > earliest_date) %>%
      # save record of sites with multiple time series
      group_by(site_no) %>% mutate(count_ts = length(unique(ts_id))) %>%
      filter(count_ts > 1) %>%
      readr::write_csv(.,"3_visualize/log/summary_multiple_inst_ts.csv")),

  # Download NWIS instantaneous data
  tar_target(
    p1_inst_data,
    get_inst_nwis_data(p1_nwis_sites_inst,pcode_select,start_date=earliest_date,end_date=dummy_date),
    pattern = map(p1_nwis_sites_inst)),
  
  # Save NWIS instantaneous data
  tar_target(
    p1_inst_data_csv,
    write_to_csv(p1_inst_data, outfile="1_fetch/out/inst_do_data.csv"),
    format = "file"
  )
  
)


