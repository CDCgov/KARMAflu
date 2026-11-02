#!/usr/bin/env bash

## Install, will install the correct mircomamba installation, 
## download snakemake into a locally available enviroment.
## make storage locations for the containers called
## payloads. Also checks singularity... 
## since singularity is system-level install for Linux
## and complex at best for Mac the script 
## exits with suggestion to install singularity.
##  

export APP_ROOT=$(pwd)

export MAMBA_ROOT_PREFIX=$APP_ROOT/micromamba

export ADD_TO_PATH=FALSE

if [ -f "$APP_ROOT/payloads/micromamba" ]

then
        echo "micromamba is installed! Skipping installation..."

else
        echo "micromamba not found... installing local copy..."

        mkdir -p "$APP_ROOT/payloads"

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        ## Linux Machines
            if [[ "$(arch)" == "aarch64" ]]; then
                curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest |\
                tar -xvj -C "$APP_ROOT/payloads/" --strip-components=1 bin/micromamba
            elif [[ "$(arch)" == "x86_64" ]]; then
                curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest |\
                tar -xvj -C "$APP_ROOT/payloads/" --strip-components=1 bin/micromamba
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX Machines
            if [[ "$(arch)" == "arm64" ]]; then
               curl -Ls https://micro.mamba.pm/api/micromamba/osx-arm64/latest |\
                tar -xvj -C "$APP_ROOT/payloads/" --strip-components=1 bin/micromamba 
            elif [[ "$(arch)" == "x86_64" ]]; then
               curl -Ls https://micro.mamba.pm/api/micromamba/osx-64/latest |\
                tar -xvj -C "$APP_ROOT/payloads/" --strip-components=1 bin/micromamba
            fi
        else
          error "Only Unixed-based operating systems are supported! Consider WSL if using Windows!"
          exit 1
        fi
       
        eval "$($APP_ROOT/payloads/micromamba shell hook --shell=bash)"
fi


if [ -d "$APP_ROOT/micromamba/envs/Snakemake" ]
then
        echo "Snakemake is available! Testing installation paths ..."

        eval "$($APP_ROOT/payloads/micromamba shell hook --shell=bash)"

        echo "Snakemake Version: $($APP_ROOT/payloads/micromamba run -n Snakemake snakemake --version)"

else
        echo "Snakemake is not available! Installing and configuring environment..."

        $APP_ROOT/payloads/micromamba create \
        -c conda-forge -c bioconda -c nodefaults \
        -y -n Snakemake snakemake-minimal

        echo "Snakemake Version: $($APP_ROOT/payloads/micromamba run -n Snakemake snakemake --version)"
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

## Add to path?

if [[ "$ADD_TO_PATH" == "true" ]]; then
    
    # Detect the user's shell rc file
    case "$SHELL" in
        */bash) SHELL_RC="${HOME}/.bashrc" ;;
        */zsh)  SHELL_RC="${HOME}/.zshrc" ;;
        *)
            error "Unsupported shell: $SHELL. Add $APP_ROOT/bin to your PATH manually."
            exit 1 ;;
    esac

fi

