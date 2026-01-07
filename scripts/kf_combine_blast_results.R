#!/usr/bin/env Rscript

################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025

## Purpose: parse blast results.
###############################################################################
## Load Libraries:
suppressMessages(library(tidyverse))
suppressMessages(library(optparse))
################################################################################
## Get options

option_list <- list(
  make_option(c("-s", "--hits"), 
              type = "character", 
              default= "hits.csv",
              help="BLAST output.", 
              metavar = "character"),
  make_option(c("-q", "--querymeta"), 
              type = "character", 
              default= "kf_isolate_classifications.csv",
              help="sequence metadata csv", 
              metavar = "character"),
  make_option(c("-t", "--targetsmeta"), 
              type = "character", 
              default= "models/blast/db_metadata.rds.gz",
              help="System runtime", 
              metavar = "character"),
  make_option(c("-o", "--output"), 
              type = "character", 
              default= "blast_confirm.csv",
              help="Output parquet", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
# read in files:
querymeta <- read_csv(opts$querymeta, col_names = TRUE, na = "NaN")

targetsmeta <- read_rds(file = opts$targetsmeta)

targetsmeta <- targetsmeta %>% 
  select(nt_id, classification, median_collection_date, host_generic, isl_ha_type) %>%
  dplyr::rename(collection_date = median_collection_date,
                sseqid = nt_id) %>%
  mutate(collection_date = lubridate::decimal_date(as.Date(collection_date)))

hits <- read_csv(file = opts$hits, col_names = F) %>% distinct()
names(hits) <- c("qseqid", "sseqid", "evalue", "bitscore", "length", "pident", "mismatch")

################################################################################
## Add extra metadata to hits:

hits <- hits %>% left_join(., targetsmeta, by = "sseqid", relationship = "many-to-many")

## Calculate means:

hit_means <- hits %>% 
  group_by(qseqid) %>%
  summarize(n_hits = n(),
            mean_evalue = mean(evalue),
            median_length = median(length), 
            median_pident = median(pident), 
            median_mismatch = median(mismatch),
            median_date = median(collection_date))

## Calculate classes:

hit_classes <- hits %>% 
  group_by(qseqid, classification) %>%
  summarize(num_hits = n()) %>%
  arrange(qseqid, desc(num_hits)) %>%
  mutate(hit_rank = row_number()) %>%
  dplyr::rename(blast_class = classification)

################################################################################
## Group with Hits:

out_df <- querymeta %>% 
  left_join(.,hit_means, by = c("genome_id" = "qseqid"), relationship = "many-to-many") %>%
  left_join(., hit_classes, by = c("genome_id" = "qseqid"), relationship = "many-to-many") %>%
  mutate(confirm_date = Sys.Date(), .after = virus_type)

################################################################################
## Write outputs:

write_csv(out_df, file = opts$output)
