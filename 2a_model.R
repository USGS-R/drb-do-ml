source("2a_model/src/model_ready_data_utils.R")

p2a_targets_list <- list(

  ## PREPARE (RENAME, JOIN) INPUT AND OUTPUT FILES ##
  # join met data with light input data
  tar_target(
    p2a_met_light_data,
    p1_prms_met_data %>%
      left_join(p2_daily_max_light %>%
                  # omit subseg's not included in met data
                  filter(!subsegid %in% c("3_1","8_1","51_1")) %>%
                  select(seg_id_nat, date_localtime, frac_light) %>%
                  # format column names
                  rename(light_ratio = frac_light,
                         date = date_localtime),
                by = c("seg_id_nat", "date"))
  ),
  
  # match to site_ids to seg_ids
  tar_target(
    p2a_met_data_w_sites,
    match_site_ids_to_segs(p2a_met_light_data, p2_sites_w_segs)
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
    p2_daily_with_seg_ids  %>%
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
  # write trn and val met and seg attribute data to zarr
  # note - I have to subset before passing to subset_and_write_zarr or else I
  # get a memory error on the join
  tar_target(
    p2a_well_obs_inputs_zarr,
    { 
      trn_input <- p2a_met_data_w_sites %>%
        filter(site_id %in% p2a_trn_val_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = "site_id")
      subset_and_write_zarr(trn_input, "2a_model/out/well_obs_inputs.zarr")
    },
    format="file"
  ),


  # write trn and val do and metab data to zarr
  tar_target(
    p2a_well_obs_targets_zarr,
    {
      # need to join the metab data with the DO observations. 
      do_and_metab <- p2_daily_with_seg_ids %>%
          left_join(p1_metab, by=c("site_id", "date"))
      subset_and_write_zarr(do_and_metab, "2a_model/out/well_obs_targets.zarr", p2a_trn_val_sites)
    },
    format="file"
  ),

  # gather model ids - add to this list when you want to reproduce
  # outputs from a new model
  tar_target(
    p2a_model_ids,
    c("0_baseline_LSTM")
  ),


  # write prepped file to .npz
  tar_target(
    p2a_prepped,
    {
    dir.create(sprintf("2a_model/out/models/%s", p2a_model_ids), showWarnings = FALSE)
    prep_io_data(x_data_file = p2a_trn_inputs_zarr,
                 y_data_file = p2a_trn_targets_zarr,
                 config_dir = sprintf("2a_model/src/models/%s", p2a_model_ids),
                 out_file = sprintf("2a_model/out/models/%s/prepped.npz", p2a_model_ids))
    },
    format="file",
    pattern = map(p2a_model_ids)
  ),

  # 'touch' (update modified time) trained model weights so Snakemake doesn't retrain models
  tar_target(
    p2a_wgt_paths,
    {
    # including the prepped data so that that target is built first 
    p2a_prepped

    # get a list of all of the weight files in the repo
    wgt_files = list.files(sprintf("2a_model/out/models/%s", p2a_model_ids),
                           "train_weights",
                           full.names=TRUE,
                           recursive = TRUE,
                           include.dirs = TRUE)
    wgt_files_joined = paste(wgt_files, collapse=" ")
    # need to make the paths relative to the Snakefile
    wgt_files_joined = gsub("2a_model", "../../..", wgt_files_joined)

    # use Snakemake to "touch" each of the files
    system(sprintf("snakemake %s -s 2a_model/src/models/%s/Snakefile -j4 --touch", wgt_files_joined, p2a_model_ids))
    wgt_files
    },
    pattern = map(p2a_model_ids)
    ),
                         
  # produce the final metrics files (and all intermediate files including predictions)
  # of each "model_id" with snakemake
  tar_target(
    p2a_metrics_files,
    {
    # include wgt_paths and prepped
    p2a_wgt_paths
    p2a_prepped

    system(sprintf("snakemake -s 2a_model/src/models/%s/Snakefile -j8", p2a_model_ids))
    sprintf("2a_model/out/models/%s/exp_overall_metrics.csv", p2a_model_ids)
    },
    format="file",
    pattern = map(p2a_model_ids)
  )
)
