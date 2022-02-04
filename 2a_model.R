source("2a_model/src/model_ready_data_utils.R")

p2a_targets_list <- list(

  ## PREPARE (RENAME, JOIN) INPUT AND OUTPUT FILES ##
  # match to site_ids to seg_ids
  tar_target(
    p2a_met_data_w_sites,
    match_site_ids_to_segs (p1_prms_met_data, p2_sites_w_segs)
  ),

  # rename columns to match other data
  tar_target(
    p2a_do_data_model_labels,
    p2_daily_with_seg_ids %>%
      rename(site_id = site_no,
             date = Date,
             do_mean = Value,
             do_min = Value_Min,
             do_max = Value_Max
             )
  ),

  # match seg attributes with site_ids
  tar_target(
    p2a_seg_attr_w_sites,
    match_site_ids_to_segs(p1_seg_attr_data, p2_sites_w_segs)
  ),

  ## SPLIT SITES INTO (train) and (train and validation) ##
  # char vector of well-observed train sites
  tar_target(
    p2a_trn_sites,
    p2_well_observed_sites[!(p2_well_observed_sites %in% val_sites) & !(p2_well_observed_sites %in% tst_sites)]
  ),

  # char vector of well-observed val and training sites
  tar_target(
    p2a_trn_val_sites,
    p2_well_observed_sites[(p2_well_observed_sites %in% p2a_trn_sites) | (p2_well_observed_sites %in% val_sites)]
  ),

  # get sites that we use for trning, but also have data in the val time period
  tar_target(
    p2a_trn_sites_w_val_data,
    p2a_do_data_model_labels %>%
      filter(site_id %in% p2a_trn_val_sites,
             !site_id %in% val_sites,
             date >= val_start_date,
             date < val_end_date) %>%
      group_by(site_id) %>%
      summarise(val_count = sum(!is.na(do_mean))) %>%
      filter(val_count > 0) %>%
      pull(site_id)
  ),
  
  # sites that are trning sites but do not have data in val period
  tar_target(
    p2a_trn_only,
    p2a_trn_sites[!p2a_trn_sites %in% p2a_trn_sites_w_val_data]
  ),


  ## WRITE OUT PARTITION INPUT AND OUTPUT DATA ##
  # write trn met and seg attribute data to zarr
  # note - I have to subset before passing to subset_and_write_zarr or else I
  # get a memory error on the join
  tar_target(
    p2a_trn_inputs_zarr,
    { 
      trn_input <- p2a_met_data_w_sites %>%
        filter(site_id %in% p2a_trn_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = "site_id")
      subset_and_write_zarr(trn_input, "2a_model/out/well_observed_trn_inputs.zarr")
    },
    format="file"
  ),

  # write trn and val met and seg attribute data to zarr
  # note - I have to subset before passing to subset_and_write_zarr or else I
  # get a memory error on the join
  tar_target(
    p2a_trn_val_inputs_zarr,
    { 
      trn_input <- p2a_met_data_w_sites %>%
        filter(site_id %in% p2a_trn_val_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = "site_id")
      subset_and_write_zarr(trn_input, "2a_model/out/well_observed_trn_inputs.zarr")
    },
    format="file"
  ),


  # write trn do data to zarr
  tar_target(
    p2a_trn_do_zarr,
    subset_and_write_zarr(p2a_do_data_model_labels, "2a_model/out/well_observed_trn_do.zarr", p2a_trn_sites),
    format="file"
  ),

  # write trn and val do data to zarr
  tar_target(
    p2a_trn_val_do_zarr,
    subset_and_write_zarr(p2a_do_data_model_labels, "2a_model/out/well_observed_trn_do.zarr", p2a_trn_val_sites),
    format="file"
  )

)
