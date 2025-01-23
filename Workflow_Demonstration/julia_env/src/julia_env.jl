module julia_env
#   Packages
    using Pkg                   #Necessary for Package Support Funtions
    using Chain                 #Used for Piping Commands
    using CSV                   #Used to Import and Export CSV Files
    using Combinatorics         #Used to Estimate the Edge Weights of Communities Corrected for Volume
    using DataFrames            #Generates Julia Style DataFrames and DataFrame Manipulation
    using Distributions         #Used to generate Synthetic Data Using the Bernoulli Distribution
    using Random                #Used to generate Random Seed Value
    using Statistics            #Used for basic statistical operations
    using Printf                #Used in the Dataplot Export Function to deal with large Integer and Float Strings
    using RCall                 #Used here to Pull-In R Files
    using PyCall                #Used to facilitate movement of data in the meta-kernel notebook
    

#   SUPPORT FUNCTIONS

#   Checking Package Dependencies
#   Created by Bogumił Kamiński
#   27 February 2021
    get_pkg_status(;direct::Bool=true) = @chain Pkg.dependencies() begin
        values
        DataFrame
        direct ? _[_.is_direct_dep, :] : _
        select(:name, :version,
        [:is_tracking_path, :is_tracking_repo, :is_tracking_registry] =>
        ByRow((a, b, c) -> ["path", "repo", "registry"][a+2b+3c]) =>
        :tracking)
    end

#   DataFrame Summary Function that Imitates Julia's Default Behavior on Jupyter Notebooks
    function summarize_df(df::DataFrame; n::Int64=5, num_cols::Int64=ncol(df))
        #   Printing Meta-Data
            total_rows, total_cols = size(df)
            bottom_start = total_rows - n + 1
            println("$total_rows×$total_cols DataFrame")

        #   Indices for first and last `n` rows
            top_rows = df[1:n, :]
            bottom_rows = df[bottom_start:total_rows, :]

        #   Create a placeholder row
            placeholder = DataFrame([name => [nothing] for name in names(df)]...)

        #   Concatenate rows with placeholder
            display_df = vcat(top_rows, placeholder, bottom_rows)
            insertcols!(display_df, 1, :Row => vcat(1:n, nothing, bottom_start:total_rows))

        #   Create Custom Headers
            insertcols!(top_rows, 1, :Row => 1:n)
            header_names = names(top_rows)
            header_types = [string(eltype(top_rows[!, name])) for name in header_names]
            header_types[1] = ""  # Row index column does not need a type

        #   Display Table
            show(display_df[:,(1:num_cols)], show_row_number=false, allcols=true, 
                 header=(header_names[1:num_cols], header_types[1:num_cols]), summary=false)
    end

