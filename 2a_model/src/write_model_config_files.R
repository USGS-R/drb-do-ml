#' @title Write base model config file
#' 
#' @description 
#' Function to take model inputs and parameters from that get defined in 
#' _targets.R and write a model configuration file.
#' 
#' @param cfg_options a list containing the model configuration parameters.
#' @param fileout character string indicating the name of the saved yml file, 
#' including file path and .yml extension.
#' @param ... optional; additional parameters can be passed as inputs to the 
#' model config file such as the experiment name.
#' 
#' @return 
#' Returns a saved yml file that contains all of the model inputs/parameters 
#' that were passed to this function.
#' 
write_config_file <- function(cfg_options, fileout, ...){
  
  cfg_options_all <- c(list(...), cfg_options)
  
  # Format select inputs/variables if they are included in cfg_options. This
  # is a little clunky, but we need to assign a non-null attribute to ensure
  # a string scalar is quoted using yaml::as.yaml(). Use silent = TRUE to 
  # suppress warnings and errors that appear if one of the variables below 
  # is not included in cfg_options.
  try(expr = {attr(cfg_options_all$out_dir, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {attr(cfg_options_all$exp_name, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {attr(cfg_options_all$validation_sites, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {attr(cfg_options_all$test_sites, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {attr(cfg_options_all$x_vars, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {attr(cfg_options_all$y_vars, "quoted") <- TRUE}, silent = TRUE)
  try(expr = {cfg_options_all$num_replicates <- as.integer(format(round(cfg_options_all$num_replicates,digits = 2),nsmall = 0))},
      silent = TRUE)
  try(expr = {cfg_options_all$epochs <- as.integer(format(round(cfg_options_all$epochs,digits = 2),nsmall = 0))},
      silent = TRUE)
  try(expr = {cfg_options_all$hidden_size <- as.integer(format(round(cfg_options_all$hidden_size,digits = 2),nsmall = 0))},
      silent = TRUE)
  try(expr = {cfg_options_all$lambdas <- as.integer(format(round(cfg_options_all$lambdas,digits = 2),nsmall = 0))},
      silent = TRUE)
  
  # Save as yml 
  out <- yaml::as.yaml(cfg_options_all, 
                       # define how definitions should be indented
                       indent = 2,
                       indent.mapping.sequence = TRUE,
                       # add special handlers to return logical values
                       # with the specific formatting we want.
                       handlers = list(
                         logical = function(x){
                           result <- ifelse(x, "True", "False")
                           class(result) <- "verbatim"
                           return(result)
                           }
                         ),
                       )
  
  cat(out,"\n", file = fileout)
  
  return(fileout)

}


