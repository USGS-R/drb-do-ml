source("2a_model/src/model_ready_data_utils.R")

# subset met data to just well-observed sites and match site ids
p2a_targets_list <- list(
  tar_target(
    p2a_well_observed_met_data,
    subset_met_data_and_match_site_ids (p1_prms_met_data, p2_sites_w_segs, p2_well_observed_sites)
  )

)
