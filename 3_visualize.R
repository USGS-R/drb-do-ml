source("3_visualize/src/plot_daily_data.R")
source("3_visualize/src/plot_inst_data.R")

p3_targets_list <- list(
  
  # Plot daily data
  tar_target(p3_daily_timeseries_png,
             plot_daily_data(sprintf("3_visualize/out/daily_timeseries_png/daily_data_%s.png",unique(p1_daily_data$site_no)),p1_daily_data),
             format = "file",
             pattern = map(p1_daily_data)),
  
  # Plot instantaneous data (hourly averages)
  tar_target(p3_hourly_timeseries_png,
             plot_inst_data(sprintf("3_visualize/out/hourly_timeseries_png/hourly_data_%s.png",unique(p2_inst_data_hourly$site_no)),p2_inst_data_hourly),
             format = "file",
             pattern = map(p2_inst_data_hourly)),
  
  # Render data summary report (report target has format = "file")
  tarchetypes::tar_render(p3_wqp_spC_report, "3_visualize/src/report-do-inventory.Rmd",output_dir = "3_visualize/out")
)