#   Dataplot Export File
    function dataplot_export(data_frame::DataFrame, data_name::String)
        #   Add Row ID
            if !("Obs_ID" in names(data_frame))
                DataFrames.insertcols!(data_frame, 1, :Obs_ID => 1:nrow(data_frame))
            end

        #   Identifying Variable Types & Sort into Blocks
            types_list = string.(eltype.(eachcol(data_frame)))

        #   Create Sequential IDs for String Variables
            string_variables = names(data_frame)[occursin.("String", types_list)]
            string_vars = string_variables isa Symbol ? [string_variables] : string_variables
            for var_name in string_vars
                data_frame = string_to_integer(data_frame, String(var_name))
            end

        #   Transform Boolean Variables to Integers 
            types_list = string.(eltype.(eachcol(data_frame)))
            data_frame[!, names(data_frame)[(types_list .== "Bool")]] = Int.(data_frame[!, names(data_frame)[(types_list .== "Bool")]])

        #   Creating Index & Eliminating String Variables from the Index as these Will Not be Exported
            types_list = string.(eltype.(eachcol(data_frame)))
            col_ids = [1: 1: length(types_list);]
            col_ids = col_ids[(occursin.("String", types_list) .== 0)]
            var_names = names(data_frame)[(occursin.("String", types_list) .== 0)]

        #   Creating Export Names
            export_names = replace.(var_names, " " => "_")
            for i in eachindex(export_names)
                if (length(var_names[i]) <= 8)
                    export_names[i] = export_names[i]
                else
                    export_names[i] = string("c_", i)
                end
            end

        #   Constructing Types Index
            types_list = types_list[(occursin.("String", types_list) .== 0)]
            types_index = DataFrame(col_id = col_ids, name = var_names, export_name = export_names,  type=[eval(Symbol(t)) for t in types_list]) 

        #   Isolating String Variable Key for Export
            string_key = data_frame[:, [string_vars; string.(string_vars,"_id")]]

        #   Sorting Types Index
            sort_key = [occursin("id", lowercase(name)) ? 0 : 1 for name in types_index.name]
            types_index[!, :sort_key] = sort_key
            types_index = DataFrames.sort(types_index, [:sort_key], rev=false)
            select!(types_index, Not(:sort_key))

        #   Create print elements
            end_command = string("END OF DATA")
            space_element = "\n"

        #   Create label commands
            data_labels = Vector{String}(undef, size(types_index)[1])
            for i in eachindex(data_labels)
                data_labels[i] = string("VARIABLE LABEL", " ", types_index.name[i], " ", types_index.export_name[i])
            end

        #   Specifying Dataplot IO Settings
            io_commands = Vector{String}(undef, 4)
            if (size(data_frame)[2] > 10)
                if (size(data_frame)[1] < 1000 )
                    io_commands[1] = string("DIMENSION", " ","1000", " ", "ROWS")
                else
                    io_commands[1] = string("DIMENSION", " ", size(data_frame)[1], " ", "ROWS")
                end
            
                io_commands[2] = "MAXIMUM RECORD LENGTH  9999"
                io_commands[3] = "SET DATA MISSING VALUE missing"
                io_commands[4] = "SET READ MISSING VALUE 999"
            else
                io_commands[1] = "MAXIMUM RECORD LENGTH  9999"
                io_commands[2] = "SET DATA MISSING VALUE missing"
                io_commands[3] = "SET READ MISSING VALUE 999"
                io_commands = io_commands[1:3]
            end

        #   Writing-Out Data
            outfile = string("read_",data_name, ".DP")
            open(outfile, "w") do f
                #   Write IO Commands
                    write(f, join(io_commands, "\n"))

                #   Adding spacer
                    println(f, space_element)

                #   Writing-Out Variables
                    for i in eachindex(types_index.col_id)
                        #   Determining Type
                            data_type = types_index[i,4]
                            index_value = types_index[i,"col_id"]
                            index_name = types_index[i,"export_name"]

                        #   Outputing Vector of Values
                            if(data_type == Int64 || data_type == BigInt)
                                data_vector = format_integers_to_string(data_frame[:,index_value], index_name)
                            else
                                data_vector = format_floats_to_string(data_frame[:,index_value], index_name, data_type)
                            end
                            data_vector = [data_vector; end_command; space_element]

                        #   Writing-Out Data Elements
                            write(f, join(data_vector, "\n"))    
                    end

                #   Writing-Out Label Commands
                    write(f, join(data_labels, "\n"))
            end
        
        #   Return String Variable Key
            return string_key

    end

