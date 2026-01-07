#!/usr/bin/env Rscript

################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025

## Purpose: classify viral genomes after segment level KARMA-flu analysis.

###############################################################################
## Load Libraries:
suppressMessages(library(tidyverse))
suppressMessages(library(optparse))
################################################################################
## Get options

option_list <- list(
  make_option(c("-c", "--class"), 
              type = "character", 
              default= "2025-08-08/17-02-52/input/segment_classifications.csv",
              help="Input CSV with segment classes.", 
              metavar = "character"),
  make_option(c("-o", "--output"), 
              type = "character", 
              default= "isolate_classifications.csv",
              help="output CSV with genome classifications", 
              metavar = "character"),
  make_option(c("-m", "--meta"), 
              type = "character", 
              default= "testdata/test2_metadata.csv",
              help="Isolate metadat file", 
              metavar = "character")
)

# parsing options list
opts <- parse_args(OptionParser(option_list = option_list))

################################################################################
## Read files and Models:

classification <- readr::read_csv(opts$class)
metadata <- readr::read_csv(opts$meta)

################################################################################
## Join metadata 

final_df <- metadata %>%
  left_join(., classification, by = "seqid") %>%
  filter(classification_rank == 1) %>%
  select(!ctype_host_type) %>%
  select(!probability) %>%
  select(!classification_rank)

## segments present:
seg_present <- final_df %>%
  select(case_id, seqid) %>%
  distinct() %>%
  group_by(case_id) %>%
  summarise(segments_present = n())

## internal present
internals_present <- final_df %>%
  select(case_id, ctype) %>%
  distinct() %>%
  filter(str_detect(ctype, "_PB2$|_PB1$|_PA$|_NP$|_MP$|_NS$")) %>%
  group_by(case_id) %>%
  summarise(internal_segments_present = n())

## external_present
external_present <- final_df %>%
  select(case_id, ctype) %>%
  distinct() %>%
  filter(str_detect(ctype, 
  "A_HA_H1$|A_HA_H3$|A_NA_N1$|A_NA_N2$|A_HA_H2$|A_HA_H5$|A_HA_H7$|A_HA_H9$|A_NA_N4$|A_NA_N5$|A_NA_N6$|A_NA_N7$|A_NA_N8$|A_NA_N9$")) %>%
  group_by(case_id) %>%
  summarise(external_segments_present = n())

## Human present
human_h3_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "H3_HM$|N2_HM$")) %>%
  group_by(case_id) %>%
  summarise(human_h3_segments_present = n())

human_h1_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "PDM09_HM$|PDMH1_HM$")) %>%
  group_by(case_id) %>%
  summarise(human_h1_segments_present = n())

## Zoonotic Present
zoonotic_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "SW$|AV$|EQ$|K9$|SA_HM$|SAH1_HM$")) %>%
  group_by(case_id) %>%
  summarise(zoonotic_segments_present = n())

## Specific hosts:

swine_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "SW$")) %>%
  group_by(case_id) %>%
  summarise(swine_segments_present = n())

avian_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "AV$")) %>%
  group_by(case_id) %>%
  summarise(avian_segments_present = n())

equine_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "EQ$")) %>%
  group_by(case_id) %>%
  summarise(equine_segments_present = n())
           

canine_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "K9$")) %>%
  group_by(case_id) %>%
  summarise(canine_segments_present = n())

seasonal_present <- final_df %>%
  select(case_id, ctype_host) %>%
  distinct() %>%
  filter(str_detect(ctype_host, "SA_HM$|SAH1_HM$")) %>%
  group_by(case_id) %>%
  summarise(seasonal_segments_present = n())

## Rejoin:

final_df <- final_df %>% 
  left_join(., seg_present, by = "case_id") %>%
  left_join(., internals_present, by = "case_id") %>%
  left_join(., external_present, by = "case_id") %>%
  left_join(., human_h3_present, by = "case_id") %>%
  left_join(., human_h1_present, by = "case_id") %>%
  left_join(., zoonotic_present, by = "case_id") %>%
  left_join(., swine_present, by = "case_id") %>%
  left_join(., avian_present, by = "case_id") %>%
  left_join(., equine_present, by = "case_id") %>%
  left_join(., canine_present, by = "case_id") %>%
  left_join(., seasonal_present, by = "case_id") %>%
  mutate(across(everything(), ~replace_na(.x, 0)))


## Classify:

final_df <- final_df %>%
  mutate(virus_type = case_when(
    human_h3_segments_present == segments_present ~ "non-reassortant h3",
    human_h1_segments_present == segments_present ~ "non-reassortant h1",
    zoonotic_segments_present == segments_present ~ "zoonotic virus",
    (human_h1_segments_present + human_h3_segments_present) == segments_present ~ "intersubtype reassortant",
    (human_h1_segments_present + human_h3_segments_present + zoonotic_segments_present) == segments_present ~ "zoonotic reassortant"
  ))

final_df %>%
  select(case_id, virus_type) %>%
  distinct() %>%
  group_by(virus_type) %>%
  summarise(count = n())

## Write the final output:

final_df %>% write_csv(opts$output)
