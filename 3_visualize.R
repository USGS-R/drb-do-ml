# [Lauren] plot_daily_data and plot_inst_data not currently used to build targets, but leaving the functions here for reference
source("3_visualize/src/plot_daily_data.R")
source("3_visualize/src/plot_inst_data.R")
source("3_visualize/src/do_overview_plots.R")
source("3_visualize/src/map_sites.R")

p3_targets_list <- list(
  
  # Render data summary report (report target has format = "file")
  tarchetypes::tar_render(p3_wqp_spC_report, "3_visualize/src/report-do-inventory.Rmd",output_dir = "3_visualize/out"),
  
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
  
  
  tar_target(
    p3_well_observed_site_data,
    {
      p2_sites_w_segs %>%
        mutate(partition = case_when(site_id %in% val_sites ~ "val",
                                     site_id %in% tst_sites ~ "test",
                                     site_id %in% p2a_trn_only ~ "train",
                                     site_id %in% p2a_trn_sites_w_val_data ~ "train/val")) %>%
        filter(!is.na(partition)) %>%
        st_as_sf(., coords = c("lon", "lat"), crs = 4326)
    }
  ),

  tar_target(
    p3_well_observed_site_data_json,
    {
      filename = "3_visualize/out/well_observed_trn_val_test.geojson"
      st_write(p3_well_observed_site_data, filename, append = FALSE, delete_dsn = TRUE, driver = "GeoJSON", quiet = TRUE)
      filename
    },
    format = "file"
  )

)