#   Support Functions  
    function string_to_integer(data_frame::DataFrame, var_name::String)
        #   Extract the column as an array to work with missing values properly
            column_data = data_frame[!, var_name]

        #   Create a unique mapping for non-missing values
            unique_values = unique(filter(x -> !ismissing(x), column_data))
            value_to_id = Dict(value => id for (id, value) in enumerate(unique_values))

        #   Initialize the ID column with 0 for all entries
            id_column = zeros(Int, length(column_data))  # Use Int type and initialize as zeros

        #   Fill the ID column for non-missing values in column_data
            for i in eachindex(column_data)
                if !ismissing(column_data[i])
                    id_column[i] = value_to_id[column_data[i]]
                end
                # No need to explicitly handle missing values here; they're already accounted for by initializing id_column with zeros
            end

        #   Add the ID column to the DataFrame
            id_col_name = Symbol(string(var_name, "_id"))
            data_frame[!, id_col_name] = id_column

        #   Return Adjusted DataFrame
            return data_frame
    end

    function format_integers_to_string(variable::Vector{Int64}, var_name::String)
        #   Direct conversion to string without scientific notation
            s_variable = [@sprintf("%d", v) for v in variable]

        #   Pad strings to uniform length
            width = maximum(length.(s_variable))
            padded_s_variable = Vector{String}(undef, length(s_variable))
        
            for j in eachindex(s_variable)
                #   Determine if padding is needed
                    padding_needed = width - length(s_variable[j])
        
                #   Adding Padding
                    if padding_needed > 0
                        padding = "0" ^ padding_needed
                        if variable[j] < 0
                            #Insert padding after the negative sign
                            padded_s_variable[j] = s_variable[j][1] * padding * s_variable[j][2:end]
                        else
                            padded_s_variable[j] = padding * s_variable[j]
                        end
                    else
                        padded_s_variable[j] = s_variable[j]
                    end
            end

        #   Adding Commands
            set_command = "SET READ FORMAT 1F$(width).0"
            read_command = "READ $var_name"
            commands = [set_command; read_command]

        #   Returning Formatting String Vector
            return vcat(commands, padded_s_variable)
    end

    function format_integers_to_string(variable::Vector{BigInt}, var_name::String)
        #   Direct conversion to string without scientific notation
            s_variable = [@sprintf("%d", v) for v in variable]

        #   Pad strings to uniform length
            width = maximum(length.(s_variable))
            padded_s_variable = Vector{String}(undef, length(s_variable))
        
            for j in eachindex(s_variable)
                #   Determine if padding is needed
                    padding_needed = width - length(s_variable[j])
        
                #   Adding Padding
                    if padding_needed > 0
                        padding = "0" ^ padding_needed
                        if variable[j] < 0
                            #Insert padding after the negative sign
                            padded_s_variable[j] = s_variable[j][1] * padding * s_variable[j][2:end]
                        else
                            padded_s_variable[j] = padding * s_variable[j]
                        end
                    else
                        padded_s_variable[j] = s_variable[j]
                    end
            end

        #   Adding Commands
            set_command = "SET READ FORMAT 1F$(width).0"
            read_command = "READ $var_name"
            commands = [set_command; read_command]

        #   Returning Formatting String Vector
            return vcat(commands, padded_s_variable)
    end

    function format_floats_to_string(variable::Vector, var_name::String, col_type::Type)
        #   Determine precision
            local_precision = col_type == Float64 ? 14 : precision(BigFloat)  # Adjust for BigFloat if needed

        #   Convert to string with specified precision
            formatted_str = if col_type == Float64
                [@sprintf("%.*f", local_precision, v) for v in variable]
            else
                [string(v) for v in variable]
            end

        #   Adjust trimming logic to preserve '.0' for purely zero values
            s_variable = map(v -> begin
                    clean_v = replace(v, "f" => "")  # Clean format specifier if any
                    trimmed_v = rstrip(clean_v, '0')
                    if endswith(trimmed_v, '.')
                        trimmed_v = trimmed_v * "0"
                    else
                        trimmed_v = trimmed_v * ".0"
                    end
                    trimmed_v
                end, formatted_str)

        #   Split into whole and decimal parts, handling negative numbers
            parts = split.(s_variable, '.', keepempty=true)
            whole_parts = getindex.(parts, 1)
            decimal_parts = getindex.(parts, 2)

        #   Extract sign and magnitude for whole parts
            signs = [startswith(wp, "-") ? "-" : "" for wp in whole_parts]
            magnitudes = replace.(whole_parts, "-" => "")

        #   Calculate padding requirements
            max_whole_magnitude_width = maximum(length.(magnitudes))
            max_decimal_places = maximum([length(dp) for dp in decimal_parts])

        #   Apply padding to magnitudes and reassemble whole parts with signs
            padded_magnitudes = lpad.(magnitudes, max_whole_magnitude_width, '0')
            whole_parts_padded = [sign * mag for (sign, mag) in zip(signs, padded_magnitudes)]

        #   Apply padding to decimal parts
            decimal_parts_padded = rpad.(decimal_parts, max_decimal_places, '0')

        #   Reassemble numbers
            s_variable = [whole * (dp != "" ? "." * dp : "") for (whole, dp) in zip(whole_parts_padded, decimal_parts_padded)]

        #   Prepare Dataplot commands
            total_width = max_whole_magnitude_width + (max_decimal_places > 0 ? max_decimal_places + 1 : 0) + 1 # +1 for potential '-' sign
            set_command = "SET READ FORMAT 1F$total_width.$max_decimal_places"
            read_command = "READ $var_name"

        #   Return String
            return vcat([set_command; read_command], s_variable)
    end

