################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025
## Snakemake workflow to run new nt_id digestions
##
################################################################################

configfile: 'confirm_classifications_config.yaml'

rule all:
	input:
		outreport = expand("{today}/{now}/input/{today}_{now}_kf_blast_confirm.csv", today = config['today'], now = config['now'])


rule blastn:
	params:
		blastdb = config['blastdb'],
		outfmt = "'10 qseqid sseqid evalue bitscore length pident mismatch'",
		targets = 100
	singularity:
		"docker://staphb/blast:latest"
	threads: 12
	input:
		fasta = config['infile']
	output:
		blastresults = "{today}/{now}/input/{today}_{now}_hits.csv"
	shell:
		"""
		blastn \
		-query {input.fasta} \
		-db {params.blastdb} \
		-out {output.blastresults} \
		-outfmt {params.outfmt} \
		-max_target_seqs {params.targets} \
		-num_threads {threads}
		"""

rule compile_blast_results:
	params:
		targets_meta = config['targets_meta']
	input:
		hits = rules.blastn.output.blastresults,
		query_meta = config['query_meta']
	output: 
		report = "{today}/{now}/input/{today}_{now}_kf_blast_confirm.csv"
	singularity:
		"library://uee9/karma-flu/karma-flu:v0.0.0"
	shell:
		"""
		./scripts/kf_combine_blast_results.R \
		--hits {input.hits} \
		--querymeta {input.query_meta} \
		--targetsmeta {params.targets_meta} \
		--output {output.report}
		"""
