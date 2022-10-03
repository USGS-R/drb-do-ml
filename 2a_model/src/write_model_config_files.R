#' @title Write base model config file
#' 
#' @description 
#' Function to take model inputs and parameters from that get defined in 
#' _targets.R and write a base model configuration file.
#' 
#' @param fileout character string indicating the name of the saved yml file,
#' including file name, path, and extension. 
#' @param model_save_dir file directory where base model config file should
#' be saved.
#' @param seed logical, defaults to FALSE
#' @param n_reps integer that indicates how many replicate model runs should be performed.
#' @param trn_offset integer
#' @param tst_val_offset integer
#' @param early_stopping logical, defaults to FALSE
#' @param epochs integer
#' @param hidden_size integer
#' @param dropout numeric
#' @param recurrent_dropout numeric
#' @param finetune_learning_rate numeric
#' @param val_sites vector of character strings indicating the site numbers for those
#' sites that should be withheld for model validation purposes.
#' @param test_sites vector of character strings indicating the site numbers for those
#' sites that should be withheld for model testing purposes.
#' @param train_start_date character string indicating the earliest date of the model 
#' training period, formatted as "YYYY-MM-DD."
#' @param train_end_date character string indicating the latest date of the model 
#' training period, formatted as "YYYY-MM-DD."
#' @param val_start_date character string indicating the earliest date of the model 
#' validation period, formatted as "YYYY-MM-DD."
#' @param val_end_date character string indicating the latest date of the model
#' validation period, formatted as "YYYY-MM-DD."
#' @param test_start_date, character string indicating the earliest date of the model 
#' test period, formatted as "YYYY-MM-DD."
#' @param test_end_date character string indicating the latest date of the model
#' test period, formatted as "YYYY-MM-DD."
#' 
#' @return 
#' Returns a saved yml file that contains all of the model inputs/parameters 
#' that were passed to this function.
#' 
write_base_config_file <- function(fileout, model_save_dir, 
                                   seed = FALSE, n_reps, 
                                   trn_offset, tst_val_offset, 
                                   early_stopping = FALSE, 
                                   epochs, hidden_size, dropout,
                                   recurrent_dropout, finetune_learning_rate,
                                   val_sites, test_sites,
                                   train_start_date, train_end_date, 
                                   val_start_date, val_end_date,
                                   test_start_date, test_end_date){
  
  # Format select inputs/variables
  attr(model_save_dir, "quoted") <- TRUE
  attr(val_sites, "quoted") <- TRUE
  attr(test_sites, "quoted") <- TRUE
  n_reps <- as.integer(format(round(n_reps,digits = 2),nsmall = 0))
  
  # Define model inputs and parameters
  cfg_inputs <- list(out_dir = model_save_dir, 
                     seed = seed,
                     num_replicates = n_reps,
                     trn_offset = trn_offset,
                     tst_val_offset = tst_val_offset,
                     early_stopping = early_stopping,
                     train_start_date = list(train_start_date),
                     train_end_date = list(train_end_date),
                     val_start_date = list(val_start_date),
                     val_end_date = list(val_end_date),
                     test_start_date = list(test_start_date),
                     test_end_date = list(test_end_date),
                     validation_sites = val_sites,
                     test_sites = test_sites,
                     epochs = epochs,
                     hidden_size = hidden_size,
                     dropout = dropout,
                     recurrent_dropout = recurrent_dropout,
                     finetune_learning_rate = finetune_learning_rate)
  
  # Save as yml 
  out <- yaml::as.yaml(cfg_inputs, 
                       # define how definitions should be indented
                       indent = 2,
                       indent.mapping.sequence = TRUE,
                       # add special handlers 
                       handlers = list(
                         logical = function(x) {
                           result <- ifelse(x, "True", "False")
                           class(result) <- "verbatim"
                           return(result)
                           }
                         ),
                       )
  
  cat(out,"\n", file = fileout)
  
  return(fileout)

}





