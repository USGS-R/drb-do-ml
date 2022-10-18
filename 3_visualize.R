# [Lauren] plot_daily_data and plot_inst_data are not currently used to build 
# any targets, leaving the functions here for reference
source("3_visualize/src/plot_daily_data.R")
source("3_visualize/src/plot_inst_data.R")
source("3_visualize/src/do_overview_plots.R")
source("3_visualize/src/summarize_static_attributes.R")
source("3_visualize/src/map_sites.R")

p3_targets_list <- list(
  
  # Render data summary report (report target has format = "file")
  tarchetypes::tar_render(p3_wqp_report, 
                          path = "3_visualize/src/report-do-inventory.Rmd",
                          output_dir = "3_visualize/out"),
  
  # Generate summary plots (all daily and inst data)
  tar_target(
    p3_daily_summary_plot_png,
    plot_daily_data(p1_daily_data, fileout = "3_visualize/out/daily_daily_means.png",
                    fig_cols = 5, fig_width = 8, fig_height = 7),
    format = "file"
  ),
  
  tar_target(
    p3_inst_summary_plot_png,
    plot_daily_data(p1_inst_data, fileout = "3_visualize/out/inst_daily_means.png",
                    fig_cols = 4, fig_width = 6, fig_height = 7),
    format = "file"
  ),
  
  tar_target(
    p3_doy_means_png,
    plot_doy_means(p2_daily_combined,fileout = "3_visualize/out/doy_means.png",
                   fig_height = 3, fig_width = 4),
    format = "file"
  ),
  
  # Generate summary plots (well-observed data only)
  tar_target(
    p3_daily_summary_plot_filtered_png,
    plot_daily_data(p1_daily_data, fileout = "3_visualize/out/filtered_daily_means.png",
                    min_count = 300, start_date = "1980-01-01", end_date = "1994-01-01",
                    fig_cols = 1, fig_width = 4, fig_height = 10),
    format = "file"
  ),
  
  tar_target(
    p3_inst_summary_plot_filtered_png,
    plot_daily_data(p1_inst_data, fileout = "3_visualize/out/filtered_inst_means.png",
                    min_count = 300, fig_cols = 1, fig_width = 4, fig_height = 10),
    format = "file"
  ),

  # Save a table containing summary statistics for the NHDPlusv2 static attributes
  tar_target(
    p3_static_attr_summary_csv,
    summarize_static_attributes(p2_seg_attr_data, "3_visualize/out/nhdv2_static_attr_summary.csv"),
    format = "file"
  ),
  
  # Save png map of site locations
  tar_target(
    p3_site_map_png,
    map_sites(flowlines = p1_nhd_reaches_sf,
              matched_sites = p2a_site_splits,
              out_file = "3_visualize/out/do_site_map.png")
  ),
  
  # Save json map of site locations
  tar_target(
    p3_well_observed_site_data_json,
    {
      filename = "3_visualize/out/well_observed_trn_val_test.geojson"
      sf::st_write(p2a_site_splits, filename, append = FALSE, delete_dsn = TRUE,
                   driver = "GeoJSON", quiet = TRUE)
      filename
    },
    format = "file"
  )

)

