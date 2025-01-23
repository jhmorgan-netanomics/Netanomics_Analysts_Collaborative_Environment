#Two Moms Example: Simulating Data
#From: https://github.com/rmcelreath/causal_salad_2021/tree/main
#Jonathan H. Morgan
#22 January 2025

#   Activating Local Environment
    cd("/mnt/d/GitHub_Repositories/Netanomics_Analysts_Collaborative_Environment/Workflow_Demonstration")
    using Pkg
    Pkg.activate("julia_env")
    Pkg.status()

################
#   PACKAGES   #
################

using DataFrames
using IJulia
using julia_env

################################################
#   GENERATING DATA & EXPORTING FOR ANALYSIS   #
################################################

#   Generate Data
    sim_data = generate_synthetic_data()

#   Exporting Data to Dataplot for Descriptive Analysis
    sim_df = DataFrame(U = sim_data["U"], M = sim_data["M"], B2 = sim_data["B2"], 
                       B1 = sim_data["B1"], D = sim_data["D"])
   
    cd("Dataplot_functions")
    dataplot_export(sim_df, "two_moms")
    cd("../")

#   Exporting to R to Specify a Probabilistic Model
    cd("R_functions")
    R_export(sim_data, pwd(), "two_moms", "two_moms")
    cd("../")