#   Define a function to check if a string represents zero
    function is_zero_string(str::String)
        #   A regex to match zero, possibly with a negative sign and decimal zeros
            return occursin(r"^-?0\.?0*$", str)
    end

#   R Export
    function R_export(data_object::Union{DataFrame, Dict}, R_directory::String, file_name::String, save_name::String)
        """
        Export a Julia object (DataFrame or Dictionary) to R and save it as an .Rda file.

        # Arguments
        - `data_object`: The Julia object being exported to R. Accepts `DataFrame` or `Dict`.
        - `R_directory`: The directory where the converted Julia object will be saved.
        - `file_name`: The alias for the object in R (simpler name for R environment).
        - `save_name`: The name for the .Rda file to be saved.

        # Notes
        - If the object is a `DataFrame`, it is passed as a data frame to R.
        - If the object is a `Dict`, it is passed as a list to R without conversion.
        """

        if isa(data_object, DataFrame)
            #   Process DataFrame columns for compatibility
                var_names = names(data_object)
                for i in eachindex(var_names)
                    #   Convert Int64 ID columns to String
                        if occursin("ID", var_names[i]) && eltype(data_object[:, i]) == Int64
                            data_object[!, i] = string.(data_object[:, i])
                        elseif eltype(data_object[:, i]) == Int64
                            # Clamp and convert Int64 to Int32
                            data_object[!, i] = Int32.(clamp.(data_object[:, i], typemin(Int32), typemax(Int32)))
                        end
                end

            #   Export modified DataFrame to R
                @rput data_object
        elseif isa(data_object, Dict)
            #   Directly export Dict as an R list
                @rput data_object
        else
            error("Unsupported data object type. Only DataFrame or Dict are accepted.")
        end

        #   Create the full path with the .Rda extension
            r_save_name = joinpath(R_directory, string(save_name, ".Rda"))

        #   Save the object in R environment as an .Rda file
            R"""
            setwd($R_directory)
            assign(x = $(file_name), value = data_object, envir = .GlobalEnv)
            save(list=$(file_name), file = $(r_save_name))
            """
    end

#   ANALYSIS FUNCTIONS

#   Creating Two Moms' Synthetic Data
    function generate_synthetic_data(seed::Int = 1908, N::Int = 200)
        """
        Generate synthetic data based on Richard McElreath's "Two Moms" example.

        # Arguments
        - `seed::Int`: Random seed for reproducibility. Default is `1908`.
        - `N::Int`: Number of data points (pairs) to generate. Default is `200`.

        # Returns
        A `Dict` containing the following keys:
        - `"U"`: Array of confounders (length `N`), drawn from a standard normal distribution.
        - `"B1"`: Array of binary values representing first-born status (0 or 1), drawn from a Bernoulli(0.5) distribution.
        - `"M"`: Array of Moms' family sizes, influenced by birth order and confounders.
        - `"B2"`: Array of binary values representing the birth order of the second sibling (0 or 1), drawn from a Bernoulli(0.5) distribution.
        - `"D"`: Array of Daughters' outcomes, influenced by the second sibling's birth order, confounders, and family size.
        """
        #   Set random seed
            Random.seed!(seed)

        #   Simulate confounds
            U = randn(N)

        #   Generate birth orders and family sizes
            B1 = Int.(rand(Bernoulli(0.5), N))               # 50% first-borns
            M = [rand(Normal(2 * B1[i] + U[i], 1)) for i in 1:N]  # Mothers' family sizes

            B2 = Int.(rand(Bernoulli(0.5), N))               # Birth order of second sibling
            D = [rand(Normal(2 * B2[i] + U[i] + 0 * M[i], 1)) for i in 1:N]  # Daughters' outcomes

        #   Return as dictionary
            return Dict("U" => U, "B1" => B1, "M" => M, "B2" => B2, "D" => D)
    end

#   Exporting Objects
    export  get_pkg_status,
            summarize_df,
            dataplot_export,
            R_export,
            generate_synthetic_data
end # module julia_env
