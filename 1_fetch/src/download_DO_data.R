download_daily_mean_DO_data <- function(site_list,pcode,stat_cd,fileout){
  
  daily_DO_data_ls <- lapply(site_list,function(x){
    readNWISdv(siteNumbers = x,parameterCd=pcode,statCd=stat_cd,startDate = "",endDate = "") %>%
      renameNWISColumns()
  })
  
  # Combine daily site data and save to fileout
  daily_data_out <- do.call(rbind,daily_DO_data_ls)
  
  write_csv(daily_data_out, file = fileout)
  
  return(fileout)
  
}


download_cont_DO_data <- function(site_list,pcode,time_zone){
  
  cont_DO_data_ls <- lapply(site_list,function(x){
    readNWISuv(siteNumbers = x,parameterCd=pcode,startDate="",endDate="",tz=time_zone) %>%
      renameNWISColumns()
  })
  
  # Combine continuous site data and save to fileout
  cont_data_out <- do.call(rbind,cont_DO_data_ls)

  return(cont_data_out)
  
}