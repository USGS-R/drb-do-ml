munge_cont_DO_cols <- function(x){
  
  # x is a data frame containing downloaded continuous data from NWIS
  
  cont_data_rename <- renameNWISColumns(x)
  
  # Find which column(s) contain DO data and relevant qualifying codes:
  vector_DO_vars <- grep("DO_Inst$",names(cont_data_rename),value=TRUE)
  vector_DO_cd_vars <- grep("DO_Inst_cd$",names(cont_data_rename),value=TRUE)
  
  # Coalesce multiple specific conductance columns if applicable:
  cont_data_out <- cont_data_rename %>% 
    mutate(DO_Inst_out = coalesce(!!!syms(vector_DO_vars)),
           DO_Inst_cd_out = coalesce(!!!syms(vector_DO_cd_vars))) %>%
    select(agency_cd,site_no,dateTime,DO_Inst_out,DO_Inst_cd_out,tz_cd) %>%
    rename("DO_Inst"="DO_Inst_out","DO_Inst_cd"="DO_Inst_cd_out") 
  
  return(cont_data_out)
  
  
}


combine_cont_DO_data <- function(cont_data_nwis_ls,fileout){
  
  # cont_data_nwis_ls is a list containing the downloaded continuous data for each DO site within the DRB
  
  # Munge continuous data columns
  cont_data_nwis_munged <- lapply(cont_data_nwis_ls,munge_cont_DO_cols)
  
  # Combine continuous data and save to fileout
  cont_data_out <- do.call(rbind,cont_data_nwis_munged)
  
  write_csv(cont_data_out, file = fileout)
  
  return(fileout)
  
}
