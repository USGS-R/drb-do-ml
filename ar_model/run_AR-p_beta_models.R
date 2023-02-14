###############################################################
# 1. Simulate an AR process with covariates explanatory variables
# to test recovery of parameters with Stan model
# 2. Run model on real data to test prediction
###############################################################

# libraries
library(rstan)
library(tidyverse)
library(lubridate)
library(dataRetrieval)
library(climateR)


# Simulate AR-5 data with one covariate ####

n = 365*10
P = 2
p = 5

# simulate temperature data
x = seq(0, n, by = 1)
tmax <- rnorm(n, 6*sin(x * 2 * pi/365) + 15, 2)
X = matrix(c(rep(1, n), tmax), ncol = P)

beta = matrix(c(5, -0.2), ncol = 1)
phi = matrix(c(0.4, 0.2, 0.1, 0.2, 0), ncol = 1)
sigma <- 1

mu <- as.double(X %*% beta)

y<- arima.sim(n = n, 
               model = list(ar = phi),
               mean = mu,
               sd = sigma)

# fitting the AR model
holdout <- 721
datlist <- list(
  N = n - holdout,
  p = 5,
  y = y[1:(n - holdout)],
  X = X[1:(n - holdout), ]
)

arp_beta <- stan_model("ar_model/AR-p.stan")

fit_arp_beta <- sampling(
  arp_beta,
  data = datlist,
  chains = 4,
  cores = 4
)

print(fit_arp_beta, pars = c('beta', 'phi', 'sigma'))

# forecast the held-out observations
beta_post <- rstan::extract(fit_arp_beta, pars = "beta")$beta
phi_post <- rstan::extract(fit_arp_beta, pars = "phi")$phi
sigma_post <- rstan::extract(fit_arp_beta, pars = "sigma")$sigma
y_rep <- rstan::extract(fit_arp_beta, pars = "y_rep")$y_rep

draws <- nrow(beta_post)

# matrix of draws from the posterior-predictive distribution
post_preds <- matrix(nrow = draws, ncol = n)

# fill in first p observations that are considered fixed
post_preds[, 1:datlist$p] <- matrix(
    rep(y[1:datlist$p], each = draws), nrow = draws, ncol = datlist$p
)

# fill in post. pred. draws from stan
post_preds[, (datlist$p + 1):(n - holdout)] <- y_rep

for(i in 1:draws){
    for(t in (n - holdout + 1):n){
        y_past <- as.double(post_preds[i, (t - datlist$p):(t - 1)])
        post_preds[i, t] <- X[t, ] %*% beta_post[i, ] +
            phi_post[i, ] %*% y_past +
            rnorm(1, sd = sigma_post[i])
    }
}

forecast_df <- data.frame(
    time = 1:n,
    y = as.double(y),
    estim = apply(post_preds, 2, mean),
    low = apply(post_preds, 2, quantile, probs = 0.025, na.rm = T),
    high = apply(post_preds, 2, quantile, probs = 0.975, na.rm = T)
  )

ggplot(forecast_df, aes(x = time, y = y)) +
    geom_ribbon(aes(ymin = low, ymax = high), fill = "brown", alpha = 0.5) +
    geom_line() +
    geom_vline(xintercept = n - holdout) +
    theme_classic() +
    ggtitle("AR5 forecast")

# calculate rmse
rmse <- sqrt(mean((forecast_df$estim[(n-holdout):n] -
                   forecast_df$y[(n-holdout):n])^2, na.rm = T))



# Run ts model on actual dataset ####
site_id <- "01481500"
do_data <- readNWISuv(siteNumbers = site_id, parameterCd = "00300",
                      startDate = "2015-10-01", endDate = "2022-10-01",
                      tz = "America/New_York") |>
  renameNWISColumns() |>
  mutate(date = as.Date(dateTime)) |>
  group_by(date) |>
  summarize(do_mean = mean(DO_Inst, na.rm = TRUE), .groups = "drop")
do_site <- readNWISsite(siteNumbers = site_id) |>
  select(dec_lat_va, dec_long_va, dec_coord_datum_cd) |>
  sf::st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4269)

# download gridmet temperature data using climateR package
met_data <- getGridMET(AOI = do_site, param = "tmax", 
                       startDate = "2015-10-01", endDate = "2022-10-01")

dat <- left_join(do_data, met_data[,c("date","tmax")], by = "date") |>
  mutate(tmax_C = tmax - 273.15,
         year = lubridate::year(date),
         doy = lubridate::yday(date))

n = nrow(dat)
holdout = 721

y = dat$do_mean
X = matrix(c(rep(1, n), dat$tmax_C), ncol = 2)

datlist <- list(
    N = n - holdout,
    p = 5,
    y = y[1:(n-holdout)],
    X = X[1:(n-holdout),]
)

arp_beta <- stan_model('ar_model/AR-p.stan')

