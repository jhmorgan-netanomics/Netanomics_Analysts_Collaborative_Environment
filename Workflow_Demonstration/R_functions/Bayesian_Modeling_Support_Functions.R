#Bayesian Modeling Support Functions
#Jonathan H. Morgan, Ph.D.
#22 January 2025

# Helper Functions
  `%notin%` <- Negate(`%in%`)
  
# Dataplot Export Function & Supporting Functions
  dataplot_export <- function(data_frame, data_name) {
    # Add Row ID
      if (!("Obs_ID" %in% colnames(data_frame))) {
        data_frame <- cbind(Obs_ID = 1:nrow(data_frame), data_frame)
      }
    
    # Identify variable types & sort into blocks
      types_list <- sapply(data_frame, class)
    
    # Create sequential IDs for string variables
      string_variables <- colnames(data_frame)[grepl("character", types_list)]
      for (var_name in string_variables) {
        data_frame <- string_to_integer(data_frame, var_name)
      }
      
    # Transform boolean variables to integers
      bool_vars <- colnames(data_frame)[types_list == "logical"]
      if (length(bool_vars) > 0) {
        data_frame[bool_vars] <- lapply(data_frame[bool_vars], as.integer)
      }
    
    # Create index and remove string variables
      types_list <- sapply(data_frame, class)
      col_ids <- seq_along(types_list)
      non_string_cols <- !grepl("character", types_list)
      col_ids <- col_ids[non_string_cols]
      var_names <- colnames(data_frame)[non_string_cols]
    
    # Create export names
      export_names <- gsub(" ", "_", var_names)
      export_names <- mapply(function(name, i) {
        if (nchar(name) > 8) {
          paste0("c_", i)
        } else {
          name
        }
      }, var_names, seq_along(var_names))
      
    # Construct types index
      types_index <- data.frame(
        col_id = col_ids,
        name = var_names,
        export_name = export_names,
        type = sapply(data_frame[, non_string_cols, drop = FALSE], class)
      )
    
    # Isolate string variable key for export
      if (length(string_variables) > 0) {
        string_key <- data_frame[, c(string_variables, paste0(string_variables, "_id")), drop = FALSE]
      } else {
        # If no string variables exist, create an empty data.frame
        string_key <- data.frame()
      }
    
    # Sort types index
      sort_key <- ifelse(tolower(types_index$name) == "obs_id", -1, 
                       as.integer(grepl("id", tolower(types_index$name))))
      types_index <- types_index[order(sort_key, types_index$name, decreasing = FALSE), ]
    
    # Create print elements
      end_command <- "END OF DATA"
      space_element <- "\n"
    
    # Create label commands
      data_labels <- mapply(function(name, export_name) {
        paste("VARIABLE LABEL", name, export_name)
      }, types_index$name, types_index$export_name)
      
    # Specify Dataplot IO settings
      n_rows <- nrow(data_frame)
      n_cols <- ncol(data_frame)
      io_commands <- if (n_cols > 10) {
        c(
          if (n_rows < 1000) "DIMENSION 1000 ROWS" else paste("DIMENSION", n_rows, "ROWS"),
          "MAXIMUM RECORD LENGTH  9999",
          "SET DATA MISSING VALUE missing",
          "SET READ MISSING VALUE 999"
        )
      } else {
        c(
          "MAXIMUM RECORD LENGTH  9999",
          "SET DATA MISSING VALUE missing",
          "SET READ MISSING VALUE 999"
        )
      }
    
    # Build output content as a character vector
      io_elements <- c(io_commands, space_element)
    
    # Initialize output list for data vectors
      output_list <- list()
      for (i in seq_len(nrow(types_index))) {
        # Extracting Types Data
          index_value <- types_index$col_id[i]
          index_name <- types_index$export_name[i]
          data_type <- types_index$type[i]
        
        # Construct data_vector based on type
          data_vector <- if (data_type == "integer") {
            # Format integers
            format_integers_to_string(data_frame[[index_value]], index_name)
          } else if (data_type == "numeric") {
            # Format floating-point numbers
            format_floats_to_string(data_frame[[index_value]], index_name, data_type)
          } else {
            stop(sprintf("Unsupported data type: %s", data_type))
          }
        
        # Store each column's data_vector in the output_list
          output_list[[i]] <- c(data_vector, end_command, space_element)
      }
      output_data <- unlist(output_list)
    
    # Add data labels
      output <- c(io_elements, output_data, data_labels)
    
    # Write the output to a file
      outfile <- paste0("read_", data_name, ".DP")
      file_conn <- file(outfile, "w")
      writeLines(output, file_conn)
      close(file_conn)
    
    # Return string variable key
      return(string_key)
  }
  
  string_to_integer <- function(data_frame, var_name) {
    column_data <- data_frame[[var_name]]
    unique_values <- unique(column_data[!is.na(column_data)])
    value_to_id <- setNames(seq_along(unique_values), unique_values)
    id_column <- ifelse(is.na(column_data), 0, value_to_id[column_data])
    data_frame[[paste0(var_name, "_id")]] <- id_column
    return(data_frame)
  }
  
  format_integers_to_string <- function(variable, var_name) {
    # Convert integers to strings without scientific notation
      s_variable <- sprintf("%d", variable)
    
    # Determine the maximum width for padding
      width <- max(nchar(s_variable))
    
    # Pad strings to uniform length
      padded_s_variable <- sapply(s_variable, function(x) {
        padding_needed <- width - nchar(x)
        if (padding_needed > 0) {
          paste0(strrep("0", padding_needed), x)
        } else {
          x
        }
      })
    
    # Prepare Dataplot commands
      set_command <- sprintf("SET READ FORMAT 1F%d.0", width)
      read_command <- sprintf("READ %s", var_name)
    
    # Return a plain character vector
      return(c(set_command, read_command, padded_s_variable))
  }
  
  format_floats_to_string <- function(variable, var_name, col_type) {
    # Determine precision and width
      precision <- if (col_type == "numeric") 14 else 16
    
    # Format numeric values to strings with the specified precision
      formatted_str <- sprintf(paste0("%.", precision, "f"), variable)
    
    # Split into whole and decimal parts
      parts <- strsplit(formatted_str, "\\.", fixed = FALSE)
      whole_parts <- sapply(parts, `[`, 1) # Extract whole number part
      decimal_parts <- sapply(parts, `[`, 2, USE.NAMES = FALSE) # Extract decimal part
      
    # Determine maximum width for padding
      max_whole_width <- max(nchar(whole_parts))
      max_decimal_places <- precision # Fixed based on the desired precision
    
    # Pad whole parts with leading zeros
      padded_whole_parts <- sprintf(paste0("%0", max_whole_width, "d"), as.numeric(whole_parts))
    
    # Pad decimal parts with trailing zeros
      padded_decimal_parts <- sprintf(paste0("%-", max_decimal_places, "s"), decimal_parts)
      padded_decimal_parts <- gsub(" ", "0", padded_decimal_parts) # Replace spaces with zeros
    
    # Combine whole and decimal parts into a single string
      padded_floats <- paste0(padded_whole_parts, ".", padded_decimal_parts)
    
    # Prepare Dataplot commands
      total_width <- max_whole_width + 1 + max_decimal_places # +1 for the decimal point
      set_command <- sprintf("SET READ FORMAT 1F%d.%d", total_width, max_decimal_places)
      read_command <- sprintf("READ %s", var_name)
      
    # Return a plain character vector
      return(c(set_command, read_command, padded_floats))
  }
  
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

