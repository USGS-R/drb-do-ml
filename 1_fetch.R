source("1_fetch/src/fetch_harmonized_wqp_data.R")
source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/get_daily_nwis_data.R")
source("1_fetch/src/get_inst_nwis_data.R")
source("1_fetch/src/write_data.R")
source("1_fetch/src/summarize_timeseries.R")
source("1_fetch/src/get_ntw_attributes.R")


p1_targets_list <- list(
  
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
  
  # Download NWIS instantaneous data
  tar_target(
    p1_inst_data,
    get_inst_nwis_data(p1_nwis_sites_inst,pcode_select,start_date=earliest_date,end_date=dummy_date),
    pattern = map(p1_nwis_sites_inst)),
  
  # Save NWIS instantaneous data
  tar_target(
    p1_inst_data_csv,
    write_to_csv(p1_inst_data, outfile="1_fetch/out/inst_do_data.csv"),
    format = "file"),
  
  # Create log file to track sites with multiple time series
  tar_target(
    p1_nwis_sites_inst_multipleTS_csv,
    p1_nwis_sites %>%
      # retain "uv" sites that contain data records after user-specified {earliest_date}
      filter(data_type_cd=="uv",!(site_no %in% omit_nwis_sites),end_date > earliest_date) %>%
      # save record of sites with multiple time series
      group_by(site_no) %>% mutate(count_ts = length(unique(ts_id))) %>%
      filter(count_ts > 1) %>%
      readr::write_csv(.,"1_fetch/log/summary_multiple_inst_ts.csv")),
  
  # Create and save summary log file for NWIS daily data
  tar_target(
    p1_daily_timeseries_summary_csv,
    command = target_summary_stats(p1_daily_data,"Value","1_fetch/log/daily_timeseries_summary.csv"),
    format = "file"
  ),
  
  # Create and save summary log file for NWIS instantaneous data
  tar_target(
    p1_inst_timeseries_summary_csv,
    command = target_summary_stats(p1_inst_data,"Value_Inst","1_fetch/log/inst_timeseries_summary.csv"),
    format = "file"
  ),
  
  # Download zipped shapefile of DRB PRMS reaches
  tar_target(
    p1_reaches_shp_zip,
    # [Jeff] I downloaded this manually from science base: 
    # https://www.sciencebase.gov/catalog/item/5f6a285d82ce38aaa244912e
    # Because it's a shapefile, it's not easily downloaded using sbtools
    # like other files are (see https://github.com/USGS-R/sbtools/issues/277).
    # Because of that and since it's small (<700 Kb) I figured it'd be fine to
    # just include in the repo and have it loosely referenced to the sb item ^
    "1_fetch/in/study_stream_reaches.zip",
    format = "file"
  ),
  
  # Unzip zipped shapefile
  tar_target(
    p1_reaches_shp,
    {shapedir = "1_fetch/out/study_stream_reaches"
    # `shp_files` is a vector of all files ('dbf', 'prj', 'shp', 'shx')
    shp_files <- unzip(p1_reaches_shp_zip, exdir = shapedir)
    # return just the .shp file
    grep(".shp", shp_files, value = TRUE)},
    format = "file"
  ),
  
  # read shapefile into sf object
  tar_target(
    p1_reaches_sf,
    st_read(p1_reaches_shp)
  ),
  
  # Download DRB network attributes
  tar_target(
    p1_ntw_attributes,
    get_ntw_attributes("1_fetch/out/ntw_attributes"),
    format="file"
    ),
  
  # Load network adjacency matrix
  tar_target(
    p1_ntw_adj_matrix,
    read_csv(paste0(p1_ntw_attributes,"/distance_matrix_drb.csv"),show_col_types = FALSE)
  )
)  

