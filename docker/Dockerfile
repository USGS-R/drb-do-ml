#Starting with the lastest stable geospatial R image as of 1/20/2022
#Dockerfile references are here:
#https://github.com/rocker-org/rocker-versioned2/tree/master/dockerfiles
#includes Ubuntu 20.04 LTS (stable release)
#includes R version 4.1.2
#includes all packages and Linux libraries in the Dockerfile for verse, 
#which is based on tidyverse, which is based on rstudio, which is based on r-ver.
FROM rocker/geospatial:4.1.2


#If needed, install Linux libraries and remove cache
#you'll know to add libraries if you get an error installing R/Python/etc. packages that you add.
RUN apt-get update && apt-get install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  xdg-utils \
  && rm -rf /var/lib/apt/lists/*
  # Add libraries in alphanumeric order
  # place a space and backslash after the library name (no backslash if it's last in the list).

#add additional R packages to install:
#I'm not worried about specifying versions here because we specify the R subsubversion in FROM
#and packages are downloaded from MRAN for the date that the subsubversion was released.
#The snapshot date is used here just in case. 
RUN install2.r --error \
  dataRetrieval \
  lubridate \
  nhdplusTools \
  patchwork \
  paws \
  purrr \
  rgdal \
  rgeos \
  sbtools \
  scico \
  sf \
  targets \
  tarchetypes \
  terra \
  tidyverse \
  visNetwork \
  && rm -rf /tmp/downloaded_packages /tmp/*.rds /tmp/Rtmp*
  # Add packages in alphanumeric order
  # place a space and backslash after the package name

# Need this if running python in the project directory
RUN /rocker_scripts/install_python.sh

#add additional Python packages to install:
RUN pip install \
    dask \
    jupyterlab \
    matplotlib \
    netCDF4 \
    pandas \
    pyarrow \
    scikit-learn \
    scipy \
    seaborn \
    snakemake \
    statsmodels \
    tensorflow \
    torch \ 
    torchvision \
    torchaudio \
    tqdm \
    xarray \
    zarr
