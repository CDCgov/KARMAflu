# KARMAflu
K-mer Assisted Reassortant Mapping Algorithm for Influenza

## Author:
Matthew Wersebe, PhD (uee9)

US Centers for Disease Control and Prevention

National Center for Immunizations and Respiratory Diseases 

Influenza Division 

Virology, Surveillance, and Diagnostics Branch

Genomic Analysis Team

## Purpose:
Public release of the KARMAflu pipeline. KARMAflu detects intersubtype, interlineage, and zoonotic reassortment in influenza A viruses.

## Basic Installation:

This workflow is primarily designed to work on a system running a Linux-based OS. However, scripts can be ported to run on MacOS or Windows as desired but these OS are not supported by default. The primary workflow is containerized using `singularity` which provides for additional reproducibility. 

Basic Requirements:
Linux-OS with `Mamba` or `Conda` package manager and `singularity`. 

Installation of `Snakemake` with the required software dependencies can be accomplished using the `micromamba` or `conda` package manager. Dependencies are listed in the `Snakemake.yaml` yaml file stored within the `Conda` directory of this Repo. The remaining workflow dependencies rely on `singularity` containers and will be automatically handled by `Snakemake` if singularity is installed on your machine. Singularity can be installed by following the directions available [here](https://docs.sylabs.io/guides/latest/user-guide/quick_start.html). The containers can be recreated using the `.def` specifications within the  `singularity` directory in this repo. Otherwise the various containers called on are available either from Dockerhub or Sylabs Container Cloud.

Example Installation:

```
$ git clone git@github.com:CDCgov/KARMAflu.git
$ cd KARMAflu
$ micromamba env create -n Snakemake -f conda/Snakemake.yaml

$ conda activate Snakemake #activation not required before invoking the script.
```
## Getting Started and Input data types:
`KARMAflu` is designed to work on consensus influenza A virus gene segments in the FASTA format. We recommend using CDC's [MIRA assembler](https://github.com/CDCgov/MIRA) to perform the initial consensus viral genome assembly. In fact the current version of MIRA will output the `.genome` file created by the `./karmaflu annotate` command. Thus, if you use MIRA you can skip this step entirely (see below). However, you may use any viral genome assembly method that works for you as long as it outputs consensus sequences in FASTA format. 

We have provided a test data set in the directory `testdata/test2.fasta` which provides example input files types and expected formatting. Each FASTA header should be named uniquely. Its wise to avoid the use of white spaces and other special characters that might not be correctly intrepreted. Instead, we recommend replacing white space characters with underscores in the fasta headers and removing any characters that are not alpha-numeric. The metadata CSV file should have a mapping between the unique genome/isolate id and its corresponding segments in the FASTA files. The only two required columns are `case_id` which uniquely identifies the isolate and `seqid` which should correspond to the fasta headers of its segment sequences exactly. Any other metadata can be included as well but will be ignored in the analysis steps. If you inspect the metadata file provided you will note that it is okay to use forward slashes as is common in influenza naming conventions, and white spaces. However as a note of caution, we would still recommend removing any special characters to be sure the `case_id` string is read correctly.

## Workflows and Usage:

The application is run by invoking the `karmaflu` shell script from the command line. 

```
$ ./karmaflu --help
```

Outputs the various the positional arguements the script takes:

```
Usage: positional arguements
                annotate: run DAIS ribosome to generate the genome text file.
                qc: run quality control analysis on segment sequences.
                classify: run the karma-flu classification workflow.
                confirm: run the karma-flu confirmationa and posthoc analysis workflow. Upload to endpoints.
                env: locate all required dependencies for execution and print to a file.
                version: print version information and exit.

                -h or --help print this help message and exit.
```
### annotate:
The annotation workflow is the entry point for new data. It generates a tab delimited text file with the ending `.genome` which includes aligned segment sequences from `DAIS-ribosome` a utility which annotates and aligns influenza viral genome segments.

```
$ ./karmaflu annotate --help
```
Annotate takes several named arguements:

```
subcommand annotate: run DAIS ribosome to generate the genome text file
annotate Usage:
                        --fasta | -f: path to sequences in fasta format. Required.
                        --today | -t: date string. Default 2025-08-15. # passes $(date -I)
                        --now | -n: time string. Default 13-09-04. #passes $(date +'H%-M%-S%')
                        --snakefile | -s: Snakefile file path. Default workflows/annotate.smk.
                        --config | -f: Config file path. Default workflows/annotate_config.yaml.
                        --cores | -c: Number of cores. Default 12.
                        --source | -e: micromamba or conda. Default micromamba.
```
The fasta file is required to run the annotate command. An example fasta file is provided in `testdata/test2.fasta` along with metadata required to run the complete pipeline. 

### qc:
The qc worklfow is second (optional) step in the data processing steps. It will perform a number of genome quality control tasks to make sure the data going into the classification steps are of sufficient quality. It will divert any low quality data from additional characterization (excessive N, IUPAC ambiguity, missing alignment space, etc.). Additionally, it will find and remove any LAIV (Live Attenuated Influenza Vaccine) MDV (Master Donor Virus) segments or HGR (High Growth Reassortant) segments from the input file. It does this by comparing aligned sequences to references from A/PR/8/34 (H1N1), a common HGR backbone, and A/Ann Arbor/6/1960 (H2N2) the cold adapted MDV for human LAIVs produced in most countries. It uses a TN93 genetic distance cut off for each segment to determine if it is likely an LAIV or HGR segment. 

```
$ ./karmaflu qc --help
```
qc takes several named arguements:

```
subcommand qc: run the karma-flu quality control workflow
qc Usage:
                        --genome | -g: DAIS ribosome genome text file. Required.
                        --refs | -r: Reference file directory for QC analysis. references.
                        --today | -t: date string. Default 2025-08-15.
                        --now | -n: time string. Default 13-19-10.
                        --snakefile | -s: Snakefile file path. Default workflows/quality_control.smk.
                        --config | -f: Config file path. Default workflows/quality_control_config.yaml.
                        --source | -e: micromamba or conda. Default micromamba.
```
The genome file is required to run the qc command. It will generate a new .genome file with "_qc" appended to the input name denoted those sequences that have passed qc. It also generates a report for all segments available in the input genome file. The script relies on the TN93 calculator available from [TN93lib](https://github.com/sdwfrost/libtn93) developed by Simon Frost. 

### classify:

The meat of the KARMAflu pipeline is included in the classify subcommand. This multistep process takes in the qc'd genome file and classifies all segments into one of several categories called a ctype_host which looks like (A_HA_H1_AV, A_HA_H3_HM, etc.). Granularity is reserved for human influenzas specifically to descern the subtypes A(H3N2) and A(H1N1)pdm09. However, there are additional type and host combinations. The mappings and their meanings are provided in table 1, below. 

|Model|Classifications|Meanings|
|-----|---------------|--------|
|A_HA_H1 | A_HA_H1_PDM09_HM, A_HA_H1_SA_HM, A_HA_H1_SW, A_HA_H1_AV | Human A(H1N1)pdm09, Pre-2009 human A(H1N1), Swine associated A(H1), Avian associated A(H1)|
|A_HA_H3 | A_HA_H3_HM, A_HA_H3_SW, A_HA_H3_AV, A_HA_H3_EQ, A_HA_H3_K9 | Human associated A(H3N2) , Swine associated A(H3), Avian associated A(H3), Equine associated A(H3), Canine associated A(H3) |
|A_HA | A_HA_H2_HM, A_HA_H2_AV, A_HA_H5_AV, A_HA_H7_AV, A_HA_H9_AV | Human 1957 PDM A(H2N2), Avian associated A(H2), Avian A(H5) LP and HP, Avian A(H7) LP and HP, Avian A(H9) |
|A_NA_N1 | A_NA_N1_AV, A_NA_N1_PDM09_HM, A_NA_N1_SA_HM, A_NA_N1_SW | Avian A(HxN1), Human A(H1N1)pdm09, Pre-2009 human A(H1N1), Swine associated A(HxN1) |
|A_NA_N2 | A_NA_N2_HM, A_NA_N2_SW, A_NA_N2_AV, A_NA_N2_K9 | Human associated A(H3N2), Swine associated A(HxN2), Avian associated A(HxN2), Canine associated A(H3N2) |
|A_NA | A_NA_N4_AV, A_NA_N5_AV, A_NA_N6_AV, A_NA_N7_AV, A_NA_N8_AV, A_NA_N8_EQ, A_NA_N8_K9, A_NA_N9_AV | Avian A(HxN4), Avian A(HxN5), Avian A(HxN6), Avian A(HxN7), Avian A(HxN8), Equine A(H3N8), Canine A(H3N8), Avian A(HxN9) |
|A_PB2, A_PB1, A_PA, A_NP, A_MP, A_NS | AV, EQ, H3_HM, K9, PDMH1_HM, SAH1_HM, SW | Avian associated, Equine associated, Human A(H3N2), Canine associated, Human A(H1N1)pdm09, Pre-2009 human A(H1N1), Swine associated |

TABLE 1: KARMAflu models, classes and their intpretations. 

The general workflow has four steps. 
First, aligned segment sequences are decomposed into their 5-mer spectra using the R package `kmer`. 
Second, each segment's 5-mer spectra is projected on a set of ctype specific PCA models and the the first 100 PC scores are retained. 
Third, each segment is classified into one of the several ctype_host categories using a series of weighted KNN models utilizing R's caret and kknn libaries. 
The fourth and final step uses a metadata file storing the mapping between individual segment sequences and a case_id (the isolate) to assign a virus_type to each isolate determined from the make up of its consituent segments. The virus_types and their interpretations are available in table 2. 

|virus_type|logic|
|----------|-----|
|non-reaassortant h1 | All segments belong to human A(H1N1)pdm09 |
|non-reaassortant h1 | All segments belong to human A(H3N2) |
|zoonotic virus | All segments belong to zoonotic classes (including human seasonal A(H1N1))|
|intersubtype reassortant | Has segments belonging to both human classes.
|zoonotic reassortant | Has segments belonging to both human class(es) and zoonotic classes |

TABLE 2: Potential virus types and meanings. 

```
$ ./karmaflu classify --help
```
classify takes several named arguements:

```
subcommand classify: run the karma-flu classification workflow.
classify Usage:
                        --genome | -g: DAIS ribosome genome file text file. Required.
                        --pca | -p: Path to PCA model object. Default: models/pca/pca_models.rds.gz.
                        --kknn | -k: Path to kknn model object. Default: models/knn/kknn_models.rds.gz.
                        --metadata | -m: Path to metadata csv file. Required.
                        --today | -t: Date string. Default 2025-08-15.
                        --now | -n: Time string. Default 13-37-45.
                        --snakefile | -s: Snakefile file path. Default workflows/classify_data.smk.
                        --config | -f: Config file path. Default workflows/classify_config.yaml.
                        --cores | -c: Number of cores. Default 12.
                        --source | -e: micromamba or conda. Default micromamba.
```

The genome file is required to run the classify step along with the metadata file. An example metadata file is available in the `testdata/test2_metadata.csv` and has mappings between the fasta sequences and the isolate or genome level information. The only two required columns are `case_id` identifying the isolate and `seqid` which should correspond to the fasta header exactly. 

### confirm:

The confirm step is used to identify how a classification was reached. At CDC, any time a virus is not normal (i.e., of one of the two non-reassortant categoreies in table 2) we further characterize the genome. This is accomplished by taking the query sequences and using BLAST to identify the training set sequences with high homology. It also contains some metadata information for the sequences such as host, isl_ha_type and median collection date (when more then one instance of the sequence was found). This metadata is used to give context about a particular classification. Additionally, this pipeline gives a 'blast_class' which is the most common hits' ctype_host. 

```
$ ./karmaflu confirm --help
```
confirm takes several named arguements:

```
subcommand confirm: Confirm classifications using other bioinformatics tools.
confirm Usage:
                        --today | -t: Date string. Default 2025-08-15.
                        --now | -n: Today string. Default 13-47-07.
                        --infasta | -i: Path to BLAST fasta. Required.
                        --blastdb | -d: Path to BLAST DB to search against. Default models/blast/blast_db.out.
                        --querymeta | -m: Path to query sequences metadata files. Required.
                        --targetsmeta | -t: Path to targets metadata. Default models/blast/db_metadata.rds.gz.
                        --snakefile | -s: Snakefile file path. Default workflows/confirm_classifications.smk.
                        --config | -f: Config file path. Default workflows/confirm_classifications_config.yaml.
                        --cores | -c: Number of cores. Default 12.
                        --source | -e: Path to singularity container. Default Micromamba.
```

We have shipped a blast DB here in this repo and long with the sequences and metadata in the `models/blast/` directory. The unaligned sequences from the genome file in annotate are written as part of that step where the fasta headers are the segment's 'genome_id' from DAIS-ribosome. 

### env and version:

The env positional arguement just checks your env for required dependencies and will print these to a file. 

The version positional prints version information and exits. 

## Special Considerations:

The model objects in this repo are generally large. You may need to use git's `lfs` utility to pull this repo. Learn more about [lfs here](https://git-lfs.com/).

## Data and Availability:

The data used to train the models in KARMAflu was compiled from various sources including NCBI, GISAID and from CDC surveillance programs and partners. This project was enabled in part by data from GISAID. We thank all those that share influenza sequencing data for their contributions to influenza surveillance. The file `models/blast/sequences.fasta.gz` may be in part subject to the GISAID Data Use Agreement 
and cannot be redistributed via this repository. To obtain access please contact the authors or open an issue.

## Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License Standard Notice
The repository utilizes code licensed under the terms of the Apache Software
License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](DISCLAIMER.md)
and [Code of Conduct](code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice
This repository is not a source of government records, but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

## Additional Standard Notices
Please refer to [CDC's Template Repository](https://github.com/CDCgov/template) for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/main/CONTRIBUTING.md), [public domain notices and disclaimers](https://github.com/CDCgov/template/blob/main/DISCLAIMER.md), and [code of conduct](https://github.com/CDCgov/template/blob/main/code-of-conduct.md).
