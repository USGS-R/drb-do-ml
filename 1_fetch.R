source("1_fetch/src/fetch_harmonized_wqp_data.R")
source("1_fetch/src/get_nwis_sites.R")
source("1_fetch/src/get_daily_nwis_data.R")
source("1_fetch/src/get_inst_nwis_data.R")

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
      filter(data_type_cd=="dv",!(site_no %in% omit_nwis_sites)) %>%
      group_by(site_no) %>% slice(1)),

  # Download NWIS daily data
  tar_target(
    p1_daily_data,
    get_daily_nwis_data(p1_nwis_sites_daily,pcode_select,stat_cd_select),
    pattern = map(p1_nwis_sites_daily)),
  
  # Subset NWIS sites with instantaneous (sub-daily) data
  tar_target(
    p1_nwis_sites_inst,
    p1_nwis_sites %>%
      filter(data_type_cd=="uv",!(site_no %in% omit_nwis_sites)) %>%
      group_by(site_no) %>% slice(1)),
  
  # Download NWIS instantaneous data
  tar_target(
    p1_inst_data,
    get_inst_nwis_data(p1_nwis_sites_inst,pcode_select),
    pattern = map(p1_nwis_sites_inst))
  
)


