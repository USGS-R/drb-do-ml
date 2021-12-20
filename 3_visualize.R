# [Lauren] plot_daily_data and plot_inst_data not currently used to build targets, but leaving the functions here for reference
source("3_visualize/src/plot_daily_data.R")
source("3_visualize/src/plot_inst_data.R")
source("3_visualize/src/do_overview_plots.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/summarize_site_list.R")
source("3_visualize/src/summarize_timeseries.R")

p3_targets_list <- list(
  
  # Create and save log file containing data availability summary
  tar_target(
    p3_sitelist_summary_csv,
    summarize_site_list(p2_site_list_csv,p1_daily_data,p1_inst_data,fileout = "3_visualize/log/sitelist_summary.csv"),
    format = "file"),
  
  # Create and save indicator file for NWIS daily data
  tar_target(
    p3_daily_timeseries_ind_csv,
    command = save_target_ind_files("3_visualize/log/daily_timeseries_ind.csv",names(p3_daily_timeseries_png)),
    format = "file"),
  
  # Create and save indicator file for NWIS instantaneous data
  tar_target(
    p3_inst_timeseries_ind_csv,
    command = save_target_ind_files("3_visualize/log/inst_timeseries_ind.csv",names(p3_hourly_timeseries_png)),
    format = "file"),
  
  # Create and save indicator file for WQP data
  tar_target(
    p3_wqp_ind_csv,
    command = save_target_ind_files("3_visualize/log/wqp_data_ind.csv","p2_wqp_data_subset_csv"),
    format = "file"),
  
  # Create and save summary log file for NWIS daily data
  tar_target(
    p3_daily_timeseries_summary_csv,
    command = target_summary_stats(p1_daily_data,"Value","3_visualize/log/daily_timeseries_summary.csv"),
    format = "file"
  ),
  
  # Create and save summary log file for NWIS instantaneous data
  tar_target(
    p3_inst_timeseries_summary_csv,
    command = target_summary_stats(p1_inst_data,"Value_Inst","3_visualize/log/inst_timeseries_summary.csv"),
    format = "file"
  ),
  
  # Render data summary report (report target has format = "file")
  tarchetypes::tar_render(p3_wqp_spC_report, "3_visualize/src/report-do-inventory.Rmd",output_dir = "3_visualize/out"),

  tar_target(p3_do_plot_python_file,
             "3_visualize/src/do_overview_plots.py",
             format = "file"),

  tar_target(
    p3_do_summary_plots,
    plot_do_overview(p3_do_plot_python_file,
                     p1_daily_data_csv,
                     p1_inst_data_csv,
                     filesout=c("3_visualize/out/inst_daily_means.jpg",
                                "3_visualize/out/daily_daily_means.jpg",
                                "3_visualize/out/doy_means.jpg",
                                "3_visualize/out/filtered_daily_means.jpg",
                                "3_visualize/out/filtered_inst_means.jpg")),
    format = "file"
  )
)

