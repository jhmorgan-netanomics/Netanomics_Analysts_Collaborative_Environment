//Two Moms Model with Prior, Posterior, Likelihood, & MAP Estimates Included
//Using a Prior of exponential(0.5) for a more informative prior on the variances to addressing BFMI problems.
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
    real<lower=0> sigma;              // Standard deviation for Mom model
    real b;                           // Effect of B1 on M
    real<lower=0> k;                  // Effect of U on M and D

    real a2;                          // Intercept for Daughter model
    real<lower=0> tau;                // Standard deviation for Daughter model
    real m;                           // Effect of M on D

    vector[N] U;                      // Unmeasured confound (latent variable)

    real<lower=0, upper=1> p;         // Probability of success for B1 and B2
}

transformed parameters {
    vector[N] mu;                     // Mom model linear predictor
    vector[N] nu;                     // Daughter model linear predictor

    // Linear predictors
    mu = a1 + b * to_vector(B1) + k * U;  // Mom model mean
    nu = a2 + b * to_vector(B2) + m * M + k * U; // Daughter model mean
}

model {
    // Priors
    a1 ~ normal(0, 0.5);
    a2 ~ normal(0, 0.5);
    b ~ normal(0, 0.5);
    m ~ normal(0, 0.5);
    k ~ exponential(1);                 // Prior for latent effect of U
    sigma ~ exponential(1);             // Exponential(0.5) prior for variance
    tau ~ exponential(1);               // Exponential(0.5) prior for variance
    U ~ normal(0, 1);                   // Standard normal latent variable
    p ~ beta(2, 2);                     // Bernoulli success probability

    // Likelihoods
    M ~ normal(mu, sigma);            // Mom model
    D ~ normal(nu, tau);              // Daughter model
    B1 ~ bernoulli(p);                // Binary for first sibling
    B2 ~ bernoulli(p);                // Binary for second sibling
}

generated quantities {
    // Prior Predictive Distributions
    array[N] real prior_U = normal_rng(rep_vector(0, N), 1);
    array[N] real prior_B1 = bernoulli_rng(rep_vector(p, N));
    array[N] real prior_B2 = bernoulli_rng(rep_vector(p, N));
    array[N] real prior_mu;
    array[N] real prior_nu;
    array[N] real prior_M;
    array[N] real prior_D;

    for (n in 1:N) {
        prior_mu[n] = a1 + b * prior_B1[n] + k * prior_U[n];
        prior_nu[n] = a2 + b * prior_B2[n] + m * prior_mu[n] + k * prior_U[n];
        prior_M[n] = normal_rng(prior_mu[n], sigma);
        prior_D[n] = normal_rng(prior_nu[n], tau);
    }

    // Posterior Predictive Distributions
    array[N] real posterior_M = normal_rng(mu, sigma);
    array[N] real posterior_D = normal_rng(nu, tau);

    // Log-likelihood for LOO
    array[N] real log_lik;
    for (n in 1:N) {
        log_lik[n] = bernoulli_lpmf(B1[n] | p) +
                     bernoulli_lpmf(B2[n] | p) +
                     normal_lpdf(M[n] | mu[n], sigma) +
                     normal_lpdf(D[n] | nu[n], tau);
    }

    // Maximum a Posteriori (MAP) Estimate
    real map;
    map = bernoulli_lpmf(B1 | rep_vector(p, N)) +
          bernoulli_lpmf(B2 | rep_vector(p, N)) +
          normal_lpdf(M | mu, sigma) +
          normal_lpdf(D | nu, tau) +
          normal_lpdf(U | 0, 1) +
          normal_lpdf(a1 | 0, 0.5) +
          normal_lpdf(a2 | 0, 0.5) +
          normal_lpdf(b | 0, 0.5) +
          normal_lpdf(m | 0, 0.5) +
          exponential_lpdf(k | 1) +
          exponential_lpdf(sigma | 0.5) +
          exponential_lpdf(tau | 0.5) +
          beta_lpdf(p | 2, 2);
}
