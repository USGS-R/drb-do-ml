plot_inst_data <- function(out_file, site_data) {
  #' 
  #' @description Function to plot hourly average data from instantaneous NWIS monitoring sites
  #'
  #' @param out_file a character string that indicates the name of the file to be saved, including path and file extension 
  #' @param site_data a data frame containing the hourly-aggregated time series 
  #' site_data must include the following columns: c("Value_Inst_hourly","Value_Inst_cd","dateTime",and "site_no")
  #'
  #' @value Returns a png file containing the hourly average time series data for a site
  #' @examples 
  #' plot_inst_data(out_file = "3_visualize/out/hourly_timeseries_mysite.png",site_data = filter(p2_inst_data_hourly,site_no=="01484272"))
  
  message(sprintf('  Plotting instantaneous data for %s', site_data$site_no[1]))
  
  # Check that site_data contains required columns
  req_cols <- c("Value_Inst_hourly","Value_Inst_cd","dateTime","site_no")
  flag_cols <- req_cols[which(req_cols %in% names(site_data)=="FALSE")]
  if(length(flag_cols)>0) stop("Input data is missing one or more required columns: Value_Inst_hourly, Value_Inst_cd, dateTime, site_no")
  
  # Define y-axis label
  ylabel <- case_when(site_data$Parameter[1] %in% c("SpecCond","00095") ~ expression(paste0("Hourly mean SC at 25 ", degree, "C (", mu, "S/cm)")),
                      site_data$Parameter[1] %in% c("DO","00300") ~ expression("Hourly mean DO, unfiltered (mg/L)"))
  
  # Create hourly time series plot
  inst_plot <- ggplot( 
    filter(site_data, Value_Inst_cd %in% c('A','P')), aes(x=dateTime, y=Value_Inst_hourly, color=Value_Inst_cd)) +
    geom_line(size=0.7) +
    geom_point(data=filter(site_data, !(Value_Inst_cd %in% c('A','P'))), size=0.2) +
    ylab(ylabel) + xlab("date") + 
    scale_x_datetime(date_labels="%Y-%m") + 
    ggtitle(site_data$site_no[1]) + 
    theme(axis.title = element_text(size=8),axis.text = element_text(size=7),
          legend.title = element_text(size=8),legend.text = element_text(size=7))
  suppressWarnings(ggsave(out_file, plot=inst_plot, width=6, height=3))
  
  # Save daily time series plot
  return(out_file)
}
