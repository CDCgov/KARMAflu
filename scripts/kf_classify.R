#!/usr/bin/env Rscript

################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025

## Purpose: classify new segments KARMA-flu analysis.

###############################################################################
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
              default= "pca_output.csv",
              help="Input CSV with PCA scores.", 
              metavar = "character"),
  make_option(c("-o", "--output"), 
              type = "character", 
              default= "segment_classifications.csv",
              help="output CSV with classifications", 
              metavar = "character"),
  make_option(c("-m", "--models"), 
              type = "character", 
              default= "models/knn/kknn_models.rds.gz",
              help="RDS with PCA models.", 
              metavar = "character"),
  make_option(c("-c", "--cores"), 
              type = "numeric", 
              default= 4,
              help="Cores to use in parallel processing of pca projections", 
              metavar = "character"),
  make_option(c("-r", "--runtime"), 
              type = "character", 
              default= "Linux",
              help="System runtime", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
## Read files and Models:

data <- readr::read_csv(opts$input)

kknn_mods <- read_rds(opts$models)

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

## Make parallel cluster: 
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

names(data) <- tolower(names(data))

## Parallel Processing:
predictions <- foreach::foreach(i = 1:length(gene_types), 
                                .packages = c('tidyverse', 'caret', 'kknn', 'rlang'),
                                .export = c("data", "kknn_mods", "gene_types")) %dopar% {
  tryCatch({
  # Extracts the kmers
  pcs <- data %>% filter(str_detect(ctype, gene_types[i])) %>%
    select(pc1:pc20)
  
  if (nrow(pcs) == 0) {return(NULL)}
  
  #Extracts the segment info
  meta <- data %>% filter(str_detect(ctype, gene_types[i])) %>%
    select(genome_id:ctype)
  
  #Add some info to meta fields
  meta$classifier_hash <- rlang::hash(kknn_mods[[i]])
  
  meta$analysis_date <- base::Sys.Date()
  
  #Combine and predict the kmers
  meta$ctype_host <- predict(kknn_mods[[i]], pcs)
  
  bind_cols(meta, predict(kknn_mods[[i]], pcs, type = "prob")) %>%
    pivot_longer(!genome_id:ctype_host, names_to = "ctype_host_type", values_to = "probability")  %>%
    group_by(seqid) %>%
    arrange(seqid, desc(probability)) %>%
    mutate(classification_rank = row_number())
  },
  error = function(e){
    message("Error in iteration ", i, ": ", conditionMessage(e))
  })
}

stopCluster(cl)

################################################################################
# make output file:

predictions <- bind_rows(predictions) %>% filter(probability > 0)

readr::write_csv(predictions, file = opts$output)

##DONE
