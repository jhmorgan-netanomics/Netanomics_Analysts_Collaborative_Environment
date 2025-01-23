//Two Moms Model with Prior, Posterior, Likelihood, & MAP Estimates Included
//QR Reparmeterization with Half-Normal Priors
//Jonathan H. Morgan, Ph.D.
//22 January 2025

data {
    int<lower=1> N;                   // Number of observations
    array[N] int<lower=0, upper=1> B1; // First sibling's birth order (binary)
    array[N] int<lower=0, upper=1> B2; // Second sibling's birth order (binary)
    vector[N] M;                      // Family sizes (Mom model)
    array[N] real D;                  // Outcome variable (Daughter model)
}

transformed data {
    // Center and scale predictors for QR decomposition
    vector[N] Q_B1 = (to_vector(B1) - mean(to_vector(B1))) / sd(to_vector(B1));
    vector[N] Q_B2 = (to_vector(B2) - mean(to_vector(B2))) / sd(to_vector(B2));
    vector[N] Q_M = (M - mean(M)) / sd(M);
}

parameters {
    real a1;                          // Intercept for Mom model
    real<lower=0> sigma;              // Standard deviation for Mom model
    vector[2] beta_M;                 // QR coefficients for B1 and U in Mom model

    real a2;                          // Intercept for Daughter model
    real<lower=0> tau;                // Standard deviation for Daughter model
    vector[3] beta_D;                 // QR coefficients for B2, M, and U in Daughter model

    vector[N] z_U;                    // Standardized latent variable (non-centered)

    real<lower=0, upper=1> p;         // Probability of success for B1 and B2
}

transformed parameters {
    vector[N] U;                      // Unmeasured confound (latent variable)
    vector[N] mu;                     // Mom model linear predictor
    vector[N] nu;                     // Daughter model linear predictor

    U = z_U;                          // Non-centered parameterization for U

    // Linear predictors using QR coefficients
    mu = a1 + beta_M[1] * Q_B1 + beta_M[2] * U;  // Mom model mean
    nu = a2 + beta_D[1] * Q_B2 + beta_D[2] * Q_M + beta_D[3] * U; // Daughter model mean
}

model {
    // Priors
    a1 ~ normal(0, 0.5);
    a2 ~ normal(0, 0.5);
    beta_M ~ normal(0, 0.5);   // Priors for Mom model QR coefficients
    beta_D ~ normal(0, 0.5);   // Priors for Daughter model QR coefficients
    sigma ~ normal(0, 2.5) T[0, ]; // Half-normal prior for Mom model variance
    tau ~ normal(0, 2.5) T[0, ];  // Half-normal prior for Daughter model variance
    z_U ~ normal(0, 1);           // Non-centered latent variable
    p ~ beta(2, 2);               // Bernoulli success probability

    // Likelihoods
    M ~ normal(mu, sigma);  // Mom model
    D ~ normal(nu, tau);    // Daughter model
    B1 ~ bernoulli(p);      // Binary for first sibling
    B2 ~ bernoulli(p);      // Binary for second sibling
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
        prior_mu[n] = a1 + beta_M[1] * prior_B1[n] + beta_M[2] * prior_U[n];
        prior_nu[n] = a2 + beta_D[1] * prior_B2[n] + beta_D[2] * Q_M[n] + beta_D[3] * prior_U[n];
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
          normal_lpdf(beta_M | 0, 0.5) +
          normal_lpdf(beta_D | 0, 0.5) +
          normal_lpdf(sigma | 0, 2.5) +
          normal_lpdf(tau | 0, 2.5) +
          beta_lpdf(p | 2, 2);
}
