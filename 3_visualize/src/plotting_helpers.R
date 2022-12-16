### This script contains helper functions for plotting model predictive performance


#' @title Plot model performance
#' 
#' @description 
#' Function to plot the model performance by partition. 
#' 
#' @param metrics_df data frame containing the predictive performance metrics. 
#' Must contain columns "variable", "partition", and "model_id".
#' @param performance_metric character string indicating which performance metric 
#' to plot from `metrics_df`.
#' @param fileout character string indicating name of saved png file, including 
#' file path and extension.  
#' @param partition_select character string or character vector indicating which 
#' model partitions should be included in the plot. Options are "val", "train", and "val_times".
#' @param partition_colors character string or character vector containing the hex
#' color codes that are used to represent the model partitions.
#' @param y_range numeric vector of length 2, indicating the desired range of the y-axis. If
#' none is provided, we will estimate the best y-axis range. Defaults to NULL.
#' @param y_label character string containing the y axis label. If none is provided, 
#' we will do our best to impute one. Defaults to NULL.
#' @param plot_title logical; should the plot include a title indicating the model_id? 
#' Defaults to TRUE.
#' @param panel_grids logical; should we plot the background grid lines? Defaults to TRUE.
#' @param box_size numeric; width of border lines around box plots
#' @param facet_text_size integer
#' @param axis_text_size integer
#' @param axis_title_size integer
#' @param legend_text_size integer
#' @param plot_height_in numeric; height of saved plot in inches
#' @param plot_width_in numeric; width of saved plot in inches
#' 
#' @returns 
#' Saves a png file containing a boxplot with one panel for each target variable. 
#'
plot_metrics_by_partition <- function(metrics_df, 
                                      performance_metric,
                                      fileout,
                                      partition_select = c("val","train","val_times"),
                                      partition_colors = c("#bdd7e7","#6baed6","#2171b5"),
                                      y_range = NULL,
                                      y_label = NULL,
                                      plot_title = TRUE,
                                      panel_grids = TRUE,
                                      box_size = 0.25,
                                      facet_text_size = 13,
                                      axis_text_size = 12,
                                      axis_title_size = 13,
                                      legend_text_size = 12,
                                      plot_height_in = 4,
                                      plot_width_in = 6.4){
  
  # subset the metrics data frame and rename the column containing
  # the requested performance metric to the more generic "metric"
  metrics_df_subset <- metrics_df %>%
    filter(partition %in% partition_select) %>%
    select('model_id', 'partition', 'variable', 'rep_id',c(!!performance_metric)) %>%
    rename(metric := !!performance_metric) %>%
    mutate(variable_renamed = recode(variable,
                                     "do_max" = "DO-max", 
                                     "do_min" = "DO-min", 
                                     "do_mean" = "DO-mean")) %>%
    mutate(variable_renamed = factor(variable_renamed,
                                     levels = c("DO-mean","DO-min","DO-max")))
  
  # define the y-axis label
  if(is.null(y_label)){
    if(grepl("rmse", performance_metric)){
      y_label <- expression(RMSE~(mg~O[2]~L^-1))
    }
    if(grepl("nse", performance_metric)){
      y_label <- expression(NSE)
    }
    if(grepl("bias", performance_metric)){
      y_label <- expression(Mean~bias~(mg~O[2]~L^-1))
    }
    if(grepl("kge", performance_metric)){
      y_label <- expression(KGE)
    }
  }
  
  # define the y-axis range
  if(is.null(y_range)){
    y_range <- c((0.85*min(metrics_df_subset$metric)),
                 (1.15*max(metrics_df_subset$metric)))
  }
  
  # make the plot
  p <- metrics_df_subset %>%
    ggplot() + 
    geom_boxplot(aes(x= partition, y = metric, fill = partition), size = box_size) +
    facet_wrap(~variable_renamed) + 
    scale_fill_manual(values = partition_colors, name = "") +
    labs(x = "", y = y_label)+
    coord_cartesian(ylim = c(y_range[1], y_range[2])) +
    theme_bw() + 
    theme(strip.background = element_blank(),
          strip.text = element_text(size = facet_text_size),
          axis.title = element_text(size = axis_title_size),
          axis.text = element_text(size = axis_text_size),
          axis.title.y = element_text(margin = margin(r = 10)),
          axis.title.x = element_text(margin = margin(t = 12)),
          legend.text = element_text(size = legend_text_size),
          legend.key.size = unit(0.65, "cm"),
          legend.key.height = unit(0.75, 'cm'))
  
  if(!panel_grids){
    p <- p + theme(panel.grid.major = element_blank(),
                   panel.grid.minor = element_blank())
  }
  if(plot_title){
    p <- p + ggtitle(unique(metrics_df_subset$model_id))
  }
  
  # save the plot
  ggsave(filename = fileout, plot = p, 
         width = plot_width_in, height = plot_height_in, units = c("in"), 
         dpi = 300)
  
  return(fileout)
}



