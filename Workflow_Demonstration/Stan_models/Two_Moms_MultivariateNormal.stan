//Two Moms Model with Prior, Posterior, Likelihood, & MAP Estimates Included
//Implementing McElreath's Multivariate Normal Distribution Specification
//Included Cholesky Factorization to Handle the Multi-Collinearity Issues Causing Poor Posterior Exploration
//Jonathan H. Morgan, Ph.D.
//22 January 2025

data {
    int<lower=1> N;                   // Number of observations
    array[N] int<lower=0, upper=1> B1; // First sibling's birth order (binary)
    array[N] int<lower=0, upper=1> B2; // Second sibling's birth order (binary)
    vector[N] M;                      // Family sizes (Mom model)
    array[N] real D;                  // Outcome variable (Daughter model)
}

parameters {
    real a1;                          // Intercept for Mom model
    real a2;                          // Intercept for Daughter model
    real b;                           // Effect of Birth Order, B1 and B2
    real m;                           // Effect of M on D
    real<lower=0> sigma_M;            // Standard deviation for Mom model
    real<lower=0> sigma_D;            // Standard deviation for Daughter model
    cholesky_factor_corr[2] L;        // Cholesky factor of correlation matrix
    real<lower=0, upper=1> p;         // Probability of success for B1 and B2
}

transformed parameters {
    vector[N] mu_M;                   // Mom model linear predictor
    vector[N] mu_D;                   // Daughter model linear predictor
    matrix[2, 2] Sigma;               // Covariance matrix for (M, D)

    // Linear predictors
    mu_M = a1 + b * to_vector(B1);   // Mom model mean
    mu_D = a2 + b * to_vector(B2) + m * M;  // Daughter model mean

    // Covariance matrix
    Sigma = diag_pre_multiply([sigma_M, sigma_D], L);
}

model {
    // Priors
    a1 ~ normal(0, 0.5);
    a2 ~ normal(0, 0.5);
    b ~ normal(0, 0.5);
    m ~ normal(0, 0.5);
    sigma_M ~ exponential(1);
    sigma_D ~ exponential(1);
    L ~ lkj_corr_cholesky(2);        // Prior for Cholesky factor of correlation
    p ~ beta(2, 2);

    // Likelihoods
    for (n in 1:N) {
        row_vector[2] y = to_row_vector([M[n], D[n]]);
        row_vector[2] mu = to_row_vector([mu_M[n], mu_D[n]]);
        y ~ multi_normal_cholesky(mu, Sigma);
    }
    B1 ~ bernoulli(p);
    B2 ~ bernoulli(p);
}

generated quantities {
    // Posterior Predictive Distributions
    vector[N] posterior_M;
    vector[N] posterior_D;

    for (n in 1:N) {
        posterior_M[n] = normal_rng(mu_M[n], sigma_M);
        posterior_D[n] = normal_rng(mu_D[n], sigma_D);
    }

    // Prior Predictive Distributions
    array[N] int prior_B1 = bernoulli_rng(rep_vector(p, N)); // Adjusted to array[N] int
    array[N] int prior_B2 = bernoulli_rng(rep_vector(p, N)); // Adjusted to array[N] int
    vector[N] prior_mu_M;
    vector[N] prior_mu_D;
    vector[N] prior_M;
    vector[N] prior_D;

    for (n in 1:N) {
        prior_mu_M[n] = a1 + b * prior_B1[n];
        prior_mu_D[n] = a2 + b * prior_B2[n] + m * prior_mu_M[n];
        prior_M[n] = normal_rng(prior_mu_M[n], sigma_M);
        prior_D[n] = normal_rng(prior_mu_D[n], sigma_D);
    }

    // Log-likelihood for LOO
    array[N] real log_lik;
    for (n in 1:N) {
        row_vector[2] y = to_row_vector([M[n], D[n]]);
        row_vector[2] mu = to_row_vector([mu_M[n], mu_D[n]]);
        log_lik[n] = multi_normal_cholesky_lpdf(y | mu, Sigma) +
                     bernoulli_lpmf(B1[n] | p) +
                     bernoulli_lpmf(B2[n] | p);
    }

    // Maximum a Posteriori (MAP) Estimate
    array[N] row_vector[2] y;
    array[N] row_vector[2] mu;

    for (n in 1:N) {
        y[n] = [M[n], D[n]];
        mu[n] = [mu_M[n], mu_D[n]];
    }

    real map = bernoulli_lpmf(B1 | rep_vector(p, N)) +
               bernoulli_lpmf(B2 | rep_vector(p, N)) +
               multi_normal_cholesky_lpdf(y | mu, Sigma) +
               normal_lpdf(a1 | 0, 0.5) +
               normal_lpdf(a2 | 0, 0.5) +
               normal_lpdf(b | 0, 0.5) +
               normal_lpdf(m | 0, 0.5) +
               exponential_lpdf(sigma_M | 1) +
               exponential_lpdf(sigma_D | 1) +
               lkj_corr_cholesky_lpdf(L | 2) +
               beta_lpdf(p | 2, 2);
}
