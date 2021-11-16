source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/download_DO_data.R")
source("1_fetch/src/fetch_harmonized_wqp_data.R")

p1_targets_list <- list(
  
  # Load harmonized WQP data product for discrete samples
  tar_target(
    p1_wqp_data,
    fetch_harmonized_wqp_data("1_fetch/out")),
  
  # Identify NWIS sites with continuous DO data ("dv" or "uv")
  tar_target(
    p1_DO_sites_nwis,
    get_drb_sites(drb_huc8s,DO_pcodes,site_tp_select,stat_cd_select)),
  tar_target(
    p1_daily_DO_csv,
    {
      DO_daily_sites <- p1_DO_sites_nwis %>% 
        filter(data_type_cd == "dv")
      # Download and save daily DO data
      download_daily_mean_DO_data(site_list = unique(DO_daily_sites$site_no),pcode=DO_pcodes,stat_cd="00003",fileout="1_fetch/out/DRB_daily_DO_data.csv")
    }),
  tar_target(
    p1_cont_DO_data_ls,
    {
      # Filter DO sites for sites with instantaneous DO data
      DO_cont_sites <- p1_DO_sites_nwis %>% 
        filter(data_type_cd=="uv")
      # For each site, download instantaneous DO data
      lapply(unique(DO_cont_sites$site_no),function(x)
        readNWISuv(siteNumbers = x,parameterCd=DO_pcodes,tz="America/New_York",startDate = "",endDate = ""))
    })
)