#' @title Read reach-level feather files
#' 
#' @description
#' Function to read in feather file containing model predictions and performance
#' metrics for individual site locations.
#' 
#' @param path file path of the feather file
#' @param preds_file file name with .feather file extension
#' 
#' @returns 
#' Returns a data frame containing the reach-level predictive performance metrics.
#' 
read_preds_feather <- function(path, preds_file = "val_preds.feather"){
  
  rep <- substr(path, nchar(path), nchar(path))
  file_name <- paste0(path,"/",preds_file)
  
  preds <- arrow::read_feather(file_name) %>%
    mutate(rep_id = rep)
  
  return(preds)
}



#' @title Plot timeseries of model predictions with observations
#' 
#' @description 
#' Function to plot a timeseries of observations with predictions from up to
#' two different models, "base" for baseline LSTM, and/or "metab_dense" for
#' the LSTM with a metab dense layer. All replicates are plotted as separate
#' lines.
#' 
#' @param preds_data data frame containing the model predictions and observations.
#' Must include columns "site_no", "rep_id", "date", and `variable_obs`
#' @param site_no character string indicating which site to plot
#' @param variable_obs character string indicating which target variable to plot.
#' Options include "do_mean", "do_max", and "do_min"
#' @param plot_preds character vector indicating which model predictions to plot. 
#' Options include "base" and/or "metab_dense". Defaults to c("base", "metab_dense").
#' @param preds_colors character string or character vector containing the hex
#' color codes that are used to represent the different models.
#' @param date_breaks character string indicating the date breaks to use. Defaults
#' to "2_months". See ??scale_x_date for more information.
#' @param date_label_format character string indicating the format to use for the 
#' date breaks. Defaults to "%b %Y". See ??scale_x_date for more information.
#' @param line_width numeric; controls the width of the lines for each model rep
#' @param line_alpha numeric; controls the transparency of the lines for each model rep
#' 
#' @returns 
#' Returns a ggplot object
#' 
plot_preds_timeseries <- function(preds_data, 
                                  site_no, 
                                  variable_obs = "do_mean",
                                  plot_preds = c("base", "metab_dense"),
                                  preds_colors = c("#5ab4ac", "#fc8d62"),
                                  date_breaks = "2 months", 
                                  date_label_format = "%b %Y",
                                  line_width = 0.25,
                                  line_alpha = 0.5){
  
  # get site name
  site_info <- dataRetrieval::readNWISsite(siteNumbers = c(site_no))
  site_name <- site_info$station_nm
  
  # define variable names that correspond w/ preferences in `plot_preds`
  variable_pred_base <- paste0(variable_obs, "_base")
  variable_pred_metab <- paste0(variable_obs, "_metab_dense")
  cols_select <- c("date", "site_id", "rep_id", variable_obs, variable_pred_base, variable_pred_metab)
  
  # define y-axis labels that correspond w/ selected `variable_obs`
  if(variable_obs == "do_mean"){
    y_axis_label <- expression(Daily~mean~DO~(mg~O[2]~L^-1))
  }
  if(variable_obs == "do_min"){
    y_axis_label <- expression(Daily~max~DO~(mg~O[2]~L^-1))
  }
  if(variable_obs == "do_max"){
    y_axis_label <- expression(Daily~max~DO~(mg~O[2]~L^-1))
  }
  
  # format data frame
  preds_data_subset <- preds_data %>% 
    filter(site_id %in% c(site_no)) %>%
    select(all_of(cols_select)) %>%
    rename(var_obs := !!variable_obs,
           var_mod_base := !!variable_pred_base,
           var_mod_metab := !!variable_pred_metab) %>%
    mutate(rep_id = as.factor(rep_id))

  # make base figure by plotting observed DO data
  p <- preds_data_subset %>%
    ggplot() + 
    geom_point(aes(x= date, y = var_obs, color = "observed"), size = 0.9) 
    
  # now add on model predictions, depending on which model ids are requested in `plot_preds`
  if(length(plot_preds) == 1 && plot_preds == "base"){
    color_values <- c('gray50',preds_colors[1],'white')
    labels <- paste("<span style='color:",
                    c('black','black','white'),
                    "'>",
                    c('observed','DL-predicted','PGDL-predicted'),
                    "</span>")
    p1 <- p + 
      geom_line(aes(x=date, y = var_mod_base, group = rep_id, color = "predicted"),size = line_width, alpha = line_alpha) +
      geom_line(aes(x=date, y = var_mod_metab, group = rep_id, color = "zpredicted"),size = line_width, alpha = 0) 
  }
  
  if(length(plot_preds) == 1 && plot_preds == "metab_dense"){
    color_values <- c('gray50',preds_colors[1],'white')
    labels <- paste("<span style='color:",
                    c('black','black','white'),
                    "'>",
                    c('observed','PGDL-predicted','DL-predicted'),
                    "</span>")
    p1 <- p + 
      geom_line(aes(x=date, y = var_mod_base, group = rep_id, color = "zpredicted"), size = line_width, alpha = 0) +
      geom_line(aes(x=date, y = var_mod_metab, group = rep_id, color = "predicted"), size = line_width, alpha = line_alpha)
  }
  
  if("metab_dense" %in% plot_preds & "base" %in% plot_preds){
    color_values <- c('gray50',preds_colors[1],preds_colors[2])
    labels <- paste("<span style='color:",
                    c('black','black','black'),
                    "'>",
                    c('observed','DL-predicted','PGDL-predicted'),
                    "</span>")
    p1 <- p + 
      geom_line(aes(x = date, y = var_mod_base, group = rep_id, color = "predicted"), size = line_width, alpha = line_alpha) +
      geom_line(aes(x = date, y = var_mod_metab, group = rep_id, color = "zpredicted"), size = line_width, alpha = line_alpha)
  }
  
  # finalize plot formatting 
  p2 <- p1 + 
    scale_color_manual(name = '',
                       labels = labels,
                       values = color_values,
                       guide = guide_legend(override.aes = list(
                         linetype = c("blank", "solid",'solid'),
                         shape = c(16, NA,NA),
                         size = c(2.5,1,1)))) +
    scale_x_date(date_breaks = date_breaks, 
                 date_labels = date_label_format) +
    ggtitle(label = site_name, subtitle = paste0("USGS ", site_no)) + 
    labs(x = "", y = y_axis_label) +
    theme_classic() + 
    theme(axis.title = element_text(size = 13),
          axis.text = element_text(size = 12),
          legend.text = ggtext::element_markdown(size = 13),
          legend.key.size = unit(0.65, "cm"),
          legend.key.height = unit(0.75, 'cm'),
          axis.title.x = element_text(margin = margin(t = 10, r = 0, b = 0, l = 0)))
  
  return(p2)
}



