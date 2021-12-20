subset_wqp_sites <- function(wqp_data,hucs,fileout){
  #' 
  #' @description Function to subset discrete sample locations for the lower DRB
  #'
  #' @param wqp_data a data frame containing discrete water quality data. Data frame must contain columns "LongitudeMeasure" and "LatitudeMeasure".
  #' @param hucs a character string containing the HUC8 watershed codes of interest
  #' @param fileout="./data/out/filtered_wqp_SC_data.csv"
  #'
  #' @value Outputs a data frame containing the subset of discrete water quality data for which the point locations intersect the huc watersheds of interest
  #' 

  # For the discrete WQP data, fetch associated HUC8 code from WQP:
  wqp_retrieved_sites <- dataRetrieval::whatWQPsites(huc = hucs)
  
  # Filter discrete WQP data for sites that intersect the huc watersheds of interest
  wqp_data_subset <- wqp_data %>%
    filter(MonitoringLocationIdentifier %in% wqp_retrieved_sites$MonitoringLocationIdentifier)
  
  # Save WQP data subset
  write_csv(wqp_data_subset, file = fileout)
  
  return(fileout)
  
}
