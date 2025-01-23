// Assessing Evidence for the Null Hypothesis:
// Namely, that Daughter Family Size (D) is only a function of the population-level posterior mean (i.e., the intercept),
// with no influence from covariates (e.g., B1, B2, or M).
//Jonathan H. Morgan, Ph.D.
//23 January 2025

data {
    int<lower=1> N;                   // Number of observations
    vector[N] M;                      // Family sizes (Mom model)
    array[N] real D;                  // Outcome variable (Daughter model)
}

parameters {
    real a2;                          // Intercept for Daughter model
    real<lower=0> sigma_D;            // Standard deviation for Daughter model
}

transformed parameters {
    vector[N] mu_D;                   // Daughter model linear predictor

    // Linear predictor (intercept only, no covariate effects)
    mu_D = rep_vector(a2, N);
}

model {
    // Priors
    a2 ~ normal(0, 0.5);
    sigma_D ~ exponential(1);

    // Likelihood for Daughter model
    D ~ normal(mu_D, sigma_D);
}

generated quantities {
    // Prior Predictive Distributions
    vector[N] prior_mu_D;
    vector[N] prior_D;

    for (n in 1:N) {
        prior_mu_D[n] = a2;  // Intercept-only model
        prior_D[n] = normal_rng(prior_mu_D[n], sigma_D);
    }
}
