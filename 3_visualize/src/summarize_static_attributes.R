#' @title Summarize static attribute values
#' 
#' @description 
#' Function to generate summary statistics for each static attribute feature
#' and save the output as a csv file.
#' 
#' @param attr_df data frame containing the static attribute values, with 
#' one row per NHDplusv2 COMID and a column containing the numeric values
#' for each static attribute.
#' @param fileout character string indicating the name of the output file,
#' including file path and extension.
#' 
#' @return 
#' Returns a csv file with one row for each static attribute feature and
#' columns containing the min, mean, max, and standard deviation of the 
#' attribute values. Two additional columns indicate the total count (of
#' COMIDs) and the count of NA values.
#' 
summarize_static_attributes <- function(attr_df, fileout){
  
  # Define function to summarize the number of NA's in numeric vector x
  num_NA <- function(x){
    sum(is.na(x))
  }
  
  # Edit base functions so that they're robust to columns with all NA values, 
  # i.e., don't return Inf
  Min <- function(x){if (length(x[is.na(x)]) < length(x)) min(x, na.rm = TRUE) else NA}
  Max <- function(x){if (length(x[is.na(x)]) < length(x)) max(x, na.rm = TRUE) else NA}
  Mean <- function(x){if (length(x[is.na(x)]) < length(x)) mean(x, na.rm = TRUE) else NA}
  Sd <- function(x){if (length(x[is.na(x)]) < length(x)) sd(x, na.rm = TRUE) else NA}
  n <- function(x){length(x)}
  
  # Calculate summary statistics for each variable's time series
  attr_summary <- attr_df %>%
    select(where(is.numeric)) %>%
    pivot_longer(everything()) %>%
    group_by(name) %>%
    summarize(across(everything(), list(Min = Min, Mean = Mean, Max = Max, Sd = Sd, num_NA = num_NA, num = n))) %>%
    mutate(across(where(is.numeric), round, 4)) %>%
    rename(static_attribute = name, 
           Min = value_Min,
           Mean = value_Mean,
           Max = value_Max,
           StdDev = value_Sd,
           n_NA = value_num_NA,
           n_total = value_num)
  
  # Save data summary
  readr::write_csv(attr_summary,fileout)
  
  return(fileout) 
}


  