# Shrinkage Checks
  shrinkage_check <- function(draws_df, observed_values, prior_term, post_term, iterations=1000){
    # Isolating Prior Predictive Values
      y_prior_df <- draws_df[,grepl(prior_term, colnames(draws_df))] 
    
    # Sample one value from each column in each iteration of the Prior Predictive Distribution
      set.seed(123) # For reproducibility
      prior_density_list <- vector('list', iterations)
      for (i in seq_along(prior_density_list)){
        prior_density_list[[i]] <-  density(apply(y_prior_df, 2, function(col) sample(col, 1)))
      }
    
    # Isolating Posterior for y
      y_pred_df <- draws_df[,grepl(post_term, colnames(draws_df))] 
    
    # Number of iterations and columns
      posterior_density_list <- vector('list', iterations)
      for (i in seq_along(posterior_density_list)){
        posterior_density_list[[i]] <-  density(apply(y_pred_df, 2, function(col) sample(col, 1)))
      }
      
    # Scaling the y axes of the Prior & Posterior Distributions to be betwwen 0 and 1
      prior_density_list <- lapply(prior_density_list, function(d) {
        d$y <- d$y / max(d$y)  
        d  
      })
      
      posterior_density_list <- lapply(posterior_density_list, function(d) {
        d$y <- d$y / max(d$y)  
        d  
      })
    
    # Constraining Values to Fall within the Observed Minimum and Maximum
      prior_max_x <- max(unlist(lapply(prior_density_list, function(d) max(d$x))))
      posterior_max_x <- max(unlist(lapply(posterior_density_list, function(d) max(d$x))))
      max_x <- max(c(prior_max_x,  posterior_max_x))
      
      prior_min_x <- min(unlist(lapply(prior_density_list, function(d) min(d$x))))
      posterior_min_x <- min(unlist(lapply(posterior_density_list, function(d) min(d$x))))
      min_x <- min(c(prior_min_x, posterior_min_x))
    
    # Plotting the Two Distributions
      x_axis <- pretty(c(min_x, max_x))
    
    # Layout Matrix
      layout.matrix <- matrix(c(1, 2), nrow = 2, ncol = 1)
      par(mfrow = c(1, 1)) 
      layout(mat = layout.matrix, heights = c(2, 0.25))
    
    # Creating Base Plot
      plot(0, type='n', xlab='Values', ylab='Density', xlim=c(min(x_axis), max(x_axis)), ylim=c(0,1) ,cex.axis=1, 
           las=1, main=' ', tck=0.015, xaxt='n', bty='L')
      grid(nx = NA, ny = NULL, col = "gray", lty = "dotted")
      
      axis(1, padj=0.75, tck=0.015) 
      dataplot_tick_function(0.015, 0.40)
    
    # Plotting Densities
      for (i in seq_along(prior_density_list)){
        lines(prior_density_list[[i]], col=rgb(119/255,136/255,153/255))
      }
      
      for (i in seq_along(posterior_density_list)){
        lines(posterior_density_list[[i]], col="brown")
      }
      
    # Adding Title
      title("Model Checks", family='serif', cex.main=1.5, line=0.2)
    
    # Adding Legend
      par(mar = c(0, 0, 0, 0))
      plot.new()
      
    # Adding Line & Annotations
      y_pos <- 0.5
      x1_start <- 0.1
      x1_end <- 0.15
      segments(x1_start, y_pos, x1_end, y_pos, col = rgb(119/255,136/255,153/255))
      text(x1_end + 0.005, y_pos, 'Prior Predictive Dist.', pos=4)
      
      x1_start <- 0.6
      x1_end <- 0.65
      segments(x1_start, y_pos, x1_end, y_pos, col = 'brown')
      text(x1_end + 0.005, y_pos, 'Post. Predictive Dist.', pos=4)
    
    # Recording Plot
      shrinkage_plot <- recordPlot()
    
    # Return Plot
      return(shrinkage_plot)
    
    # Return to Normal Layout
      par(mfrow = c(1, 1))
  }

