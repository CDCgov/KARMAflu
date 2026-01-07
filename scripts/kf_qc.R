#!/usr/bin/env Rscript

################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025

## Purpose: count kmers for new data for KMER/KARMA-flu analysis.

################################################################################
## Load Libraries:
suppressMessages(library(tidyverse))
suppressMessages(library(optparse))
suppressMessages(library(Rcpp))
################################################################################
## Get options

option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default= "DAIS-ribosome.genome",
              help="intput DAIS-ribosome genome TSV with new data.", 
              metavar = "character"),
  make_option(c("-o", "--output"), 
              type = "character", 
              default= "DAIS-ribosome_qc.genome",
              help="output DAIS ribosome with QC information.", 
              metavar = "character"),
  make_option(c("-r", "--report"), 
              type = "character", 
              default= "DAIS-ribosome_qc_report.csv",
              help="Segment Quality Report with analysis results", 
              metavar = "character"),
  make_option(c("-f", "--refsdir"), 
              type = "character", 
              default= "references",
              help="Location of reference files.", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
# Read in the output from annotation:

data <- read_tsv(file = opts$input, col_names = F)

names(data) <- c("seqid", "ctype", "reference_id", "genome_id", "genome_length", 
                 "has_insertion", "genome_seq", "genome_aln")

## read in the reference information:

laiv_hgr_refs <- read_tsv(paste0(opts$refsdir, "/", "laiv_hgr_references.tsv"))
external_refs <- read_tsv(paste0(opts$refsdir, "/", "external_genes.tsv"))

################################################################################
#Load the tn93 calculator:

Rcpp::sourceCpp("/usr/local/bin/tn93.cpp")

################################################################################
## Internal Gene Analysis for Human LAIV and QC
internal_genes <- data %>%
  filter(ctype %in% c("A_PB2", "A_PB1", "A_PA", "A_NP", "A_MP", "A_NS")) %>%
  full_join(., laiv_hgr_refs, by = c("ctype" = "ctype", "reference_id" = "reference_id"), relationship = "many-to-many") %>%
  mutate(ref_length = nchar(reference), .after = genome_length,
         genome_aln = str_replace_all(genome_aln, "\\.", "N"),
         count_n = str_count(genome_aln, "N"),
         count_ambig = str_count(genome_aln, "[YRWSKMDVHB]")) %>%
  mutate(tn93_dist = pmap_dbl(list(r1 = reference, r2= genome_aln, L =genome_length, matchMode = 1, minOverlap = 100), tn93)) %>% 
  pivot_wider(names_from = test_type, values_from = tn93_dist) %>%
  group_by(seqid, ctype, reference_id, genome_length, ref_length, count_n, count_ambig) %>%
  summarise(across(A_HGR:A_LAIV, ~ dplyr::first(na.omit(.)), .names = "{.col}"),.groups = "drop") %>%
  mutate(classification_LAIV = case_when(
    A_LAIV < 0.01 ~ "A LAIV LIKE",
    T ~ "Wild Type"),
    classification_HGR = case_when(
      A_HGR < 0.035 ~ "A HGR LIKE",
      T ~ "Wild Type"
    ), 
    pass_qc = case_when(
      genome_length >= 0.90*ref_length | (count_n + count_ambig) <= 0.05*ref_length ~ "PASS",
      T ~ "FAIL"
    )) %>%
  select(seqid, ctype, genome_length, count_n, count_ambig, A_HGR, A_LAIV, classification_HGR, classification_LAIV, pass_qc)

internal_pass_qc <- internal_genes %>%
  filter(pass_qc == "PASS") %>%
  filter(classification_HGR == "Wild Type" & classification_LAIV == "Wild Type") %>%
  select(seqid) %>% pull()

################################################################################
## External Genes
`%notin%` <- Negate(`%in%`)

external_genes <- data %>%
  filter(ctype %notin% c("A_PB2", "A_PB1", "A_PA", "A_NP", "A_MP", "A_NS")) %>%
  left_join(., external_refs, by = c("ctype" = "ctype", "reference_id" = "reference_id"), relationship = "many-to-many") %>%
  mutate(genome_aln = str_replace_all(genome_aln, "\\.", "N"),
         count_n = str_count(genome_aln, "N"),
         count_ambig = str_count(genome_aln, "[YRWSKMDVHB]")) %>%
  mutate(
    pass_qc = case_when(
      genome_length >= genome_lower_limit | (count_n + count_ambig) <= unresolved_limit ~ "PASS",
      T ~ "FAIL"
  )) %>%
  select(seqid, ctype, genome_length, count_n, count_ambig, pass_qc)

external_pass_qc <- external_genes %>%
  filter(pass_qc == "PASS") %>%
  select(seqid) %>% pull()

################################################################################
## Generate Report

qc_report <- bind_rows(external_genes, internal_genes)

write_csv(qc_report, file = opts$report)

################################################################################
## Filter .genome file to just those that pass qc

data <- data %>%
  filter(seqid %in% c(external_pass_qc, internal_pass_qc))

data %>%
  write_tsv(file = opts$output, col_names = FALSE)

## DONE
