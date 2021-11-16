source("1_fetch/src/fetch_harmonized_wqp_data.R")
source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/get_daily_nwis_data.R")

p1_targets_list <- list(
  
  # Load harmonized WQP data product for discrete samples
  tar_target(
    p1_wqp_data,
    fetch_harmonized_wqp_data("1_fetch/out")),
  
  # Identify NWIS sites with continuous DO data ("dv" or "uv")
  tar_target(
    p1_nwis_sites,
    get_drb_sites(drb_huc8s,DO_pcodes,site_tp_select,stat_cd_select)),
  
  # Subset daily NWIS sites
  tar_target(
    p1_nwis_sites_daily,
    filter(p1_nwis_sites,data_type_cd=="dv")),
  
  # Download NWIS daily data
  tar_target(
    p1_daily_data,
      get_daily_nwis_data(p1_nwis_sites_daily,DO_pcodes,stat_cd_select),
      pattern = map(p1_nwis_sites_daily))
  
)


