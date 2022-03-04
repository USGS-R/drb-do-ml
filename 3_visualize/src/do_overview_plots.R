
plot_daily_data <- function(data,fileout,min_count = 0, start_date = "",end_date = "",fig_cols,fig_height,fig_width){
  #' 
  #' @description Function to plot daily mean dissolved oxygen (DO)
  #'  
  #' @param data a data frame containing the daily time series 
  #' site_data must include the following columns: c("Value","Value_cd","Date",and "site_no")
  #' @param fileout character string that indicates the name of the file to be saved, including path and file extension 
  #' @param min_count filter data to only include 'well-observed' sites where the number of observation
  #' days exceeds {min_count}.
  #' @param start_date character string indicating the earliest date to include in plots
  #' Default value is "" and will plot all available data.
  #' @param end_date character string indicating the ending date to include in plots
  #' Default value is "" and will plot all available data. 
  #' @param fig_cols integer; how many columns should be used to plot multiple site panels
  #' @param fig_height integer; figure height to use when saving plot
  #' @param fig_width integer; figure width to use when saving plot
  #'
  #' @value Returns a png file containing the daily time series data for a site
  #' @examples 
  #' plot_daily_data(data = p1_daily_data, fileout = "3_visualize/out/daily_timeseries_mysite.png")
  #' 
  
  new_names <- c("date" = "dateTime",
                 "date" = "Date",
                 "value" = "Value",
                 "value" = "Value_Inst")
  plot_title <- ifelse("dateTime" %in% names(data),
                       "Daily mean DO (mg/l) at instantaneous sites",
                       "Daily mean DO (mg/l) at daily sites")
  
  daily_data <- data %>%
    rename(any_of(new_names)) %>%
    mutate(Date = as.Date(date)) %>%
    group_by(site_no,Date) %>%
    summarize(meanValue = mean(value,na.rm=TRUE),
              .groups="drop") %>%
    {if (start_date == "") {.} else {filter(., Date >= start_date)}} %>%
    {if (end_date == "") {.} else {filter(., Date <= end_date)}} %>%
    group_by(site_no) %>%
    mutate(count = n()) %>%
    ungroup() %>%
    filter(count > min_count)
  
  daily_plot <- daily_data %>%
    ggplot() + geom_line(aes(x=Date,y=meanValue,group = cumsum(c(0, diff(Date) > 1))),
                         color="steelblue",size=0.5) +
    facet_wrap(~site_no,ncol=fig_cols) + 
    ggtitle(plot_title) +
    theme_light()+
    theme(plot.title = element_text(hjust = 0.5),
          strip.text = element_text(colour = 'black'),
          axis.text.x = element_text(angle = 30,hjust=1))
  
  ggsave(fileout,plot=daily_plot,width = fig_width,height=fig_height,device = "png",units = "in")
  
  return(fileout)
  
}



plot_doy_means <- function(data,fileout,min_count = 0, start_date = "",end_date = "",fig_height,fig_width){
  #' 
  #' @description Function to plot mean dissolved oxygen (DO) by day of year
  #'  
  #' @param data a data frame containing the daily time series 
  #' site_data must include the following columns: c("Value","Value_cd","Date",and "site_no")
  #' @param fileout character string that indicates the name of the file to be saved, including path and file extension 
  #' @param min_count filter data to only include 'well-observed' sites where the number of observation
  #' days exceeds {min_count}.
  #' @param start_date character string indicating the earliest date to include in plots
  #' Default value is "" and will plot all available data.
  #' @param end_date character string indicating the ending date to include in plots
  #' Default value is "" and will plot all available data. 
  #' @param fig_height integer; figure height to use when saving plot
  #' @param fig_width integer; figure width to use when saving plot
  #'
  #' @value Returns a png file containing the mean DO by day of year across sites
  #' 
  
  doy_data <- data %>%
    mutate(Date = as.Date(Date),
           doy = lubridate::yday(Date)) %>%
    {if (start_date == "") {.} else {filter(., Date >= start_date)}} %>%
    {if (end_date == "") {.} else {filter(., Date <= end_date)}} %>%
    group_by(site_no) %>%
    mutate(count = n()) %>%
    ungroup() %>%
    filter(count > min_count) %>%
    group_by(site_no,doy) %>%
    summarize(meanValue = mean(Value,na.rm=TRUE),
              .groups = "drop")
  
  doy_plot <- doy_data %>%
    ggplot() + geom_line(aes(x = doy, y = meanValue, group = site_no), 
                         alpha = 0.5, color="steelblue") +
    labs(x = "day of year", y = "mean DO concentration (mg/l)") +
    theme_light() +
    theme(legend.position = "none",
          plot.title = element_text(hjust = 0.5),
          strip.text = element_text(colour = 'black'),
          axis.text.x = element_text(angle = 30,hjust=1))
  
  ggsave(fileout,plot=doy_plot,width = fig_width,height=fig_height,device = "png",units = "in")
  
  return(fileout)
  
}

