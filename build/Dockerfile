# Netanomics Common Collaborative Analysts' Environment
# Jonathan H. Morgan, Ph.D.
# 14 December 2024
# Use the official Ubuntu base image
FROM ubuntu:22.04

# Set environment variable to non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------------------
# 1. Install Dependencies
# ----------------------------------------
RUN apt-get update && \
    echo "tzdata tzdata/Areas select America" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/America select New_York" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wget \
        curl \
        build-essential \
        gcc \
        gfortran \
        libx11-dev \
        libxft-dev \
        libgd-dev \
        libtiff-dev \
        libcairo2 \
        libcairo2-dev \
        libreadline-dev \
        xclip \
        plotutils \
        libplot-dev \
        xvfb \
        ghostscript \
        libssl-dev \
        libxml2-dev \
        libcurl4-openssl-dev \
        libgit2-dev \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libfreetype6-dev \
        net-tools \
        openbox \
        python3-tk \
        pkg-config \
        unzip \
        git && \
    apt-get clean

# Set PKG_CONFIG_PATH to ensure pkg-config finds the libraries
ENV PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig"

# ----------------------------------------
# 2. Add System Fonts & Configure Locales
# ----------------------------------------

# Create a directory for custom fonts
RUN mkdir -p /usr/share/fonts/truetype/custom

