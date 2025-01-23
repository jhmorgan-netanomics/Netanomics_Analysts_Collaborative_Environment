#Bayesian Modeling Support Functions
#Jonathan H. Morgan, Ph.D.
#22 January 2025

# Helper Functions
  `%notin%` <- Negate(`%in%`)
  
# Highest Density Posterior Interval (HDPI) function in R
  HPDI <- function(x, alpha = 0.11) {
    n <- length(x)
    m <- max(1, ceiling(alpha * n))
    
    y <- sort(x)
    a <- y[1:m]
    b <- y[(n - m + 1):n]
    i <- which.min(b - a)
    
    return(c(a[i], b[i]))
  }
  
# Plotting Function
  dataplot_tick_function <- function(major_tick_length=0.035, minor_tick_ratio=0.25){
    # Check if Hmisc is Present. If not, install it.
      packages <- c('Hmisc')
      install.packages(setdiff(packages, rownames(installed.packages()))) 
    
    # Add Dataplot Style- Through Tick Marks to Plot
      Hmisc::minor.tick(nx = 2, ny = 2, tick.ratio = minor_tick_ratio)  
      Hmisc::minor.tick(nx = 2, ny = 2, tick.ratio = -minor_tick_ratio)  
      axis(2, tck=1, tck=-major_tick_length, labels = FALSE)
      axis(1, tck=1, tck=-major_tick_length, labels = FALSE)
  }
  
# Calculate the Standard Error
  std <- function(x) sd(x)/sqrt(length(x))
  
# Function to Evaluate Posteriors of Covariates whose HDPI Crosses Zero
  posterior_check <- function(data, draws_df){
    # Isolate the Covariate Distributions
      covariate_df <- draws_df[, grepl("beta", colnames(draws_df)), drop = FALSE]
      beta_names <-names(covariate_df)
    
    # Renaming them for Clarity
      colnames(covariate_df) <- colnames(data$X)
    
    # Calculating the HDPI for each Covariate
      hdpi_results <- apply(covariate_df, 2, HPDI)
      hdpi_results <- data.frame(beta = beta_names, lower_limit = hdpi_results[1,], upper_limit = hdpi_results[2,])
      
    # Checking if Any Cross Zero
      hdpi_results$check <- hdpi_results$lower_limit * hdpi_results$upper_limit
    
    # Isolate Crossing Covariates
      crossing_covariates <- hdpi_results[(hdpi_results$check < 0),]
    
    # Plot if there are Zero Crossing Covariates
      if(nrow(crossing_covariates) > 0){
        # Create Plot List
          plots_list <- vector('list', nrow(crossing_covariates))
          names(plots_list) <- row.names(crossing_covariates)
          
        # Isolate Crossing Covariates from Posterior List
          crossing_list <- posterior_list[names(posterior_list) %in% crossing_covariates$beta]
        
        # Generating Color Pallette
          colors <- color_scheme_get("mix-blue-red")[c(1:4)]
        
        # Creating Posterior Plots
          for (i in seq_along(crossing_list)){
            # Base Plot Attributes
              var_den <- density(unlist(crossing_list[[i]]))
              y_axis <- c(pretty(var_den$y), max(pretty(var_den$y)) + (max(pretty(var_den$y))/length(pretty(var_den$y))))
              x_values <- pretty(var_den$x)
              
            # Plotting Base Plot
              plot(0, type='n', xlab='Values', ylab='Density', xlim=c(min(x_values), max(x_values)), ylim=c(min(y_axis), max(y_axis)) ,cex.axis=1, 
                   las=1, main=' ', tck=0.015, xaxt='n', bty='L')
              grid(lwd = 2, col = "gray", lty = "dotted")
              
              axis(1, padj=0.75, tck=0.015) 
              dataplot_tick_function(0.015, 0.40)
              
            # Plotting Densities
              for (j in 1:length(crossing_list[[i]])) {
                lines(x=density(crossing_list[[i]][[j]])$x, y=density(crossing_list[[i]][[j]])$y, col=colors[[j]])
              }
            
            # Adding Title
              title(row.names(crossing_covariates)[[i]]  , family='serif', cex.main=1.5, line=1.25)
            
            # Adding Zero Reference Line
              abline(v=0,col='brown',lwd=2, lty=2)
            
            # Adding Legend
              legend("topright", legend=c("Chain 1", "Chain 2", "Chain 3", "Chain 4"), col=c(colors[[1]], colors[[2]], colors[[3]], colors[[4]]), 
                     lty=1:1, cex=0.95, bty='n')
            
            # Recording Plot
              plots_list[[i]] <- recordPlot()
          }
          
        # Returning Plots List
          return(plots_list)
      }else{
        # Print Status
          print("There Are No Covariates that Cross Zero")
      }
    }  
  
# Chains & Density Visualizations
  chains_visualization <- function(parameter, input_data){
    # Defining Meta Data
      parameter_name <- rlang::parse_expr(parameter)
      y_axis <- pretty(unlist(input_data))
      x_values <- seq(1, length(input_data[[1]]), 1)
      colors <- color_scheme_get("mix-blue-red")[c(1:4)]
    
    # Creating Base Plot
      plot(NA, xlim = c(0, 2000), ylim = c(min(y_axis), max(y_axis)), 
           xlab='Iteration', ylab='Value', las=1, main=' ', tck=0.025, 
           bty='L', cex.axis=1.1, xaxt='n')
      
      grid(lwd = 2)
      axis(1, padj=0.75, tck=0.015) 
      dataplot_tick_function(0.015, 0.40)
    
    # Plotting LInes
      for (i in 1:length(input_data)) {
        lines(x=x_values, y=input_data[[i]], col=colors[[i]])
      }
    
    # Adding Title
      title(parameter_name, family='serif', cex.main=1.35, line=0.2)
  }
  
  density_visualization <- function(parameter, input_data){
    # Defining Meta Data
      parameter_name <- rlang::parse_expr(parameter)
      colors <- color_scheme_get("mix-blue-red")[c(1:4)]
      
      var_den <- density(unlist(input_data))
      y_axis <- c(pretty(var_den$y), max(pretty(var_den$y)) + (max(pretty(var_den$y))/length(pretty(var_den$y))))
      x_values <- pretty(var_den$x)
      
    # Creating Base Plot
      plot(NA, xlim = c(min(x_values), max(x_values)), ylim = c(min(y_axis), max(y_axis)), 
           xlab='Value', ylab='Density', las=1, main=' ', tck=0.025, 
           bty='L', cex.axis=1.1, xaxt='n')
      
      grid(lwd = 2)
      axis(1, padj=0.75, tck=0.015) 
      dataplot_tick_function(0.015, 0.40)
    
    # Plotting Densities
      for (i in 1:length(input_data)) {
        lines(x=density(input_data[[i]])$x, y=density(input_data[[i]])$y, col=colors[[i]])
      }
      abline(v=0,col='brown',lwd=2, lty=2)
    
    # Adding Title
      title(parameter_name, family='serif', cex.main=1.35, line=0.2)
    
    # Adding Legend
    # legend("topright", legend=c("Chain 1", "Chain 2", "Chain 3", "Chain 4"), col=
    #        c(colors[[1]], colors[[2]], colors[[3]], colors[[4]]), lty=1:1, cex=1.3, bty='n')
  }
  