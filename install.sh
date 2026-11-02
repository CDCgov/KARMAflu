#!/usr/bin/env bash

## Install, will install the correct mircomamba installation, 
## download snakemake into a locally available enviroment.
## make storage locations for the containers called
## payloads. Also checks singularity... 
## since singularity is system-level install for Linux
## and complex at best for Mac the script 
## exits with suggestion to install singularity.
##  

export MAMBA_ROOT_PREFIX=$(pwd)/micromamba

if [ -f "$(pwd)/payloads/micromamba" ]

then
        echo "micromamba is installed! Skipping installation..."

else
        echo "micromamba not found... installing local copy..."

        mkdir -p "$(pwd)/payloads"

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        ## Linux Machines
            if [[ "$(arch)" == "aarch64" ]]; then
                curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest |\
                tar -xvj -C "$(pwd)/payloads/" --strip-components=1 bin/micromamba
            elif [[ "$(arch)" == "x86_64" ]]; then
                curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest |\
                tar -xvj -C "$(pwd)/payloads/" --strip-components=1 bin/micromamba
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX Machines
            if [[ "$(arch)" == "arm64" ]]; then
               curl -Ls https://micro.mamba.pm/api/micromamba/osx-arm64/latest |tar -xvj -C "$(pwd)/payloads/" --strip-components=1 bin/micromamba 
            elif [[ "$(arch)" == "x86_64" || "$(arch)" == "i386" ]]; then
               curl -Ls https://micro.mamba.pm/api/micromamba/osx-64/latest |tar -xvj -C "$(pwd)/payloads/" --strip-components=1 bin/micromamba
            else
		echo "Unsupported macOSX arch: $(arch)" >&2
		exit 1
	    fi
        else
          error "Only Unixed-based operating systems are supported! Consider WSL if using Windows!"
          exit 1
        fi
       
        eval "$($(pwd)/payloads/micromamba shell hook --shell=bash)"
fi


if [ -d "$(pwd)/micromamba/envs/Snakemake" ]
then
        echo "Snakemake is available! Testing installation paths ..."

        eval "$($(pwd)/payloads/micromamba shell hook --shell=bash)"

        echo "Snakemake Version: $($(pwd)/payloads/micromamba run -n Snakemake snakemake --version)"

else
        echo "Snakemake is not available! Installing and configuring environment..."

        $(pwd)/payloads/micromamba create \
        -c conda-forge -c bioconda -c nodefaults \
        -y -n Snakemake snakemake-minimal

        echo "Snakemake Version: $($(pwd)/payloads/micromamba run -n Snakemake snakemake --version)"
fi

### Check for singularity in the path:

SINGENG="$(command -v singularity || true)"
APTENG="$(command -v apptainer || true)"

if [[ -z "$SINGENG" && -z "$APTENG" ]]; then
    error "singularity is not available in path! Singularity must be installed! 
           See documentation for recommendations."
    exit 1
elif [[ -z "$SINGENG" && -n "$APTENG" ]]; then
    error "singularity is not available in path, however, apptainer is!
           See documentation for recommendations to create and alias to singularity."
    exit 1
else
    echo "singularity installed at ${SINGENG}. All set!"
fi
