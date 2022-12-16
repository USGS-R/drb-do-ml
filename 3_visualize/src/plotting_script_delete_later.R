# pseudo targets pipeline for creating plots of model predictive performance

source("3_visualize/src/plotting_helpers.R")
library(tidyverse)
library(targets)
library(patchwork)
tar_load(p2a_metrics_files)
tar_load(p2a_do_and_metab)

# read in and bind the overall_metrics files from each model id
p3_overall_metrics <- lapply(p2a_metrics_files, function(x){
  dat <- readr::read_csv(x, show_col_types = FALSE) %>%
    mutate(model_id = str_replace_all(x, '2a_model/out/models/|/exp_overall_metrics.csv', ''))
  }) %>%
  bind_rows()

# plot overall model performance by train/test partition
# targets pipeline will save plots for all model ids
p3_overall_metrics_png <- plot_metrics_by_partition(metrics_df = filter(p3_overall_metrics, model_id == "0_baseline_LSTM"),
                                                    performance_metric = "rmse", 
                                                    fileout = "3_visualize/out/baseline_rmse.png",
                                                    partition_select = c("train", "val"),
                                                    partition_colors = c("#a6cee3","#1f78b4"))

# save directories containing model reps
p3_preds_dir_0_baseline_LSTM <- list.files("2a_model/out/models/0_baseline_LSTM/nstates_10/nep_100", full.names = TRUE) 
p3_preds_dir_2_multitask_dense <- list.files("2a_model/out/models/2_multitask_dense/nstates_10/nep_100", full.names = TRUE) 

# read in feather files from model rep sub-directories and create a data frame w/ DO predictions from 0_baseline_LSTM
p3_preds_0_baseline_LSTM <- p3_preds_dir_0_baseline_LSTM %>%
  purrr::map_dfr(read_preds_feather, preds_file = "val_preds.feather", .id = "rep_file") %>%
  mutate(model_id = str_replace_all(rep_file, '2a_model/out/models/|/exp_overall_metrics.csv', '')) %>%
  rename(do_min_base = do_min, do_max_base = do_max, do_mean_base = do_mean)

# read in feather files from model rep sub-directories and create a data frame w/ DO predictions from 2_multitask_dense
p3_preds_2_multitask_dense <- p3_preds_dir_2_multitask_dense %>%
  purrr::map_dfr(read_preds_feather, preds_file = "val_preds.feather", .id = "rep_file") %>%
  mutate(model_id = str_replace_all(rep_file, '2a_model/out/models/|/exp_overall_metrics.csv', '')) %>%
  rename(do_min_metab_dense = do_min, do_max_metab_dense = do_max, do_mean_metab_dense = do_mean)

# bind together predictions from both models, note that the preds columns have different names 
# for each model id
p3_preds_all_models <- p3_preds_0_baseline_LSTM %>%
  select(-c(model_id, rep_file)) %>%
  left_join(y = select(p3_preds_2_multitask_dense, -model_id, -rep_file), 
            by = c("site_id", "date", "rep_id")) %>%
  select(-c(GPP, ER, K600, depth, temp.water))

# bind together model predictions with observations
p3_preds_all_models_w_obs <- p3_preds_all_models %>%
  mutate(date = as.Date(date)) %>%
  left_join(y = p2a_do_and_metab, by = c("site_id","date"))

# create a timeseries plot that shows the model predictions vs observations
p3_preds_timeseries <- plot_preds_timeseries(preds_data = filter(p3_preds_all_models_w_obs, 
                                                                 date > "2011-10-01", 
                                                                 date < "2016-10-02"),
                                             site_no = "01481500",
                                             variable_obs = "do_mean",
                                             plot_preds = c("base", "metab_dense"),
                                             preds_colors = c("#1b9e77", "#d95f02"),
                                             date_breaks = "1 year", 
                                             date_label_format = "%Y",
                                             line_alpha = 0.5)

# create a scatterplot that shows the model predictions vs observations.
# note that the scatterplot includes all model reps!
p3_preds_scatterplot <- plot_preds_scatter(preds_data = filter(p3_preds_all_models_w_obs, 
                                                               date > "2011-10-01", 
                                                               date < "2016-10-02"), 
                                           site_no = "01481500", 
                                           variable_obs = "do_mean",
                                           plot_preds = c("base", "metab_dense"),
                                           preds_colors = c("#1b9e77", "#d95f02"),
                                           breaks_x = seq(4,16,3), 
                                           breaks_y = seq(4,16,3),
                                           point_size = 0.7,
                                           point_alpha = 0.3, 
                                           plot_legend = FALSE)

# combine the timeseries and the scatterplot in one plot
p3_preds_plot_combined <- p3_preds_timeseries + 
  p3_preds_scatterplot + 
  plot_layout(ncol = 2, widths = c(2, 1))

# save the combined plot showing model predictions vs. observations
ggsave(filename = "3_visualize/out/model_preds_vs_obs.png", 
       plot = p3_preds_plot_combined, 
       width = 12, height = 4.5, units = c("in"), 
       dpi = 300)
  
  
  