# Fetch fonts from your GitHub repository and place them in the custom fonts directory
RUN curl -L -o /tmp/fonts.zip https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment/archive/refs/heads/main.zip \
    && unzip /tmp/fonts.zip 'Netanomics_Analysts_Collaborative_Environment-main/tools/fonts/*' -d /tmp/ \
    && mkdir -p /usr/share/fonts/truetype/custom/ \
    && cp /tmp/Netanomics_Analysts_Collaborative_Environment-main/tools/fonts/* /usr/share/fonts/truetype/custom/ \
    && fc-cache -fv \
    && rm -rf /tmp/fonts.zip /tmp/Netanomics_Analysts_Collaborative_Environment-main

# Configure locales
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Set environment variables for the locales
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Clean up to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/fonts.zip /tmp/Netanomics_Analysts_Collaborative_Environment-main

# ----------------------------------------
# 3. Install Dataplot
# ----------------------------------------

WORKDIR /tmp/nist_dataplot
RUN git clone https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment.git /tmp/nist_dataplot

WORKDIR /tmp/nist_dataplot/tools/dataplot/src
RUN make clean && make && make install

# Rename the original Dataplot binary
RUN mv /usr/local/bin/dataplot /usr/local/bin/dataplot-original

# Wrapper Script for Dataplot
RUN echo '#!/bin/bash\n\
if [ -z "$DISPLAY" ]; then\n\
    echo "No DISPLAY found. Falling back to xvfb-run..."\n\
    xvfb-run -a /usr/local/bin/dataplot-original "$@"\n\
else\n\
    /usr/local/bin/dataplot-original "$@"\n\
fi' > /usr/local/bin/dataplot-wrapper.sh && \
    chmod +x /usr/local/bin/dataplot-wrapper.sh

# Symlink for convenience
RUN ln -s /usr/local/bin/dataplot-wrapper.sh /usr/local/bin/dataplot

# ----------------------------------------
# 4. Install the Latest Version of Julia
# ----------------------------------------

# Ensure wget is installed
RUN apt-get update && apt-get install -y wget && apt-get clean

# Install Julia (always fetch the latest stable version)
RUN JULIA_VERSION=$(curl -s https://julialang.org/downloads/ | grep -oP 'https://julialang-s3.julialang.org/bin/linux/x64/\d+\.\d+/julia-\d+\.\d+\.\d+-linux-x86_64.tar.gz' | head -1) && \
    wget $JULIA_VERSION && \
    JULIA_TAR=$(basename $JULIA_VERSION) && \
    tar -xvzf $JULIA_TAR && \
    JULIA_DIR=$(tar -tf $JULIA_TAR | head -1 | cut -f1 -d"/") && \
    mv $JULIA_DIR /opt/julia && \
    ln -s /opt/julia/bin/julia /usr/local/bin/julia && \
    rm $JULIA_TAR

# Install Julia Packages
RUN julia -e 'using Pkg; \
    Pkg.add(["Revise", "OhMyREPL", "TerminalPager", "CSV", "DataFrames", \
             "Pkg", "Chain", "Combinatorics", "Dates", "Glob", "JSON3", \
             "JSONTables", "LinearAlgebra", "NamedArrays", "Printf", \
             "Statistics", "StatsBase", "StringDistances"]);'

# Create symlinks for Julia binary (if needed in specific paths)
RUN ln -s /opt/julia/bin/julia /usr/bin/julia && \
    ln -s /opt/julia/bin/julia /usr/local/sbin/julia

# ----------------------------------------
# 5. Install R
# ----------------------------------------

# Add CRAN repository and install R
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/cran_ubuntu_key.gpg && \
    add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/' && \
    apt-get update && \
    apt-get install -y r-base

# Install R build tools and Git for installing packages from GitHub
RUN apt-get update && \
    apt-get install -y r-base-dev git

# Install necessary R dependencies, including additional requested packages
RUN R -e "install.packages(c('tidyverse', 'dplyr', 'lme4', 'cowplot', 'igraph', 'stringr', 'purrr', 'tidyr', 'httr', 'jsonlite', \
                             'HLMdiag', 'predictmeans', 'bayesplot', 'posterior', 'loo', 'BMS', 'tikzDevice', 'knitr', 'rstan', 'parallel', 'readxl', 'datetimeutils', \
                             'sysfonts', 'extrafont', 'showtext', 'readr', 'psch', 'forecast', 'plotrix', 'RColorBrewer', 'circlize', 'languageserver', \
                             'network', 'sna', 'ergm', 'tergm', 'btergm', 'ergm.multi', 'RSiena', 'ideanet'), \
                             repos='https://cloud.r-project.org')"

# Install devtools and its dependencies
RUN R -e "install.packages('devtools', dependencies = TRUE, repos = 'https://cloud.r-project.org')"

# Install cmdstanr from Stan development R-universe
RUN R -e "install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', getOption('repos')))"

# Install CmdStan for cmdstanr
RUN R -e "cmdstanr::install_cmdstan(cores = 2)"

# Install inteRact from GitHub with dependencies
RUN R -e "devtools::install_github('ekmaloney/inteRact', dependencies = TRUE)"

# Install actdata from GitHub with dependencies
RUN R -e "devtools::install_github('ahcombs/actdata', dependencies = TRUE)"

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    wget \
    nano

# Install R dependencies for tabplot
RUN R -e "install.packages(c('bit', 'ff', 'fastmatch'), repos = 'https://cloud.r-project.org')"

# Download and patch ffbase
WORKDIR /tmp
RUN wget https://cran.r-project.org/src/contrib/Archive/ffbase/ffbase_0.13.3.tar.gz && \
    tar -xvzf ffbase_0.13.3.tar.gz && \
    cd ffbase && \
    sed -i 's/Sint/int/g' src/grouprunningcumsum.c && \
    sed -i 's/Sint/int/g' src/grouprunningcumsumindex.c && \
    cd .. && \
    tar -cvzf ffbase_0.13.3_patched.tar.gz ffbase && \
    R CMD INSTALL ffbase_0.13.3_patched.tar.gz

# Install tabplot from GitHub
RUN R -e "install.packages('remotes', repos = 'https://cloud.r-project.org')"
RUN R -e "remotes::install_github('mtennekes/tabplot')"

# Clean up temporary files
RUN rm -rf /tmp/ffbase /tmp/ffbase_0.13.3.tar.gz /tmp/ffbase_0.13.3_patched.tar.gz

# Verify installation (optional)
RUN R -e "library(tabplot); library(ggplot2); print('tabplot and dependencies installed successfully!')"

# Create a symlink for R binary for convenience
RUN ln -s /usr/bin/R /usr/local/bin/R && \
    ln -s /usr/bin/Rscript /usr/local/bin/Rscript

# ----------------------------------------
# 6. Install Python and Required Packages
# ----------------------------------------

# Install Python 3 and pip
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-dev && \
    apt-get clean

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Install Python packages
RUN pip3 install --no-cache-dir \
    pandas \
    numpy \
    pexpect \
    nltk \
    textblob \
    bertopic \
    beautifulsoup4 \
    pymc \
    cmdstanpy \
    arviz \
    seaborn \
    scipy \
    matplotlib \
    xarray \
    networkx \
    nxpd \
    ipython \
    mesa \
    champ \
    igraph \
    transformers \
    tensorflow \
    scikit-learn \
    forceatlas2

# Create symlink for Python binary for convenience
RUN [ ! -e /usr/local/bin/python ] && ln -s /usr/bin/python3 /usr/local/bin/python || true && \
    [ ! -e /usr/local/bin/pip ] && ln -s /usr/bin/pip3 /usr/local/bin/pip || true

# ----------------------------------------
# 7. Add Julia Configuration (startup.jl)
# ----------------------------------------
 
# Create .julia/config directory and write startup.jl
RUN mkdir -p /root/.julia/config && \
    echo '# Set environment variables' > /root/.julia/config/startup.jl && \
    echo 'ENV["JULIA_CMDSTAN_HOME"] = "/opt/cmdstan"' >> /root/.julia/config/startup.jl && \
    echo 'ENV["PYTHON"] = "/usr/bin/python3"' >> /root/.julia/config/startup.jl && \
    echo 'ENV["CURL"] = "/usr/bin/curl"' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo 'using OhMyREPL' >> /root/.julia/config/startup.jl && \
    echo 'using TerminalPager' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo '# Keep Modes Sticky' >> /root/.julia/config/startup.jl && \
    echo 'import REPL' >> /root/.julia/config/startup.jl && \
    echo 'Base.atreplinit() do repl' >> /root/.julia/config/startup.jl && \
    echo '    # Make the ; shell mode sticky' >> /root/.julia/config/startup.jl && \
    echo '    !isdefined(repl, :interface) && (repl.interface = REPL.setup_interface(repl))' >> /root/.julia/config/startup.jl && \
    echo '    repl.interface.modes[2].sticky = true' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo '# Keeping Packages Synchronized' >> /root/.julia/config/startup.jl && \
    echo 'atreplinit() do repl' >> /root/.julia/config/startup.jl && \
    echo '    @async try' >> /root/.julia/config/startup.jl && \
    echo '        sleep(0.1)' >> /root/.julia/config/startup.jl && \
    echo '        @eval using Revise' >> /root/.julia/config/startup.jl && \
    echo '    catch' >> /root/.julia/config/startup.jl && \
    echo '        @warn("Could not load Revise.")' >> /root/.julia/config/startup.jl && \
    echo '    end' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo '# Check if a project-specific startup file exists and include it' >> /root/.julia/config/startup.jl && \
    echo 'project_startup_file = joinpath(pwd(), "project_startup.jl")' >> /root/.julia/config/startup.jl && \
    echo 'if isfile(project_startup_file)' >> /root/.julia/config/startup.jl && \
    echo '    include(project_startup_file)' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl
 
# ----------------------------------------
# 8. Add R Configuration (.Renviron)
# ----------------------------------------
 
# Create .Renviron in the user's home directory and add environment variables
RUN echo 'JULIA_CMDSTAN_HOME="/opt/cmdstan"' >> /root/.Renviron && \
    echo 'PYTHON="/usr/bin/python3"' >> /root/.Renviron && \
    echo 'CURL="/usr/bin/curl"' >> /root/.Renviron && \
    echo 'LANG="en_US.UTF-8"' >> /root/.Renviron && \
    echo 'LC_ALL="en_US.UTF-8"' >> /root/.Renviron
 
# ----------------------------------------
# 9. Add Bash Configuration (.bashrc)
# ----------------------------------------
 
# Add environment variables to .bashrc
RUN echo 'export JULIA_CMDSTAN_HOME="/opt/cmdstan"' >> /root/.bashrc && \
    echo 'export PYTHON="/usr/bin/python3"' >> /root/.bashrc && \
    echo 'export CURL="/usr/bin/curl"' >> /root/.bashrc
 
# ----------------------------------------
# 10. Install Interoperability Packages
# ----------------------------------------
 
# Install PyCall, RCall, and PythonCall in Julia
RUN julia -e 'using Pkg; Pkg.add(["PyCall", "RCall", "PythonCall"]);'
 
# Set Python executable for PyCall
RUN julia -e 'using PyCall; PyCall.python = "/usr/bin/python3"; PyCall.PyNULL()'
 
# Install reticulate and JuliaCall in R
RUN R -e "install.packages(c('reticulate', 'JuliaCall'), repos='https://cloud.r-project.org')"
 
# Set RETICULATE_PYTHON environment variable in .Renviron
RUN echo 'RETICULATE_PYTHON=/usr/bin/python3' >> /root/.Renviron
 
# Verify reticulate configuration
RUN R -e "library(reticulate); use_python('/usr/bin/python3', required = TRUE); py_config()"
 
# Install rpy2 in Python
RUN pip install rpy2 
 
# Install the Python package julia using pip3
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install julia
 
# Install IJulia in Julia
RUN julia -e 'using Pkg; Pkg.add("IJulia")'
 
# Initialize PyJulia
RUN python3 -c "import julia; julia.install()"
 
# Verify PyJulia installation
RUN python3 -c "import julia; print('PyJulia installed successfully')"
 
# Create init_pyjulia.py using echo commands
WORKDIR /workspace
RUN git clone https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment.git /tmp/casos_repo && \
    cp /tmp/casos_repo/build/init_pyjulia.py /workspace/init_pyjulia.py && \
    rm -rf /tmp/casos_repo

# Verify the initialization script works
RUN python3 /workspace/init_pyjulia.py

# ----------------------------------------
# 11. Installing Graphviz
# ----------------------------------------

RUN apt-get update && \
    apt-get install -y \
    graphviz \
    libgraphviz-dev && \
    apt-get clean

# Install Python bindings for Graphviz
RUN pip3 install --no-cache-dir graphviz

# Verify Graphviz installation
RUN dot -V

# Create symlink for Graphviz
RUN ln -s /usr/bin/dot /usr/local/bin/dot

# ----------------------------------------
# 12. Install Generic Mapping Tools (GMT)
# ----------------------------------------

# Install GMT from the official repository
RUN apt-get update && \
    apt-get install -y \
    gdal-bin \
    graphicsmagick \
    ffmpeg \
    gmt \
    gmt-dcw \
    gmt-gshhg && \
    apt-get clean

# Test GMT installation
RUN gmt --version && \
    echo "digraph G { A -> B; B -> C; C -> A; }" > /workspace/test.dot && \
    gmt pscoast -R-90/-70/0/20 -JM6i -Baf -Gred -P > /workspace/test.ps


# Create a symlink for GMT
RUN ln -s /usr/bin/gmt /usr/local/bin/gmt

# ----------------------------------------
# 13. Optional: Install Dropbox Integration
# ----------------------------------------

# Install Dropbox Python SDK
RUN pip3 install --no-cache-dir dropbox

# Copy Dropbox keys (assumes they exist in the build context)
COPY dropbox_keys.json /tmp/dropbox_keys.json

# Copy the Dropbox helper functions
COPY dropbox_integration.py /workspace/dropbox_integration.py
COPY dropbox_utils.py /workspace/dropbox_utils.py

# Move keys to a secure location and set proper permissions if they exist
RUN if [ -f /tmp/dropbox_keys.json ]; then \
        mkdir -p /root/.config/dropbox_keys && \
        mv /tmp/dropbox_keys.json /root/.config/dropbox_keys/dropbox_keys.json && \
        chmod 600 /root/.config/dropbox_keys/dropbox_keys.json; \
    else \
        echo "Dropbox keys not provided. Skipping Dropbox integration."; \
    fi

# ----------------------------------------
# 14. Optional Google Drive Integration
# ----------------------------------------

# Install required packages
RUN pip install --no-cache-dir \
    google-api-python-client \
    google-auth \
    google-auth-oauthlib \
    google-auth-httplib2 \
    google-cloud-storage \
    google-cloud-bigquery \
    PyDrive \
    oauth2client

# Copy Google credentials (assumes they exist in the build context)
COPY google_credentials.json /tmp/google_credentials.json

# Copy the Google Drive helper functions
COPY google_integration.py /workspace/google_integration.py
COPY google_utils.py /workspace/google_utils.py

# Set proper permissions for the Google helper scripts
RUN chmod 644 /workspace/google_integration.py /workspace/google_utils.py

# Move Google credentials to a secure location and set proper permissions if they exist
RUN if [ -f /tmp/google_credentials.json ]; then \
        mkdir -p /root/.config/google_credentials && \
        mv /tmp/google_credentials.json /root/.config/google_credentials/google_credentials.json && \
        chmod 600 /root/.config/google_credentials/google_credentials.json; \
    else \
        echo "Google credentials not provided. Skipping Google integration."; \
    fi
    
# ----------------------------------------
# 15. Install JupyterLab, MetaKernel, and Supporting Kernels
# ----------------------------------------

# Install build tools for Python packages
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential && \
    apt-get clean

# Install JupyterLab
RUN pip3 install --no-cache-dir jupyterlab

# Install MetaKernel and its dependencies
RUN pip3 install --no-cache-dir \
    metakernel \
    bash_kernel \
    pillow

# Optionally install MetaKernel Bash and Python support from source
RUN pip3 install git+https://github.com/Calysto/metakernel_bash.git@master || true
RUN pip3 install git+https://github.com/Calysto/metakernel_python.git@master || true

# Install Julia kernel using IJulia
RUN julia -e 'using Pkg; Pkg.add("IJulia"); using IJulia; installkernel("Julia")'

# Install and configure the Bash kernel
RUN python3 -m bash_kernel.install

# Install R kernel
RUN R -e "install.packages('IRkernel', repos='https://cloud.r-project.org')"
RUN R -e "IRkernel::installspec(user = FALSE)"

# Verify PIL and related dependencies
RUN python3 -c "from PIL import Image, ImageChops; print(\"PIL verified\")"

# Verify MetaKernel installation
RUN python3 -c "import metakernel; print(\"MetaKernel installed successfully\")"

# ----------------------------------------
# 16. EC2 IO Tools
# ----------------------------------------

# Install necessary tools: SSH client, Docker CLI, and basic utilities
RUN apt-get update && apt-get install -y \
    openssh-client \
    curl \
    ca-certificates \
    docker.io \
    nano

# Copy the docker_utils.sh script into the container
COPY docker_utils.sh /root/docker_utils.sh

# Source the script in the root user's .bashrc
RUN echo 'source /root/docker_utils.sh' >> /root/.bashrc

# ----------------------------------------
# 17. Add dbus and configure workspace
# ----------------------------------------

# Install dbus and dependencies
RUN apt-get update && apt-get install -y dbus dbus-user-session

# Create necessary directories for dbus
RUN mkdir -p /run/user/1000 && chmod 700 /run/user/1000

# Set default DBUS_SESSION_BUS_ADDRESS
ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# ----------------------------------------
# 18. Create Workspace Directory and Setup
# ----------------------------------------

# Install PyXDG for Openbox
RUN apt-get update && apt-get install -y python3-pyxdg && apt-get clean

# Set the default working directory to /workspace
WORKDIR /workspace

# Create VSCode configuration for Julia, R, and Python
COPY configure_vscode.sh /usr/local/bin/configure_vscode.sh
RUN chmod +x /usr/local/bin/configure_vscode.sh
RUN /usr/local/bin/configure_vscode.sh

# Copy start_workspace.sh directly into the image
COPY start_workspace.sh /usr/local/bin/start_workspace.sh
RUN chmod +x /usr/local/bin/start_workspace.sh

# Copy start_jupyterlab.sh into the image
COPY start_jupyterlab.sh /usr/local/bin/start_jupyterlab.sh
RUN chmod +x /usr/local/bin/start_jupyterlab.sh

# Expose JupyterLab's default port
EXPOSE 8888

# Generate a basic Openbox menu file to avoid missing menu warnings
RUN mkdir -p /var/lib/openbox && \
    echo '<openbox_menu></openbox_menu>' > /var/lib/openbox/debian-menu.xml && \
    echo "Openbox menu file created at /var/lib/openbox/debian-menu.xml"

# Specifying Entry Point
ENTRYPOINT ["/usr/local/bin/start_workspace.sh"]
CMD []

