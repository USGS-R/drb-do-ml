source("2a_model/src/model_ready_data_utils.R")

p2a_targets_list <- list(

  ## PREPARE (RENAME, JOIN) INPUT AND OUTPUT FILES ##
  # join met data with light input data
  tar_target(
    p2a_met_light_data,
    p2_met_data_at_obs_sites %>%
      mutate(date = as.Date(time, tz = 'Etc/GMT+5')) %>%
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
      
      write_df_to_zarr(inputs_and_outputs, c("site_id", "date"), "2a_model/out/well_obs_io.zarr")
    },
    format="file"
  ),
  
 
  
  # gather model ids - add to this list when you want to reproduce
  # outputs from a new model #add medium observed sites
  tar_target(
    p2a_model_ids,
    # paths are relative to 2a_model/src/models
      list(list(model_id = "0_baseline_LSTM",
                  snakefile_dir = "0_baseline_LSTM",
                  config_path = "0_baseline_LSTM/config.yml"),
         #the 1_ models use the same model and therefore
         #the same Snakefile as the 0_baseline_LSTM run
         list(model_id = "1_metab_multitask",
              snakefile_dir = "0_baseline_LSTM",
              config_path = "1_metab_multitask/config.yml"),
         list(model_id = "1a_multitask_do_gpp_er",
              snakefile_dir = "0_baseline_LSTM",
              config_path = "1_metab_multitask/1a_multitask_do_gpp_er.yml"),
         list(model_id = "2_multitask_dense",
              snakefile_dir = "2_multitask_dense",
              config_path = "2_multitask_dense/config.yml")),
          iteration = "list"
  ),

  # produce the final metrics files (and all intermediate files including predictions)
  # of each "model_id" with snakemake
  tar_target(
    p2a_metrics_files,
    {
    #we need these to make the prepped data file
    p2a_well_obs_data
    
    #add in the medium observed data
    p2a_med_obs_data
    
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
    system(stringr::str_glue("snakemake -s {snakefile_path} --configfile {config_path} -j --rerun-incomplete --rerun-triggers mtime"))
    
    # print out the metrics file name for the target
    file.path("2a_model/out/models", p2a_model_ids$model_id, "exp_overall_metrics.csv")
    },
    format="file",
    pattern = map(p2a_model_ids)
  ),
  
  
  ## CREATE EQUIVALENT TARGETS FOR "MODERATELY-OBSERVED SITES" ##
  # write input/output data to zarr for the medium-observed sites
  tar_target(
    p2a_med_obs_data,
    {
      inputs_med_obs <- p2a_met_data_w_sites %>%
        # include all med-obs sites not in testing sites
        filter(site_id %in% p2_med_observed_sites, 
               !site_id %in% tst_sites) %>%
        inner_join(p2a_seg_attr_w_sites, by = c("site_id","COMID"))
      
      inputs_and_outputs_med_obs <- inputs_med_obs %>%
        left_join(p2a_do_and_metab, by = c("site_id", "date"))
      
      write_df_to_zarr(inputs_and_outputs_med_obs, c("site_id","date"),
                       "2a_model/out/med_obs_io.zarr")
    },
    format = "file"
  )
  
)

