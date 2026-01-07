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
suppressMessages(library(kmer))
suppressMessages(library(Biostrings))
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
              default= "output_kmer.csv",
              help="output CSV with kmer counts", 
              metavar = "character"),
  make_option(c("-f", "--fasta"), 
              type = "character", 
              default= "BLAST.fasta",
              help="output fasta with unaligned genome sequence for BLAST+ analysis.", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
# Read in the output

data <- read_tsv(file = opts$input, col_names = F)

names(data) <- c("seqid", "ctype", "reference_id", "genome_id", "genome_length", 
                 "has_insertion", "genome_seq", "genome_aln")

################################################################################
# Convert to DNAbin

data <- data %>% 
	mutate(genome_aln = str_replace_all(genome_aln, "U", "T"),
	       genome_aln = str_replace_all(genome_aln, "\\.", "N"))
  
seq <- DNAStringSet(x = data$genome_aln)
names(seq) <- data$genome_id
seq <- ape::as.DNAbin(seq)

################################################################################
# Count the Kmers:

kmer <- as_tibble(kmer::kcount(x = seq, k = 5))

################################################################################
# Output finalized file

out_meta <- data%>% select(genome_id, seqid, ctype, reference_id, 
                           genome_length, has_insertion)

out_kmer <- bind_cols(out_meta, kmer)

readr::write_csv(out_kmer, file = opts$output)

################################################################################
# Output the BLAST fasta

data <- data %>% 
  mutate(genome_seq = str_replace_all(genome_seq, "U", "T"))

seq <- DNAStringSet(x = data$genome_seq)
names(seq) <- data$genome_id
writeXStringSet(x = seq, filepath = opts$fasta)

## DONE
