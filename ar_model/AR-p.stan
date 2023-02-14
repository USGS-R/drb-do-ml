/////////////////////////////////////////////////////////////
// This Stan program fits an AR(p) Gaussian time-series model
// with the potential for covariates
/////////////////////////////////////////////////////////////


data{

    int<lower = 1> N;           // number of observations
    int<lower = 0> p;           // guess for the max order of the autoregressive process
    vector[N] y;                // vector of responses
    matrix[N, 2] X;             // model matrix for covariates

}


parameters{

    vector[2] beta;                       // coefficients
    vector<lower = -1,upper = 1>[p] phi;  // autoregression parameters
    real<lower = 0> sigma;                // sd of the innovations

}


transformed parameters{

    vector[N] mu;               // declare vector of means

    // assume no error for first p observations
    mu[1:p] = y[1:p];

    // complete the AR process
    for(t in (p + 1):N){
        mu[t] = X[t, ] * beta + (y[(t - p):(t - 1)])' * phi;
    }

}


model{

    // priors
    beta ~ normal(0,1);
    phi ~ normal(0,1);
    sigma ~ cauchy(0, 1);

    // likelihood
    y[(p + 1):N] ~ normal(mu[(p + 1):N], sigma);

}


generated quantities{

    // post. pred. sampling
    real y_rep[N - p] = normal_rng(mu[(1 + p):N], sigma);

    // residuals
    vector[N - p] resid = y[(p + 1):N] - mu[(p + 1):N];

}

