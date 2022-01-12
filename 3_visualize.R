# [Lauren] plot_daily_data and plot_inst_data not currently used to build targets, but leaving the functions here for reference
source("3_visualize/src/plot_daily_data.R")
source("3_visualize/src/plot_inst_data.R")
source("3_visualize/src/do_overview_plots.R")
source("3_visualize/src/map_sites.R")

p3_targets_list <- list(
  
  # Render data summary report (report target has format = "file")
  tarchetypes::tar_render(p3_wqp_spC_report, "3_visualize/src/report-do-inventory.Rmd",output_dir = "3_visualize/out"),

  # Generate summary plots using python
  tar_target(p3_do_plot_python_file,
             "3_visualize/src/do_overview_plots.py",
             format = "file"),

  # Save summary plots
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
  ),
  
  tar_target(
    p3_well_observed_site_data,
    {
      p2_sites_w_segs %>%
        mutate(partition = case_when(site_id %in% validation_sites ~ "val",
                                     site_id %in% test_sites ~ "test",
                                     site_id %in% p2a_well_observed_train_only ~ "train",
                                     site_id %in% p2a_well_observed_time_validation_sites ~ "train/val")) %>%
        filter(!is.na(partition)) %>%
        st_as_sf(., coords = c("lon", "lat"), crs = 4326)
    }
  ),

  tar_target(
    p3_well_observed_site_data_json,
    {
      filename = "3_visualize/out/well_observed_trn_val_test.geojson"
      st_write(p3_well_observed_site_data, filename, append=FALSE)
      filename
    },
    format = "file"
  )

)

