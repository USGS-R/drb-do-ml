save_target_ind_files <- function(fileout,target_names) {
  #' 
  #' @description Function to save indicator files to track data changes over time
  #'
  #' @param fileout a character string that indicates the name of the file to be saved, including path and file extension 
  #' @param target_names a character string or vector of strings containing the target names of interest
  #'
  #' @value Returns a csv file containing the target metadata
  
  # Create indicator table
  ind_tbl <- tar_meta(all_of(target_names)) %>%
    select(tar_name = name, filepath = path, hash = data) %>%
    mutate(filepath = unlist(filepath))

  # Save indicator table
  readr::write_csv(ind_tbl, fileout)
  return(fileout)
}


target_summary_stats <- function(df,ValueVar,fileout){
  #' 
  #' @description Function to calculate basic summary statistics for each NWIS site and save to a log summary file
  #'
  #' @param df a data frame containing NWIS data. Must contain the column ValueVar
  #' @param ValueVar a character string that indicates the name of the column to be summarized
  #' @param fileout a character string that indicates the name of the file to be saved, including path and file extension 
  #'
  #' @value Returns a csv file containing summary statistics, including number of observations, mean, and sd
  
  # Check for the following columns in df
  req_cols <- ValueVar
  flag_cols <- req_cols[which(req_cols %in% names(df)=="FALSE")]
  if(length(flag_cols)>0) stop("df is missing one or more required columns: user-specified ValueVar")
  
  # Calculate summary statistics for each site
  data_summary <- df %>%
    group_by(site_no) %>%
    summarize(site_no = site_no[1],
              n_obs = length(!is.na(.data[[ValueVar]])),
              mean = round(mean(.data[[ValueVar]],na.rm=TRUE),6),
              sd = round(sd(.data[[ValueVar]],na.rm=TRUE),6))
  
  # Save summary table
  readr::write_csv(data_summary,fileout)
  
  return(fileout)
  
}