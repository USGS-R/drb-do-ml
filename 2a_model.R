source("2a_model/src/model_ready_data_utils.R")

p2a_targets_list <- list(
  # subset met data to just well-observed sites and match to site_ids
  tar_target(
    p2a_well_observed_met_data,
    subset_seg_data_and_match_site_ids(p1_prms_met_data, p2_sites_w_segs, p2_well_observed_sites)
  ),

  # well-observed do data 
  tar_target(
    p2a_well_observed_do_data,
    well_observed_do_data <- p2_daily_with_seg_ids %>%
                             filter(site_no %in% p2_well_observed_sites) %>%
                             rename(site_id = site_no,
                                    date = Date,
                                    do_mean = Value,
                                    do_min = Value_Min,
                                    do_max = Value_Max
                                    )
  ),

  tar_target(
    p2a_well_observed_train_sites,
    p2_well_observed_sites[!(p2_well_observed_sites %in% validation_sites) & !(p2_well_observed_sites %in% test_sites)]
  ),

  tar_target(
    p2a_well_observed_train_validation_sites,
    p2_well_observed_sites[(p2_well_observed_sites %in% p2a_well_observed_train_sites) | (p2_well_observed_sites %in% validation_sites)]
  ),

   # get sites that we use for training, but also have data in the validation time period
  tar_target(
    p2a_well_observed_time_validation_sites,
    p2a_well_observed_do_data %>%
      filter(site_id %in% p2a_well_observed_train_validation_sites,
             !site_id %in% validation_sites,
             date >= val_start_date,
             date < val_end_date) %>%
      group_by(site_id) %>%
      summarise(val_count = sum(!is.na(do_mean))) %>%
      filter(val_count > 0) %>%
      pull(site_id)
  ),
  
  # sites that are training sites but do not have data in validation period
  tar_target(
    p2a_well_observed_train_only,
    p2a_well_observed_train_sites[!p2a_well_observed_train_sites %in% p2a_well_observed_time_validation_sites]
  ),

  # match seg attributes with site_ids, subset to train sites and write to feather 
  tar_target(
    p2a_well_observed_train_seg_attr,
    subset_seg_data_and_match_site_ids(p1_seg_attr_data, p2_sites_w_segs, p2a_well_observed_train_sites)
  ),

  # match seg attributes with site_ids, subset to train and validation sites and write to feather 
  tar_target(
   p2a_well_observed_train_validation_seg_attr,
   subset_seg_data_and_match_site_ids(p1_seg_attr_data, p2_sites_w_segs, p2a_well_observed_train_validation_sites)
  ),

  # write train met and seg attribute data to zarr
  tar_target(
    p2a_train_inputs_zarr,
    { 
      train_met <- p2a_well_observed_met_data %>% filter(site_id %in% p2a_well_observed_train_sites)
      train_input <- train_met %>% left_join(p2a_well_observed_train_seg_attr, by = "site_id")
      write_df_to_zarr(train_input, c("site_id", "date"), "2a_model/out/well_observed_train_inputs.zarr")
    },
    format="file"
  ),

  # write train and validation met and seg attribute data to zarr
  tar_target(
    p2a_train_val_inputs_zarr,
    { 
      train_val_met <- p2a_well_observed_met_data %>% filter(site_id %in% p2a_well_observed_train_validation_sites)
      train_val_input <- train_val_met %>% left_join(p2a_well_observed_train_validation_seg_attr, by = "site_id")
      write_df_to_zarr(train_val_input, c("site_id", "date"), "2a_model/out/well_observed_train_val_inputs.zarr")
    },
    format="file"
  ),


  # write train do data to zarr
  tar_target(
    p2a_train_do_zarr,
    { 
      train_do <- p2a_well_observed_do_data %>% filter(site_id %in% p2a_well_observed_train_sites)
      write_df_to_zarr(train_do, c("site_id", "date"), "2a_model/out/well_observed_train_do.zarr")
    },
    format="file"
  ),

  # write train and validation do data to zarr
  tar_target(
    p2a_train_validation_do_zarr,
    { 
      train_val_do <- p2a_well_observed_do_data %>% filter(site_id %in% p2a_well_observed_train_validation_sites)
      write_df_to_zarr(train_val_do, c("site_id", "date"), "2a_model/out/well_observed_train_val_do.zarr")
    },
    format="file"
  )


)
