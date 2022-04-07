
ER_K_corr <- function(df){
  #'
  #' @description Function to calculate the pearson correlation coefficient
  #' between ER and K600 for each site within a data frame
  #' 
  #' @param df data frame containing cols "site_name","ER", and "K600"
  #' 
  #' @value returns a data frame with one row per site_name in df. 
  #' Each site has a corresponding cor.coef that indicates the strength
  #' of the correlation between ER and K600. Higher correlation
  #' coefficients are indicative of issues with model equifinality. 
  #' See Appling et al. 2018, https://doi.org/10.1002/2017JG004140.
  
  out <- split(x=df,f = df$site_name) %>%
    purrr::map(~ cor(x=.$ER,y=.$K600,method="pearson")) %>%
    data.frame %>% gather(.,site_name,cor.coef)
  
  return(out)
}



filter_metab_sites <- function(metab_estimates, metab_diagnostics, sites, model_conf_vals, cutoff_ER_K_corr){
  #'
  #' @description Function to filter Appling dataset of daily metabolism estimates based on
  #' desired sites, model confidence values, and strength of the correlation between ER and K600.
  #' 
  #' @param metab_estimates data frame containing the daily metabolism estimates and predictors 
  #' from Appling et al. https://www.sciencebase.gov/catalog/item/59eb9c0ae4b0026a55ffe389.
  #' @param metab_diagnostics data frame containing the metbolism model diagnostics from
  #' Appling et al. https://www.sciencebase.gov/catalog/item/59eb9bafe4b0026a55ffe382.
  #' Must contain columns "site", "model_confidence", and "site_min_confidence".
  #' @param sites character string of NWIS sites to retain (e.g. "01473500")
  #' @param model_conf_vals character string indicating which values for model_confidence to retain
  #' from metab_diagnostics. Options include "L", "M", or "H" (corresponding to low, medium, high).
  #' See diagnostics metadata for further details: 
  #' https://www.sciencebase.gov/catalog/item/59eb9bafe4b0026a55ffe382.
  #' @param cutoff_ER_K_corr double; indicates what value should be used as a cutoff used to exclude
  #' where ER-K600 > cutoff value.
  #' 
  #' @value returns a data frame that represents of subset of metab_estimates, with two new 
  #' columns GPP_filtered and ER_filtered where negative GPP days and positive ER days have
  #' been redefined as NA.
  #' 
  #' 
  
  metab_estimates_filtered <- metab_estimates %>%
    # select only those sites that are within desired sites 
    filter(site_id %in% sites) %>%
    # select only those sites where we have high or medium confidence in the model
    left_join(metab_diagnostics[,c("site","model_confidence","site_min_confidence")], 
              by = c("site_name" = "site")) %>%
    filter(site_min_confidence %in% model_conf_vals) %>%
    # select only those sites where the correlation between ER and K600 < user-defined cutoff
    left_join(ER_K_corr(.), by = "site_name") %>%
    filter(abs(cor.coef) < cutoff_ER_K_corr) %>%
    # add columns representing daily metabolic fluxes where negative GPP is NA, 
    # and positive ER is NA
    rowwise() %>%
    mutate(GPP_filtered = if_else(GPP < 0, NA_real_, GPP),
           ER_filtered = if_else(ER > 0, NA_real_, ER)) %>%
    ungroup() %>%
    select(-cor.coef)
  
  return(metab_estimates_filtered)
  
}