fit_arp_beta <- sampling(
  arp_beta,
  data = datlist,
  chains = 4,
  cores = 4
)

print(fit_arp_beta, pars = c('phi', 'beta', 'sigma'))

# forecast the held-out observations
beta_post <- rstan::extract(fit_arp_beta, pars = "beta")$beta
phi_post <- rstan::extract(fit_arp_beta, pars = "phi")$phi
sigma_post <- rstan::extract(fit_arp_beta, pars = "sigma")$sigma
y_rep <- rstan::extract(fit_arp_beta, pars = "y_rep")$y_rep

draws <- nrow(beta_post)

# matrix of draws from the posterior-predictive distribution
post_preds <- matrix(nrow = draws, ncol = n)

# fill in first p observations that are considered fixed
post_preds[, 1:datlist$p] <- matrix(
  rep(y[1:datlist$p], each = draws), nrow = draws, ncol = datlist$p
)

# fill in post. pred. draws from stan
post_preds[, (datlist$p + 1):(n - holdout)] <- y_rep

for(i in 1:draws){
  for(t in (n - holdout + 1):n){
    y_past <- as.double(post_preds[i, (t - datlist$p):(t - 1)])
    post_preds[i, t] <- X[t, ] %*% beta_post[i, ] +
      phi_post[i, ] %*% y_past +
      rnorm(1, sd = sigma_post[i])
  }
}

forecast_df <- data.frame(
  time = 1:n,
  y = as.double(y),
  estim = apply(post_preds, 2, mean),
  low = apply(post_preds, 2, quantile, probs = 0.025, na.rm = T),
  high = apply(post_preds, 2, quantile, probs = 0.975, na.rm = T)
)

ggplot(forecast_df, aes(x = time, y = y)) +
  geom_ribbon(aes(ymin = low, ymax = high), fill = "brown", alpha = 0.5) +
  geom_line() +
  geom_vline(xintercept = n - holdout) +
  theme_classic() +
  ggtitle("AR5 forecast")

# calculate rmse
rmse <- sqrt(mean((forecast_df$estim[(n-holdout):n] -
                     forecast_df$y[(n-holdout):n])^2, na.rm = T))


# Simulate data for the hierarchical AR model ####

S = 6
n <- round(rnorm(S, 365*5, 200))
n_S <- cumsum(c(1, n))
p = 5

beta = matrix(c(5, -0.2), ncol = 1)
phi = matrix(c(0.4, 0.2, 0.1, 0.2, 0), ncol = 1)
sigma <- 1

X <- data.frame()
for(s in 1:S){
    x = seq(0, n[s], by = 1)
    tmax <- rnorm(n[s], rnorm(1, 6, 0.5)*sin(x * 2 * pi/365) + rnorm(1, 15, 1), 2)
    xx = data.frame(
        day = seq(1, n[s]),
        tmax = tmax, 
        ss = s, 
        slope = rnorm(1, 0.5, 0.1)) 
    mu = beta[1] + beta[2] * xx$tmax * xx$slope
    xx$y = arima.sim(n = n[s], 
                  model = list(ar = phi),
                  mean = mu,
                  sd = sigma)
    
    X <- bind_rows(X, xx)
}


ggplot(X, aes(day, y, col = slope))+
    geom_line() +
    facet_wrap(.~ss, ncol = 1)
  
datlist <- list(
    N = nrow(X),
    p = 5,
    S = S,
    n = n_S,
    ss = X$ss,
    y = X$y,
    tmax = X$tmax,
    slope = X$slope
)

arp_hier <- stan_model('ar_model/AR-p_hierarchical.stan')

fit_arp_h <- sampling(
    arp_hier,
    data = datlist,
    chains = 4,
    cores = 4
)
saveRDS(fit_arp_h, 'ar_model/data/sim_arp_h_fit.rds')

print(fit_arp_h, pars = c('beta', 'phi', 'sigma'))

# test hierarchical model on real dataset ####

dat <- readRDS("ar_model/data/drb_do_data_w_splits.rds")

dat <- dat %>% 
    select(site_id, date, do_min, do_mean, do_max, tmax = tmmx, slope = SLOPE,
           partition) %>%
    mutate(ss = as.numeric(factor(site_id))) %>%
    filter(!is.na(do_mean))

ggplot(dat, aes(date, do_mean, col = partition)) +
    geom_line()+
    facet_wrap(.~site_id, ncol = 2)

dat <- filter(dat, partition != 'test')

dd <- dat %>% 
  filter(partition == 'training') %>%
  mutate(ss = as.numeric(factor(site_id)))
  
n_S <- cumsum(c(1, rle(dd$ss)$lengths))

datlist <- list(
    N = nrow(dd),
    p = 5,
    S = length(unique(dd$ss)),
    n = n_S,
    ss = dd$ss,
    y = dd$do_mean,
    tmax = dd$tmax,
    slope = dd$slope
)

