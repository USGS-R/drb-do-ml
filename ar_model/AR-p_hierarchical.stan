/////////////////////////////////////////////////////////////
// This Stan program fits an AR(p) Gaussian time-series model
// with the potential for covariates
/////////////////////////////////////////////////////////////
data{
    
    int<lower = 1> N;           // total number of observations
    int<lower = 0> p;           // guess for the max order of the autoregressive process
    int<lower = 1> S;           // number of sites to fit
    int<lower = 1> n[S+1];      // starting index for each site
    vector[N] ss;               // site number
    vector[N] y;                // vector of responses
    vector[N] tmax;             // temperature
    vector[N] slope;            // slope

}


parameters{

    vector[2] beta;                       // coefficients
    vector<lower = -1,upper = 1>[p] phi;  // autoregression parameters
    real<lower = 0> sigma;                // sd of the innovations

}


transformed parameters{

    vector[N] mu;               // declare vector of means

    for(s in 1:S){
        // assume no error for first p observations at each site
        mu[n[s]:(n[s]+p-1)] <- y[n[s]:(n[s]+p-1)];

        // complete the AR process
        for(t in (n[s] + p):(n[s+1] - 1)){
            mu[t] = beta[1] + beta[2] * tmax[t] * slope[t] + (y[(t - p):(t - 1)])' * phi;
        }
    }    
    
}


model{

    // priors
    beta ~ normal(0,1);
    phi ~ normal(0,1);
    sigma ~ cauchy(0, 1);

    // likelihood
    for(s in 1:S){
        y[(n[s] + p):(n[s+1]-1)] ~ normal(mu[(n[s] + p):(n[s+1]-1)], sigma);
    }
}


generated quantities{

    // vector[N] y_rep 
    // post. pred. sampling
    real y_rep[N] = normal_rng(mu, sigma);

    // residuals
    vector[N] resid = y - mu;

}

