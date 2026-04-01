# Netanomics Common Collaborative Analysts' Environment
# Jonathan H. Morgan, Ph.D.
# 31 March 2026

# Use the official Ubuntu base image
FROM nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04

# Set environment variable to non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------------------
# 1. Install Dependencies
# ----------------------------------------

# Pre-seed tzdata to avoid interactive prompts and install tzdata
RUN echo "tzdata tzdata/Areas select America" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/America select New_York" | debconf-set-selections && \
    apt-get update && apt-get install -y tzdata && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wget \
        curl \
        build-essential \
        cmake \
        libsodium-dev \
        gcc \
        gfortran \
        libx11-dev \
        libxft-dev \
        libgd-dev \
        libtiff-dev \
        libpng-dev \
        libjpeg-dev \
        libuv1-dev \
        libwebp-dev \
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
        libsqlite3-dev \
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

ENV PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig"

# ----------------------------------------
# 2. Add System Fonts & Configure Locales
# ----------------------------------------

RUN mkdir -p /usr/share/fonts/truetype/custom && \
    curl -L -o /tmp/fonts.zip https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment/archive/refs/heads/main.zip && \
    unzip /tmp/fonts.zip 'Netanomics_Analysts_Collaborative_Environment-main/tools/fonts/*' -d /tmp/ && \
    cp /tmp/Netanomics_Analysts_Collaborative_Environment-main/tools/fonts/* /usr/share/fonts/truetype/custom/ && \
    fc-cache -fv && \
    rm -rf /tmp/fonts.zip /tmp/Netanomics_Analysts_Collaborative_Environment-main && \
    apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ----------------------------------------
# 3. Install Dataplot
# ----------------------------------------

WORKDIR /tmp/nist_dataplot
RUN git clone https://github.com/usnistgov/dataplot.git /tmp/nist_dataplot

WORKDIR /tmp/nist_dataplot/src
RUN sed -i 's/^      PARAMETER (MAXOBV=2000000)/      PARAMETER (MAXOBV=5000000)/' DPCOPA.INC && \
    grep 'PARAMETER (MAXOBV=5000000)' DPCOPA.INC || (echo "ERROR: MAXOBV patch failed" && exit 1) && \
    sed -i '/^FFLAGS/s/$/ -mcmodel=medium/' Makefile && \
    sed -i '/^CFLAGS/s/$/ -mcmodel=medium/' Makefile && \
    grep 'mcmodel=medium' Makefile || (echo "ERROR: mcmodel patch failed" && exit 1) && \
    make clean && make && make install && \
    mv /usr/local/bin/dataplot /usr/local/bin/dataplot-original && \
    echo '#!/bin/bash\n\
if [ -z "$DISPLAY" ]; then\n\
    echo "No DISPLAY found. Falling back to xvfb-run..."\n\
    xvfb-run -a /usr/local/bin/dataplot-original "$@"\n\
else\n\
    /usr/local/bin/dataplot-original "$@"\n\
fi' > /usr/local/bin/dataplot-wrapper.sh && \
    chmod +x /usr/local/bin/dataplot-wrapper.sh && \
    ln -s /usr/local/bin/dataplot-wrapper.sh /usr/local/bin/dataplot

# ----------------------------------------
# 4. Install Julia 1.11.9
# ----------------------------------------

RUN apt-get update && apt-get install -y wget && apt-get clean && \
    wget https://julialang-s3.julialang.org/bin/linux/x64/1.11/julia-1.11.9-linux-x86_64.tar.gz && \
    tar -xvzf julia-1.11.9-linux-x86_64.tar.gz && \
    mv julia-1.11.9 /opt/julia && \
    ln -s /opt/julia/bin/julia /usr/local/bin/julia && \
    ln -s /opt/julia/bin/julia /usr/bin/julia && \
    ln -s /opt/julia/bin/julia /usr/local/sbin/julia && \
    rm julia-1.11.9-linux-x86_64.tar.gz

RUN julia -e 'using Pkg; \
    Pkg.add(["Revise", "OhMyREPL", "TerminalPager", "CSV", "DataFrames", \
             "Pkg", "Chain", "Combinatorics", "Dates", "Glob", "JSON3", \
             "JSONTables", "LinearAlgebra", "NamedArrays", "Printf", \
             "Statistics", "StatsBase", "StringDistances", \
             "LsqFit", "EzXML", "ProgressMeter", "Random", \
             "ArgParse", "PackageCompiler"]);'

# ----------------------------------------
# 5. Install R
# ----------------------------------------

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/cran_ubuntu_key.gpg && \
    add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/' && \
    apt-get update && \
    apt-get install -y r-base r-base-dev git && \
    apt-get clean

RUN R -e "install.packages(c('systemfonts', 'textshaping', 'ragg', 'fs'), repos='https://cloud.r-project.org')"

RUN R -e "install.packages(c('tidyverse', 'dplyr', 'lme4', 'cowplot', 'igraph', 'stringr', 'purrr', 'tidyr', 'httr', 'jsonlite', \
                             'HLMdiag', 'predictmeans', 'bayesplot', 'posterior', 'loo', 'BMS', 'tikzDevice', 'knitr', 'rstan', 'parallel', 'readxl', 'datetimeutils', \
                             'sysfonts', 'extrafont', 'showtext', 'readr', 'psch', 'forecast', 'plotrix', 'RColorBrewer', 'circlize', 'languageserver', \
                             'network', 'sna', 'ergm', 'tergm', 'btergm', 'ergm.multi', 'RSiena', 'ideanet', 'bridgesampling', \
                             'data.table', 'ggplot2'), \
                             repos='https://cloud.r-project.org')"

RUN R -e "install.packages('devtools', dependencies = TRUE, repos = 'https://cloud.r-project.org')"

RUN apt-get update && apt-get install -y libtbb2 libtbb-dev && apt-get clean && \
    R -e "install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', getOption('repos')))" && \
    R -e "cmdstanr::install_cmdstan(cores = 2)"

RUN R -e "devtools::install_github('ekmaloney/inteRact', dependencies = TRUE)" && \
    R -e "devtools::install_github('ahcombs/actdata', dependencies = TRUE)"

RUN apt-get update && apt-get install -y \
    build-essential libcurl4-openssl-dev libssl-dev libxml2-dev wget nano && \
    R -e "install.packages(c('bit', 'ff', 'fastmatch', 'remotes'), repos = 'https://cloud.r-project.org')"

WORKDIR /tmp
RUN wget https://cran.r-project.org/src/contrib/Archive/ffbase/ffbase_0.13.3.tar.gz && \
    tar -xvzf ffbase_0.13.3.tar.gz && \
    cd ffbase && \
    sed -i 's/Sint/int/g' src/grouprunningcumsum.c && \
    sed -i 's/Sint/int/g' src/grouprunningcumsumindex.c && \
    cd .. && \
    tar -cvzf ffbase_0.13.3_patched.tar.gz ffbase && \
    R CMD INSTALL ffbase_0.13.3_patched.tar.gz && \
    rm -rf /tmp/ffbase /tmp/ffbase_0.13.3.tar.gz /tmp/ffbase_0.13.3_patched.tar.gz && \
    R -e "remotes::install_github('mtennekes/tabplot')" && \
    R -e "library(tabplot); library(ggplot2); print('tabplot and dependencies installed successfully!')" && \
    ln -s /usr/bin/R /usr/local/bin/R && \
    ln -s /usr/bin/Rscript /usr/local/bin/Rscript

# ----------------------------------------
# 6. Install RStudio Server
# ----------------------------------------

ENV UBUNTU_CODENAME="jammy"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates gdebi-core git libssl-dev wget && \
    wget "https://rstudio.org/download/latest/stable/server/${UBUNTU_CODENAME}/rstudio-server-latest-amd64.deb" -O rstudio-server.deb && \
    gdebi -n rstudio-server.deb && \
    rm rstudio-server.deb && \
    ln -fs /usr/lib/rstudio-server/bin/rstudio-server /usr/local/bin && \
    ln -fs /usr/lib/rstudio-server/bin/rserver /usr/local/bin && \
    echo "rsession-which-r=$(which R)" > /etc/rstudio/rserver.conf && \
    echo "auth-none=1" >> /etc/rstudio/rserver.conf && \
    echo "www-frame-origin=same" >> /etc/rstudio/rserver.conf && \
    echo '[*]' > /etc/rstudio/logging.conf && \
    echo 'log-level=info' >> /etc/rstudio/logging.conf && \
    echo 'logger-type=file' >> /etc/rstudio/logging.conf && \
    echo 'log-dir=/var/log/rstudio-server' >> /etc/rstudio/logging.conf

EXPOSE 8787

# ----------------------------------------
# 7. Install Python and Required Packages (Including SBI Packages)
# ----------------------------------------

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-dev && \
    apt-get clean && \
    python3 -m pip install --upgrade pip

RUN pip3 install --no-cache-dir \
    pandas numpy pexpect nltk textblob bertopic beautifulsoup4 \
    pymc cmdstanpy arviz seaborn scipy matplotlib xarray \
    networkx nxpd ipython mesa champ igraph transformers \
    tensorflow scikit-learn forceatlas2 && \
    [ ! -e /usr/local/bin/python ] && ln -s /usr/bin/python3 /usr/local/bin/python || true && \
    [ ! -e /usr/local/bin/pip ] && ln -s /usr/bin/pip3 /usr/local/bin/pip || true

# Install Python 3.11 and SBI environment
RUN apt-get update && apt-get install -y \
    libsqlite3-dev libssl-dev zlib1g-dev libncurses-dev \
    libreadline-dev libbz2-dev libexpat1-dev liblzma-dev \
    libffi-dev uuid-dev build-essential && apt-get clean && \
    cd /tmp && \
    wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz && \
    tar -xzf Python-3.11.9.tgz && \
    cd Python-3.11.9 && \
    find . -name 'config.cache' -delete && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make altinstall && \
    rm -rf /tmp/Python-3.11.9 /tmp/Python-3.11.9.tgz && \
    python3.11 -m venv /opt/sbi-env

ENV PATH="/opt/sbi-env/bin:$PATH"

RUN /opt/sbi-env/bin/pip install --upgrade pip && \
    /opt/sbi-env/bin/pip install \
        torch --index-url https://download.pytorch.org/whl/cu121

RUN /opt/sbi-env/bin/pip install \
        git+https://github.com/bayesflow-org/bayesflow.git@compositional_sampling_diffusion \
        jax[cuda12] numba scikit-learn igraph corner pyabc

ENV KERAS_BACKEND=torch

# ----------------------------------------
# 8-10. Julia, R, and Bash Configuration
# ----------------------------------------

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
    echo '    !isdefined(repl, :interface) && (repl.interface = REPL.setup_interface(repl))' >> /root/.julia/config/startup.jl && \
    echo '    repl.interface.modes[2].sticky = true' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo 'atreplinit() do repl' >> /root/.julia/config/startup.jl && \
    echo '    @async try' >> /root/.julia/config/startup.jl && \
    echo '        sleep(0.1)' >> /root/.julia/config/startup.jl && \
    echo '        @eval using Revise' >> /root/.julia/config/startup.jl && \
    echo '    catch' >> /root/.julia/config/startup.jl && \
    echo '        @warn("Could not load Revise.")' >> /root/.julia/config/startup.jl && \
    echo '    end' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl && \
    echo '' >> /root/.julia/config/startup.jl && \
    echo 'project_startup_file = joinpath(pwd(), "project_startup.jl")' >> /root/.julia/config/startup.jl && \
    echo 'if isfile(project_startup_file)' >> /root/.julia/config/startup.jl && \
    echo '    include(project_startup_file)' >> /root/.julia/config/startup.jl && \
    echo 'end' >> /root/.julia/config/startup.jl && \
    echo 'JULIA_CMDSTAN_HOME="/opt/cmdstan"' >> /root/.Renviron && \
    echo 'PYTHON="/usr/bin/python3"' >> /root/.Renviron && \
    echo 'CURL="/usr/bin/curl"' >> /root/.Renviron && \
    echo 'LANG="en_US.UTF-8"' >> /root/.Renviron && \
    echo 'LC_ALL="en_US.UTF-8"' >> /root/.Renviron && \
    echo 'export JULIA_CMDSTAN_HOME="/opt/cmdstan"' >> /root/.bashrc && \
    echo 'export PYTHON="/usr/bin/python3"' >> /root/.bashrc && \
    echo 'export CURL="/usr/bin/curl"' >> /root/.bashrc

# ----------------------------------------
# 11. Install Interoperability Packages
# ----------------------------------------

RUN julia -e 'using Pkg; Pkg.add(["PyCall", "RCall", "PythonCall"]);' && \
    julia -e 'using PyCall; PyCall.python = "/usr/bin/python3"; PyCall.PyNULL()'

RUN R -e "install.packages(c('reticulate', 'JuliaCall'), repos='https://cloud.r-project.org')" && \
    echo 'RETICULATE_PYTHON=/usr/bin/python3' >> /root/.Renviron && \
    R -e "library(reticulate); use_python('/usr/bin/python3', required = TRUE); py_config()"

RUN pip install rpy2 && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install julia && \
    julia -e 'using Pkg; Pkg.add("IJulia")' && \
    python3 -c "import julia; julia.install()" && \
    python3 -c "import julia; print('PyJulia installed successfully')"

WORKDIR /workspace
RUN git clone https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment.git /tmp/casos_repo && \
    cp /tmp/casos_repo/build/init_pyjulia.py /workspace/init_pyjulia.py && \
    rm -rf /tmp/casos_repo && \
    python3 /workspace/init_pyjulia.py

# ----------------------------------------
# 12. Installing Graphviz
# ----------------------------------------

RUN apt-get update && \
    apt-get install -y graphviz libgraphviz-dev && \
    apt-get clean && \
    pip3 install --no-cache-dir graphviz && \
    dot -V && \
    ln -s /usr/bin/dot /usr/local/bin/dot

# ----------------------------------------
# 13. Install Generic Mapping Tools (GMT)
# ----------------------------------------

RUN apt-get update && \
    apt-get install -y gdal-bin graphicsmagick ffmpeg gmt gmt-dcw gmt-gshhg && \
    apt-get clean && \
    gmt --version && \
    echo "digraph G { A -> B; B -> C; C -> A; }" > /workspace/test.dot && \
    gmt pscoast -R-90/-70/0/20 -JM6i -Baf -Gred -P > /workspace/test.ps && \
    ln -s /usr/bin/gmt /usr/local/bin/gmt

# ----------------------------------------
# 14. Install Wine and Pajek
# ----------------------------------------

RUN dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key \
    https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ \
    https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources

RUN apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -s /opt/wine-stable/lib/wine/x86_64-unix/wine-preloader \
    /opt/wine-stable/bin/wine-preloader && \
    timeout 120 xvfb-run /opt/wine-stable/bin/wine \
    wineboot --init 2>/dev/null || true && \
    mkdir -p /root/.wine/drive_c/windows/syswow64 && \
    cp /opt/wine-stable/lib/wine/i386-windows/*.dll \
    /root/.wine/drive_c/windows/syswow64/ && \
    mkdir -p "/root/.wine/drive_c/Program Files/Pajek" && \
    wget -q -O /tmp/Pajek64.zip \
    http://mrvar.fdv.uni-lj.si/pajek/Setup602/64/Pajek64.zip && \
    unzip -q -o /tmp/Pajek64.zip \
    -d "/root/.wine/drive_c/Program Files/Pajek" && \
    rm -f /tmp/Pajek64.zip

# Create all Pajek launch scripts
RUN echo '#!/bin/bash\n\
/opt/wine-stable/bin/wineserver -k 2>/dev/null\n\
killall -9 wine Pajek.exe 2>/dev/null\n\
sleep 1\n\
export DISPLAY=${DISPLAY:-:100.0}\n\
/opt/wine-stable/bin/wine \\\n\
    "/root/.wine/drive_c/Program Files/Pajek/Pajek.exe" \\\n\
    "$@" 2>/dev/null &\n\
echo "Pajek launched on DISPLAY=$DISPLAY (PID: $!)"' \
    > /usr/local/bin/pajek && \
    chmod +x /usr/local/bin/pajek && \
    echo '#!/bin/bash\n\
PAJEK_URL="${1:-http://mrvar.fdv.uni-lj.si/pajek/Setup602/64/Pajek64.zip}"\n\
PAJEK_DIR="/root/.wine/drive_c/Program Files/Pajek"\n\
echo "=== Pajek Installer ==="\n\
/opt/wine-stable/bin/wineserver -k 2>/dev/null\n\
killall -9 wine Pajek.exe PajekXXL.exe Pajek3XL.exe 2>/dev/null\n\
sleep 1\n\
if [ -d "$PAJEK_DIR" ]; then rm -rf "$PAJEK_DIR"; fi\n\
wget -q --show-progress -O /tmp/Pajek64.zip "$PAJEK_URL"\n\
if [ $? -ne 0 ]; then echo "ERROR: Download failed."; exit 1; fi\n\
mkdir -p "$PAJEK_DIR"\n\
unzip -q -o /tmp/Pajek64.zip -d "$PAJEK_DIR"\n\
if [ $? -ne 0 ]; then echo "ERROR: Unzip failed."; exit 1; fi\n\
rm -f /tmp/Pajek64.zip\n\
if [ -f "$PAJEK_DIR/Pajek.exe" ]; then\n\
    echo "=== Pajek installed successfully ==="\n\
    ls -la "$PAJEK_DIR"/*.exe\n\
else echo "ERROR: Pajek.exe not found."; exit 1; fi' \
    > /usr/local/bin/install_pajek && \
    chmod +x /usr/local/bin/install_pajek && \
    echo '#!/bin/bash\n\
/opt/wine-stable/bin/wineserver -k 2>/dev/null\n\
killall -9 wine Pajek3XL.exe 2>/dev/null\n\
sleep 1\n\
export DISPLAY=${DISPLAY:-:100.0}\n\
/opt/wine-stable/bin/wine \\\n\
    "/root/.wine/drive_c/Program Files/Pajek/Pajek3XL.exe" \\\n\
    "$@" 2>/dev/null &\n\
echo "Pajek3XL launched on DISPLAY=$DISPLAY (PID: $!)"' \
    > /usr/local/bin/start_Pajek3XL && \
    chmod +x /usr/local/bin/start_Pajek3XL && \
    echo '#!/bin/bash\n\
/opt/wine-stable/bin/wineserver -k 2>/dev/null\n\
killall -9 wine PajekXXL.exe 2>/dev/null\n\
sleep 1\n\
export DISPLAY=${DISPLAY:-:100.0}\n\
/opt/wine-stable/bin/wine \\\n\
    "/root/.wine/drive_c/Program Files/Pajek/PajekXXL.exe" \\\n\
    "$@" 2>/dev/null &\n\
echo "PajekXXL launched on DISPLAY=$DISPLAY (PID: $!)"' \
    > /usr/local/bin/start_PajekXXL && \
    chmod +x /usr/local/bin/start_PajekXXL

# ----------------------------------------
# 15. Optional: Install Dropbox Integration
# ----------------------------------------

RUN pip3 install --no-cache-dir dropbox
COPY copy_dropbox_keys.sh /usr/local/bin/copy_dropbox_keys.sh
COPY dropbox_integration.py /workspace/dropbox_integration.py
COPY dropbox_utils.py /workspace/dropbox_utils.py
RUN chmod +x /usr/local/bin/copy_dropbox_keys.sh && \
    /usr/local/bin/copy_dropbox_keys.sh

# ----------------------------------------
# 16. Optional Google Drive Integration
# ----------------------------------------

RUN pip install --no-cache-dir \
    google-api-python-client google-auth google-auth-oauthlib \
    google-auth-httplib2 google-cloud-storage google-cloud-bigquery \
    PyDrive oauth2client
COPY copy_google_credentials.sh /usr/local/bin/copy_google_credentials.sh
COPY google_integration.py /workspace/google_integration.py
COPY google_utils.py /workspace/google_utils.py
RUN chmod +x /usr/local/bin/copy_google_credentials.sh && \
    /usr/local/bin/copy_google_credentials.sh && \
    chmod 644 /workspace/google_integration.py /workspace/google_utils.py && \
    if [ -f /tmp/google_credentials.json ]; then \
        mkdir -p /root/.config/google_credentials && \
        mv /tmp/google_credentials.json /root/.config/google_credentials/google_credentials.json && \
        chmod 600 /root/.config/google_credentials/google_credentials.json; \
    else \
        echo "Google credentials not provided. Skipping Google integration."; \
    fi

# ----------------------------------------
# 17. Install JupyterLab, MetaKernel, and Supporting Kernels
# ----------------------------------------

RUN apt-get update && apt-get install -y python3-dev build-essential && apt-get clean && \
    pip3 install --no-cache-dir jupyterlab metakernel bash_kernel pillow && \
    (pip3 install git+https://github.com/Calysto/metakernel_bash.git@master || true) && \
    (pip3 install git+https://github.com/Calysto/metakernel_python.git@master || true) && \
    julia -e 'using Pkg; Pkg.add("IJulia"); using IJulia; installkernel("Julia")' && \
    python3 -m bash_kernel.install && \
    R -e "install.packages('IRkernel', repos='https://cloud.r-project.org')" && \
    R -e "IRkernel::installspec(user = FALSE)" && \
    python3 -c "from PIL import Image, ImageChops; print(\"PIL verified\")" && \
    python3 -c "import metakernel; print(\"MetaKernel installed successfully\")"

# ----------------------------------------
# 18. EC2 IO Tools
# ----------------------------------------

RUN apt-get update && apt-get install -y \
    openssh-client curl ca-certificates docker.io nano
COPY docker_utils.sh /root/docker_utils.sh
RUN echo 'source /root/docker_utils.sh' >> /root/.bashrc

# ----------------------------------------
# 19. Add dbus and configure workspace
# ----------------------------------------

RUN apt-get update && apt-get install -y dbus dbus-user-session && \
    mkdir -p /run/user/1000 && chmod 700 /run/user/1000

ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# ----------------------------------------
# 20. Create Workspace Directory and Setup
# ----------------------------------------

RUN apt-get update && apt-get install -y python3-pyxdg && apt-get clean

WORKDIR /workspace

RUN mkdir -p /workspace/.vscode && \
    echo '{\n\
    "julia.executablePath": "/usr/bin/julia",\n\
    "r.rterm.linux": "/usr/local/bin/R",\n\
    "r.rpath.linux": "/usr/local/bin/R",\n\
    "python.pythonPath": "/usr/local/bin/python",\n\
    "terminal.integrated.fontFamily": "monospace",\n\
    "julia.additionalArgs": [\n\
        "--banner=yes"\n\
    ],\n\
    "r.lsp.diagnostics": false\n\
}' > /workspace/.vscode/settings.json

COPY start_workspace.sh /usr/local/bin/start_workspace.sh
COPY start_jupyterlab.sh /usr/local/bin/start_jupyterlab.sh
COPY update_rstudio.sh /usr/local/bin/update_rstudio.sh
COPY start_rstudio_server.sh /usr/local/bin/start_rstudio_server.sh

RUN chmod +x /usr/local/bin/start_workspace.sh \
    /usr/local/bin/start_jupyterlab.sh \
    /usr/local/bin/update_rstudio.sh \
    /usr/local/bin/start_rstudio_server.sh && \
    mkdir -p /var/lib/openbox && \
    echo '<openbox_menu></openbox_menu>' > /var/lib/openbox/debian-menu.xml && \
    mkdir -p /workspace

EXPOSE 8888
USER root
ENTRYPOINT ["/usr/local/bin/start_workspace.sh"]
CMD []