# Fit Plot Density Function
  fit_check_density <- function(predictions, x_label, observed_values, plot_title, iterations=1000){
    # Layout Matrix
      layout.matrix <- matrix(c(1, 2), nrow = 2, ncol = 1)
      par(mfrow = c(1, 1)) 
      layout(mat = layout.matrix, heights = c(2, 0.25))
    
   #  Generating the Sample Densities
      posterior_density_list <- vector('list', iterations)
      for (i in seq_along(posterior_density_list)){
        posterior_density_list[[i]] <-  density(apply(predictions, 2, function(col) sample(col, 1)))
      }
    
    # Standardizing the y-axis for Comparison
      posterior_density_list <- lapply(posterior_density_list, function(d) {
        d$y <- d$y / max(d$y)  
        d  
      })
    
    # Creating Joint Axis
      posterior_max_x <- max(unlist(lapply(posterior_density_list, function(d) max(d$x))))
      posterior_min_x <- max(unlist(lapply(posterior_density_list, function(d) min(d$x))))
      x_axis <- pretty(c(posterior_min_x, posterior_max_x))
    
    # Create Empty Plot
      plot(NA, xlim = range(x_axis), ylim = c(0,1.05), 
           xlab='', ylab=' ', las=1, main=' ', tck=0.025, 
           bty='L', cex.axis=1.1, xaxt='n')
      
      grid(lwd = 2)
      axis(1, padj=0.75, tck=0.015) 
      dataplot_tick_function(0.015, 0.40)
    
    # Adding Axis Labels
      mtext(side = 1, text=x_label, line = 3.5, cex = 1.3)
      mtext(side = 2, text='Density', 2.5, cex = 1.3)
    
    # Plotting Predictive Posterior Distribution
      for (i in seq_along(posterior_density_list)){
        lines(posterior_density_list[[i]], col=rgb(187/255, 187/255, 187/255))
      }
    
    # Plotting Observations 
      observed_density <- density(observed_values)
      x <- observed_density$x
      y <- observed_density$y
      y <- y/max(y)
      lines(x, y, col="blue")  
    
    # Adding Title
      title(plot_title, family='serif', cex.main=1.5, line=1.25)
    
    # Adding Legend
      par(mar = c(0, 0, 0, 0))
      plot.new()
    
    # Adding Line & Annotations
      y_pos <- 0.5
      x1_start <- 0.10
      x1_end <- 0.15
      segments(x1_start, y_pos, x1_end, y_pos, col = 'blue')
      text(x1_end + 0.005, y_pos, 'Observed', pos=4)
    
      x1_start <- 0.7
      x1_end <- 0.75
      segments(x1_start, y_pos, x1_end, y_pos, col = rgb(187/255, 187/255, 187/255))
      text(x1_end + 0.005, y_pos, 'Predictions', pos=4)
    
    # Recording Plot
      fit_density <- recordPlot()
    
    # Return Plot
      return(fit_density)
    
    # Return to Normal Layout
      par(mfrow = c(1, 1))
  }

