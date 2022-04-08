source("1_fetch/src/fetch_sb_data.R")
source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/get_daily_nwis_data.R")
source("1_fetch/src/get_inst_nwis_data.R")
source("1_fetch/src/write_data.R")
source("1_fetch/src/summarize_timeseries.R")


p1_targets_list <- list(
  
  # download WQP data product from science base for discrete samples
  tar_target(
    p1_wqp_data_file,
    download_sb_file(sb_id = "5e010424e4b0b207aa033d8c",
                     file_name = "Water-Quality Data.zip",
                     out_dir="1_fetch/out"),
    format = "file"
  ),

  # load WQP data into R object
  tar_target(
    p1_wqp_data,
    {
      unzip(zipfile=p1_wqp_data_file,exdir = "1_fetch/out",overwrite=TRUE)
      readRDS(paste("1_fetch/out","/Water-Quality Data/DRB.WQdata.rds",sep=""))
    }
  ),
  
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


  # Download NWIS daily data for other parameters (flow, temperature, SC) (see codes below)
  tar_target(
    p1_daily_aux_data,
    dataRetrieval::readNWISdv(
                              siteNumbers = p1_nwis_sites_daily$site_no,
                              parameterCd=c("00060", "00010", "00095"),
                              statCd=stat_cd_select,
                              startDate=earliest_date,
                              endDate=dummy_date) %>%
    dataRetrieval::renameNWISColumns() %>%
    select(!starts_with("..2..")),
    pattern = map(p1_nwis_sites_daily)),

  # Save daily aux data to csv
  tar_target(
    p1_daily_aux_csv,
    write_to_csv(p1_daily_aux_data, outfile="1_fetch/out/daily_aux_data.csv"),
    format = "file"),
  
  # Subset NWIS sites with instantaneous (sub-daily) data
  tar_target(
    p1_nwis_sites_inst,
    p1_nwis_sites %>%
      # retain "uv" sites that contain data records after user-specified {earliest_date} and
      # before user-specified {dummy_date}
      filter(data_type_cd=="uv",
             !(site_no %in% omit_nwis_sites),
             end_date > earliest_date,
             begin_date < dummy_date) %>%
      # for sites with multiple time series (ts_id), retain the most recent time series for site_info
      group_by(site_no) %>% arrange(desc(end_date)) %>% slice(1)),
  
  # Download NWIS instantaneous data
  tar_target(
    p1_inst_data,
    get_inst_nwis_data(p1_nwis_sites_inst,pcode_select,start_date=earliest_date,end_date=dummy_date),
    pattern = map(p1_nwis_sites_inst)),
  
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

  # fetch prms met data
  tar_target(
    p1_prms_met_data_zip,
    download_sb_file(sb_id = "5f6a289982ce38aaa2449135",
                     file_name = "sntemp_inputs_outputs_drb.zip",
                     out_dir = "1_fetch/out"),
    format = "file"
  ),

  # unzip prms met data
  tar_target(
    p1_prms_met_data_csv,
    {
    unzip(zipfile=p1_prms_met_data_zip,exdir = dirname(p1_prms_met_data_zip),overwrite=TRUE)
    file.path(dirname(p1_prms_met_data_zip), "sntemp_inputs_outputs_drb.csv")
    },
    format = "file"
  ),

  # read in prms met data
  tar_target(
    p1_prms_met_data,
    read_csv(p1_prms_met_data_csv, show_col_types = FALSE)
  ),

  # read in prms met data
  # [Jeff] I'm including these in the "in" folder because they are unpublished
  # They are built in the delaware_model_prep pipeline (1_network/out/seg_attr_drb.feather)
  tar_target(
    p1_seg_attr_data,
    arrow::read_feather("1_fetch/in/seg_attr_drb.feather")
  ),
  
  # Download DRB network adjacency matrix
  tar_target(
    p1_ntw_adj_matrix_csv,
    download_sb_file(sb_id = "5f6a289982ce38aaa2449135",
                     file_name = "distance_matrix_drb.csv",
                     out_dir="1_fetch/out"),
    format="file"
  ),
  
  # Read in network adjacency matrix
  tar_target(
    p1_ntw_adj_matrix,
    read_csv(p1_ntw_adj_matrix_csv,show_col_types = FALSE)
  ),

  # Download and unzip metabolism estimates from https://www.sciencebase.gov/catalog/item/59eb9c0ae4b0026a55ffe389
  tar_target(
    p1_metab_tsv,
    {
    metab_file <- download_sb_file(sb_id = "59eb9c0ae4b0026a55ffe389",
                                   file_name = "daily_predictions.zip",
                                   out_dir="1_fetch/out")
    unzip(zipfile=metab_file, exdir = dirname(metab_file), overwrite=TRUE)
    file.path(dirname(metab_file), "daily_predictions.tsv")
    },
    format="file" 
  ),
  
  # Load downloaded metabolism estimates
  tar_target(
    p1_metab,
      read_tsv(p1_metab_tsv, show_col_types = FALSE) %>%
      # create a new column "site_id". This column is the same as site_name from the
      # original data, but the 'nwis_' before the site number is removed to match site naming
      # conventions used in our pipeline.
      mutate(site_id = str_replace(site_name, "nwis_", ""))
    
  ),
  
  # Download and unzip metabolism diagnostics from https://www.sciencebase.gov/catalog/item/59eb9bafe4b0026a55ffe382
  # metab diagnostics contains 1 row per streamMetabolizer model for each site
  tar_target(
    p1_metab_diagnostics_tsv,
    {
    diagnostics_file <- download_sb_file(sb_id = "59eb9bafe4b0026a55ffe382",
                                         file_name = "diagnostics.zip",
                                         out_dir="1_fetch/out")
    unzip(zipfile=diagnostics_file, exdir = dirname(diagnostics_file), overwrite=TRUE)
    file.path(dirname(diagnostics_file), "diagnostics.tsv")
    }
  ),
  
  tar_target(
    p1_metab_diagnostics,
    read_tsv(p1_metab_diagnostics_tsv, show_col_types = FALSE) %>%
      # create a new column "site_id"; see p1_metab target for details.
      mutate(site_id = str_replace(site, "nwis_",""),
             resolution = str_replace(resolution, "min",""))
  )

)  