fit_data_arp_h <- sampling(
    arp_hier,
    data = datlist,
    chains = 4,
    cores = 4
)
saveRDS(fit_data_arp_h, 'ar_model/data/dat_arp_h_fit.rds')

print(fit_data_arp_h, pars = c('phi', 'beta', 'sigma'))

# predict the validation data
# forecast the held-out observations
beta_post <- rstan::extract(fit_data_arp_h, pars = "beta")$beta
phi_post <- rstan::extract(fit_data_arp_h, pars = "phi")$phi
sigma_post <- rstan::extract(fit_data_arp_h, pars = "sigma")$sigma
y_rep <- rstan::extract(fit_data_arp_h, pars = "y_rep")$y_rep

draws <- nrow(beta_post)

n_S <- data.frame(site = c(unique(dd$site_id), NA), 
                  index = cumsum(c(1, rle(dd$ss)$lengths)),
                  n = c(rle(dd$ss)$lengths,NA))
n_Sv <- data.frame(site = c(unique(dat$site_id), NA),
                   index = cumsum(c(1, rle(dat$ss)$lengths)),
                   n = c(rle(dat$ss)$lengths,NA))


post_preds <- matrix(nrow = draws)
X_fc <- matrix(c(rep(1, nrow(dat)), dat$tmax*dat$slope), ncol = 2)
for(s in 3:(nrow(n_Sv)-1)){
    s_id <- n_Sv$site[s]
    n_val <-n_Sv$n[s]
    n_test <-n_S[which(n_S$site==s_id),]
    if(nrow(n_test)==0){n_test <- data.frame(site = s_id, n = 0)}
    mu <- matrix(rep(NA, n_val*draws), nrow = draws)
    mu[,1:5] <- rep(dat$do_mean[n_Sv$index[s]:(n_Sv$index[s]+datlist$p-1)], 
                    each = draws)
    nn <- 6
    
    if(s_id %in% n_S$site){
        mu[,nn:n_test$n] <-
          y_rep[,(n_test$index+datlist$p):(n_test$index+n_test$n-1)]
        nn <- n_test$n+1
    }
    
    if(nn>n_val){
        post_preds <- cbind(post_preds,mu)
        next
    }
    
    for(i in 1:draws){
        for(t in nn:n_val){
            y_past <- as.double(mu[i, (t - datlist$p):(t - 1)])
            mu[i, t] <- X_fc[n_Sv$index[s]+t-1, ] %*% beta_post[i, ] +
              phi_post[i, ] %*% y_past +
              rnorm(1, sd = sigma_post[i])
            
        }
      if(i%%100 == 0) print(i/4000)
    }
    
    post_preds <- cbind(post_preds,mu)
    
}
post_preds <- post_preds[,-1]

forecast_df <- dat %>%
  select(date, site_id, y = do_mean, partition) %>%
  mutate(estim = apply(post_preds, 2, mean),
         low = apply(post_preds, 2, quantile, probs = 0.025, na.rm = T),
         high = apply(post_preds, 2, quantile, probs = 0.975, na.rm = T)
)

val_sites <- dat %>% filter(partition == 'validation') %>%
  select(site_id) %>%
  unique() %>%c()

forecast_df %>%
  filter(site_id %in% val_sites$site_id)%>%
ggplot(aes(date, y))+
    geom_ribbon(aes(ymin = low, ymax = high, fill = partition))+
    geom_line(size = 0.2) +
    facet_wrap(.~site_id, ncol = 1, strip.position = 'right') +
    ylab('DO mean')+
    ggtitle('AR model prediction with slope and temperature')+
    theme_bw()

data.frame(post_preds)
rmse_df <- bind_cols(forecast_df, t(post_preds)) %>%
  filter(partition == 'validation') %>%
  data.frame()

rmse <- data.frame()
for(s in unique(rmse_df$site_id)){
  s_df <- filter(rmse_df, site_id == s)
  s_rmse <- vector()
  for(i in 1:draws){
    r <- sqrt(mean((s_df[,i+8] - s_df$y)^2, na.rm = T))
    s_rmse <- c(s_rmse, r)
  }
  rr <- data.frame(site_id = s,
                   rmse = mean(s_rmse),
                   low = quantile(s_rmse, 0.025),
                   high = quantile(s_rmse, 0.975))
  rmse <- bind_rows(rmse, rr)
}

s_rmse <- vector()
for(i in 1:draws){
  r <- sqrt(mean((rmse_df[,i+8] - rmse_df$y)^2, na.rm = T))
  s_rmse <- c(s_rmse, r)
}
rr <- data.frame(site_id = 'all',
                 rmse = mean(s_rmse),
                 low = quantile(s_rmse, 0.025),
                 high = quantile(s_rmse, 0.975))
rmse <- bind_rows(rmse, rr)
row.names(rmse) <- NULL

write_csv(rmse, 'ar_model/data/rmse_of_ar_model_fits.csv')