# Posterior Distribution with a HDPI
  posterior_plot <- function(delta_values, plot_titles, x_label, hdpi_setting){
    # Specifying Layout Matrix
      layout.matrix <- matrix(c(1), nrow = 1, ncol = 1)
      layout(mat = layout.matrix) # Widths of the two columns
      # layout.show(n=4)
      
    # Looping through each emotion
      for (i in seq_along(plot_titles)){
        # Calculating the Mean & HPDI
          hpdi <- HPDI(delta_values[[i]], hdpi_setting)
          lower_hpdi <- hpdi[[1]]
          upper_hpdi <- hpdi[[2]]
         
          posterior_mean <- mean(delta_values[[i]])
          
        # Generating the Density
          delta_density <- density(delta_values[[i]])
          x_axis <- delta_density$x
          y_axis <- delta_density$y
          y_axis <- y_axis/max(y_axis)
          
          within_hpdi <- x_axis >= lower_hpdi & x_axis <= upper_hpdi
          
        # Creating Base Plot
          par(mar=c(5,5.5,4,2))
          plot(NA, xlim = range(x_axis), ylim = range(y_axis), 
               xlab='', ylab=' ', las=1, main=' ', tck=0.025, 
               bty='L', cex.axis=1.1, xaxt='n')
          
          grid(nx = NA, ny = NULL, col = "gray", lty = "dotted")
          axis(1, padj=0.75, tck=0.015) 
          dataplot_tick_function(0.015, 0.40)
          
        # Adding Axis Labels
          mtext(side = 1, text= x_label, line = 3.5, cex = 1)
          mtext(side = 2, text='Density', 2.5, cex = 1)
          
        # Plotting Predictive Posterior Distribution
          lines(x_axis, y_axis, col='black')
          
        # Shade the HPDI region
          polygon(
            c(x_axis[within_hpdi], rev(x_axis[within_hpdi])),      # X-coordinates for the shaded region
            c(y_axis[within_hpdi], rep(0, sum(within_hpdi))),      # Y-coordinates (closing to zero at the edges)
            col = rgb(187/255, 187/255, 187/255, alpha = 0.25),                 # Adjust color and transparency
            border = NA
          )
          
        # Adding Reference Line
          abline(v=0,col='brown',lwd=2, lty=2)
          
        # Adding Title
          title(plot_titles[[i]], family='serif', cex.main=1.5, line=1.25)
      }
      
    # Recording Plot
      difference_plot <- recordPlot()
      
    # Return Plot
      return(difference_plot )
      
    # Return to Normal Layout
      par(mfrow = c(1, 1))
  }
  