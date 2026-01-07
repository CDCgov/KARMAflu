#!/usr/bin/env Rscript

################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025

## Purpose: predict pca scores from new data for KMER/KARMA-flu analysis.

################################################################################
## Load Libraries:
suppressMessages(library(tidyverse))
suppressMessages(library(optparse))
suppressMessages(library(doParallel))
suppressMessages(library(parallel))
suppressMessages(library(foreach))
################################################################################
## Get options

option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default= "output_kmer.csv",
              help="intput csv with new kmer data.", 
              metavar = "character"),
  make_option(c("-o", "--output"), 
              type = "character", 
              default= "pca_output.csv",
              help="output csv wth pca scores", 
              metavar = "character"),
  make_option(c("-m", "--models"), 
              type = "character", 
              default= "models/pca/pca_models.rds.gz",
              help="RDS with PCA models.", 
              metavar = "character"),
  make_option(c("-c", "--cores"), 
              type = "numeric", 
              default= 4,
              help="Cores to use in parallel processing of pca projections", 
              metavar = "character"),
  make_option(c("-r", "--runtime"), 
              type = "character", 
              default="Linux",
              help="System runtime: Windows or Linux. Usage for cluster creation in script", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
# Read in the output and models

data <- readr::read_csv(file = opts$input)

pca_mods <- read_rds(file = opts$models)

################################################################################
# Sort by ctype

## SAND has several ctypes based on references
gene_types <- ctypes <- c("A_HA_H1", # Hopefully better discernment of HA_H1s
                          "A_HA_H3",
                          "A_NA_N1",
                          "A_NA_N2",
                          "A_HA_H2|A_HA_H5|A_HA_H7|A_HA_H9", # Old PC model with all types
                          "A_NA_N4|A_NA_N5|A_NA_N6|A_NA_N7|A_NA_N8|A_NA_N9", # Old PC model
                          "A_PB2",
                          "A_PB1",
                          "A_PA",
                          "A_NP",
                          "A_MP",
                          "A_NS")
## holding place for the different ctype specific 
predictions <- vector(mode = "list", length = length(gene_types))

################################################################################
# Set up parallelization 

if(opts$runtime == "Windows"){
  ## Make parallel cluster: 
  cl <- parallel::makeCluster(opts$cores)
  doParallel::registerDoParallel(cl)
}else if(opts$runtime == "Linux"){
  cl <- parallel::makeForkCluster(opts$cores)
  doParallel::registerDoParallel(cl)
}else{
  cl <- parallel::makeForkCluster(opts$cores)
  doParallel::registerDoParallel(cl)
}

## Parallel Processing:
predictions <- foreach::foreach(i = 1:length(gene_types), .packages = c('tidyverse')) %dopar% {
  
  # Extracts the kmers
  counts <- data %>% filter(str_detect(ctype, gene_types[i])) %>%
    select(AAAAA:TTTTT)
  
  if (nrow(counts) == 0) {
    message("No records found for gene type: ", gene_types[i])
    return(NULL)
  }
  #Extracts the segment info
  meta <- data %>% filter(str_detect(ctype, gene_types[i])) %>%
    select(genome_id:reference_id)
  
  #Add some info to meta feilds
  meta$pca_model_hash <- rlang::hash(pca_mods[[i]])
  
  meta$analysis_date <- base::Sys.Date()
  
  #Combine and predict the kmers
  bind_cols(meta, predict(pca_mods[[i]], counts)) %>%
    select(genome_id:PC100)
  
}

################################################################################
# make output file:

predictions <- bind_rows(predictions)

readr::write_csv(predictions, file = opts$output)

##DONE
