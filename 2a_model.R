source("2a_model/src/model_ready_data_utils.R")
source("2a_model/src/write_model_config_files.R")

p2a_targets_list <- list(

  ## PREPARE (RENAME, JOIN) INPUT AND OUTPUT FILES ##
  # join met data with light input data
  tar_target(
    p2a_met_light_data,
    p2_met_data_at_obs_sites %>%
      mutate(date = as.Date(time, tz = 'UTC')) %>%
      left_join(y = p2_daily_max_light %>%
                  select(COMID, date_localtime, frac_light) %>%
                  # format column names
                  rename(light_ratio = frac_light,
                         date = date_localtime),
                by = c("COMID", "date")) %>%
      select(-time) %>%
      relocate(date, .after = COMID)
  ),
  
  # match site_ids to seg_ids
  tar_target(
    p2a_met_data_w_sites,
    match_site_ids_to_segs(p2a_met_light_data, p2_sites_w_segs)
  ),

  # match seg attributes with site_ids
  tar_target(
    p2a_seg_attr_w_sites,
    match_site_ids_to_segs(p2_seg_attr_data, p2_sites_w_segs)
  ),
  
  # join the metab data with the DO observations
  tar_target(
    p2a_do_and_metab,
    p2_daily_with_seg_ids %>%
      full_join(p2_metab_filtered, by = c("site_id", "date"))
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

  # get sites that we use for training, but also have data in the val time period
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
  
  # Summarize site splits/groups based on the above 3 targets
  tar_target(
    p2a_site_splits,
    p2_sites_w_segs %>%
      filter(site_id %in% c(p2a_trn_sites, val_sites, tst_sites)) %>%
      mutate(site_type = case_when(
        site_id %in% p2a_trn_sites & 
          !site_id %in% p2a_trn_sites_w_val_data ~ "train",
        site_id %in% p2a_trn_sites_w_val_data ~ "train/val",
        site_id %in% val_sites ~ "validation",
        site_id %in% tst_sites ~ "test",
        TRUE ~ NA_character_),
        # assign epsg codes based on "datum" column and convert
        # data frame to sf object
        epsg = case_when(datum == "NAD83" ~ 4269,
                         datum == "WGS84" ~ 4326,
                         datum == "NAD27" ~ 4267,
                         datum == "UNKWN" ~ 4326,
                         datum == "OTHER" ~ 4326)) %>%
      sf::st_as_sf(., coords = c("lon","lat"), crs = unique(.$epsg))
  ),
  
  ## WRITE MODEL CONFIGURATION FILES ##
  # Write base config file using inputs and parameters defined in _targets.R
  tar_target(
    p2a_config_base_yml,
    write_config_file(cfg_options = base_config_options,
                      fileout = "2a_model/src/models/config_base.yml"),
    format = "file"
  ),
  
  # Write model config file for 0_baseline_LSTM
  tar_target(
    p2a_config_baseline_LSTM_yml,
    write_config_file(cfg_options = model_config_options,
                      fileout = "2a_model/src/models/0_baseline_LSTM/config.yml",
                      exp_name = "0_baseline_LSTM"),
    format = "file"
  ),
  
  # Write model config file for 1_metab_multitask
  tar_target(
    p2a_config_metab_multitask_yml,
    write_config_file(cfg_options = metab_multitask_config_options,
                      fileout = "2a_model/src/models/1_metab_multitask/config.yml",
                      exp_name = "1_metab_multitask"),
    format = "file"
  ),
  
  # Write model config file for 1a_multitask_do_gpp_er
  tar_target(
    p2a_config_1a_metab_multitask_yml,
    write_config_file(cfg_options = metab_1a_multitask_config_options,
                      fileout = "2a_model/src/models/1_metab_multitask/1a_multitask_do_gpp_er.yml",
                      exp_name = "1a_multitask_do_gpp_er"),
    format = "file"
  ),
  
  # Write model config file for 1b_multitask_do_gpp
  tar_target(
    p2a_config_1b_metab_multitask_yml,
    write_config_file(cfg_options = metab_1b_multitask_config_options,
                      fileout = "2a_model/src/models/1_metab_multitask/1b_multitask_do_gpp.yml",
                      exp_name = "1b_multitask_do_gpp"),
    format = "file"
  ),
  
  # Write model config file for 2_multitask_dense
  tar_target(
    p2a_config_multitask_dense_yml,
    write_config_file(cfg_options = multitask_dense_config_options,
                      fileout = "2a_model/src/models/2_multitask_dense/config.yml",
                      exp_name = "2_multitask_dense"),
    format = "file"
  ),
  
  ## WRITE OUT PARTITION INPUT AND OUTPUT DATA ##
  # write met and seg attribute data for trn/val sites to zarr
  # note - I have to subset inputs to only include the train/val sites before 
  # passing to subset_and_write_zarr or else I get a memory error on the join
  
  ## CHANGING X VARIABLES ##
  #To change x variables for the model, they have to be added to the 
  #model specific config.yml file which can be found in 
  #2a_model/src/model/{model ID}/config.yml

  # write trn and val input and output data to zarr
  tar_target(
    p2a_well_obs_data,
    {
      inputs <- p2a_met_data_w_sites %>%
        filter(site_id %in% p2a_trn_val_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = c("site_id", "COMID"))

      inputs_and_outputs <- inputs %>%
          left_join(p2a_do_and_metab, by=c("site_id", "date"))
      
      # note that if the name of well_obs_io.zarr is changed below, this change must
      # also be made in 2a_model/src/Snakefile_base.smk (lines 32, 103, and 177) and
      # in 2a_model/src/visualize_models.smk (line 6). 
      write_df_to_zarr(inputs_and_outputs, c("site_id", "date"), "2a_model/out/well_obs_io.zarr")
    },
    format="file"
  ),
  
  # gather model ids - add to this list when you want to reproduce
  # outputs from a new model 
  tar_target(
    p2a_model_ids,
    # paths are relative to 2a_model/src/models
      list(
        list(model_id = "0_baseline_LSTM",
             snakefile_dir = "0_baseline_LSTM",
             config_path = stringr::str_remove(p2a_config_baseline_LSTM_yml, "2a_model/src/models/")),
        # the 1_ models use the same model and therefore the same Snakefile
        # as the 0_baseline_LSTM run
        list(model_id = "1_metab_multitask",
             snakefile_dir = "0_baseline_LSTM",
             config_path = stringr::str_remove(p2a_config_metab_multitask_yml, "2a_model/src/models/")),
        list(model_id = "1a_multitask_do_gpp_er",
             snakefile_dir = "0_baseline_LSTM",
             config_path = stringr::str_remove(p2a_config_1a_metab_multitask_yml, "2a_model/src/models/")),
        list(model_id = "2_multitask_dense",
             snakefile_dir = "2_multitask_dense",
             config_path = stringr::str_remove(p2a_config_multitask_dense_yml, "2a_model/src/models/"))
        ),
    iteration = "list"
  ),

  # produce the final metrics files (and all intermediate files including predictions)
  # of each "model_id" with snakemake
  tar_target(
    p2a_metrics_files,
    {
    #we need these to make the prepped data file
    p2a_well_obs_data

    base_dir <- "2a_model/src/models"
    snakefile_path <- file.path(base_dir, p2a_model_ids$snakefile_dir, "Snakefile")
    config_path <- file.path(base_dir, p2a_model_ids$config_path)
    # this path is relative to the Snakefile
    prepped_data_file <- file.path("../../../out/models",p2a_model_ids$model_id, "prepped.npz")

    # First create the prepped data files if they are not already.
    # These are needed to make the predictions.
    system(stringr::str_glue("snakemake {prepped_data_file} -s {snakefile_path} --configfile {config_path} -j"))

    # Then touch all of the existing files. This makes the weights "up-to-date"
    # so snakemake doesn't train the models again
    system(stringr::str_glue("snakemake -s {snakefile_path} --configfile {config_path} -j --touch"))

    # then run the snakemake pipeline to produce the predictions and metric files
    system(stringr::str_glue("snakemake -s {snakefile_path} --configfile {config_path} -j --rerun-incomplete"))
    
    # print out the metrics file name for the target
    file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_overall_metrics.csv")
    },
    format="file",
    pattern = map(p2a_model_ids)
  )
  
)