#' @title Plot scatterplot of model predictions with observations
#' 
#' @description 
#' Function to plot a scatterplot of observations with predictions from up to
#' two different models, "base" for baseline LSTM, and/or "metab_dense" for the
#' LSTM with a metab dense layer. Note that all replicates are included in this plot.
#' 
#' @param preds_data data frame containing the model predictions and observations.
#' Must include columns "site_no", "rep_id", "date", and `variable_obs`
#' @param site_no character string indicating which site to plot
#' @param variable_obs character string indicating which target variable to plot.
#' Options include "do_mean", "do_max", and "do_min"
#' @param plot_preds character vector indicating which model predictions to plot. 
#' Options include "base" and/or "metab_dense". Defaults to c("base", "metab_dense").
#' @param preds_colors character string or character vector containing the hex
#' color codes that are used to represent the different models.
#' @param breaks_x sequence of length 3 that represents the lower limit for the x-axis,
#' the upper limit for the x-axis, and the step between major axis breaks.
#' @param breaks_y sequence of length 3 that represents the lower limit for the y-axis,
#' the upper limit for the y-axis, and the step between major axis breaks.
#' @param point_size numeric; controls the size of the points
#' @param point_alpha numeric; controls the transparency of the points
#' @param plot_legend logical; should a legend be included in the plot?
#' 
#' @returns 
#' Returns a ggplot object
#' 
plot_preds_scatter <- function(preds_data, 
                               site_no, 
                               variable_obs = "do_mean",
                               plot_preds = c("base", "metab_dense"),
                               preds_colors = c("#5ab4ac", "#fc8d62"),
                               breaks_x = seq(6,18,3), 
                               breaks_y = seq(6,18,3),
                               point_size = 1,
                               point_alpha = 0.5,
                               plot_legend = FALSE){
  
  # define variable names that correspond w/ preferences in `plot_preds`
  variable_pred_base <- paste0(variable_obs, "_base")
  variable_pred_metab <- paste0(variable_obs, "_metab_dense")
  cols_select <- c("date", "site_id", "rep_id", variable_obs, variable_pred_base, variable_pred_metab)
  
  # define y-axis labels that correspond w/ selected `variable_obs`
  if(variable_obs == "do_mean"){
    y_axis_label <- expression(Predicted~mean~DO~(mg~O[2]~L^-1))
    x_axis_label <- expression(Observed~mean~DO~(mg~O[2]~L^-1))
  }
  if(variable_obs == "do_min"){
    y_axis_label <- expression(Predicted~max~DO~(mg~O[2]~L^-1))
    x_axis_label <- expression(Observed~max~DO~(mg~O[2]~L^-1))
  }
  if(variable_obs == "do_max"){
    y_axis_label <- expression(Predicted~max~DO~(mg~O[2]~L^-1))
    x_axis_label <- expression(Observed~max~DO~(mg~O[2]~L^-1))
  }
  
  # format data frame
  preds_data_subset <- preds_data %>% 
    filter(site_id %in% c(site_no)) %>%
    select(all_of(cols_select)) %>%
    rename(var_obs := !!variable_obs,
           var_mod_base := !!variable_pred_base,
           var_mod_metab := !!variable_pred_metab) %>%
    mutate(rep_id = as.factor(rep_id))
  
  # make base figure
  p <- preds_data_subset %>%
    ggplot() 
  
  # now add on model predictions, depending on which model ids are requested in `plot_preds`
  if(length(plot_preds) == 1 && plot_preds == "base"){
    p1 <- p + 
      geom_point(aes(x = var_obs, y = var_mod_base, group = rep_id, color = "predicted"),size = point_size, alpha = point_alpha) +
      scale_color_manual(name = '',
                         labels = c("DL-predicted"),
                         values = preds_colors[1])
  }
  if(length(plot_preds) == 1 && plot_preds == "metab_dense"){
    p1 <- p +
      geom_point(aes(x = var_obs, y = var_mod_metab, color = "zpredicted"),size = point_size, alpha = point_alpha) +
      scale_color_manual(name = '',
                         labels = c("PGDL-predicted"),
                         values = preds_colors[2])
  }
  if("metab_dense" %in% plot_preds & "base" %in% plot_preds){
    p1 <- p +
      geom_point(aes(x = var_obs, y = var_mod_base, group = rep_id, color = "predicted"), size = point_size, alpha = point_alpha) + 
      geom_point(aes(x = var_obs, y = var_mod_metab, group = rep_id, color = "zpredicted"), size = point_size, alpha = point_alpha) +
      scale_color_manual(name = '',
                         labels = c("DL-predicted","PGDL-predicted"),
                         values = preds_colors)
  }
  
  # finalize plot formatting 
  p2 <- p1 + 
    coord_cartesian(xlim=c(min(breaks_x), max(breaks_x)), 
                    ylim = c(min(breaks_y),max(breaks_y))) +
    scale_x_continuous(breaks = breaks_x) +
    scale_y_continuous(breaks = breaks_y) +
    labs(x = x_axis_label, y = y_axis_label) +
    geom_abline(slope = 1, intercept = 0, lty = 2, size = 0.75) +
    theme_classic() + 
    theme(axis.title = element_text(size = 13),
          axis.text = element_text(size = 12),
          axis.title.x = element_text(margin = margin(t = 10)),
          axis.title.y = element_text(margin = margin(r = 10)),
          legend.text = element_text(size = 12))
  
  if(!plot_legend){
    p2 <- p2 + theme(legend.position = "none")
  }
  
  return(p2)
}



