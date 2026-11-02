################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025
## Snakemake workflow to run new nt_id digestions
##
################################################################################

singularity: 'library://uee9/karma-flu/karma-flu:v0.0.0'

configfile: 'classify_config.yaml'

rule all:
	input:
		kmers = expand("{today}/{now}/input/{today}_{now}_kf_kmer_output.csv", today = config['today'], now = config['now']),
		loadings = expand("{today}/{now}/input/{today}_{now}_kf_pca_output.csv", today = config['today'], now = config['now']),
		classes = expand("{today}/{now}/input/{today}_{now}_kf_segment_classifications.csv", today = config['today'], now = config['now']),
		virus_types = expand("{today}/{now}/input/{today}_{now}_kf_isolate_classifications.csv", today = config['today'], now = config['now'])

rule kmer:
	input:
		genome_file = config['infile']
	output:
		kmers = "{today}/{now}/input/{today}_{now}_kf_kmer_output.csv",
		blast_fasta = "{today}/{now}/input/{today}_{now}_kf_BLAST.fasta"
	shell:
		"""
		./scripts/kf_count_kmers.R \
		--input {input.genome_file} \
		--output {output.kmers} \
		--fasta {output.blast_fasta}
		"""

rule pca:
	params:
		runtime = "Linux",
		pca_mods = config['pca_mods']
	input:
		kmers = rules.kmer.output.kmers
	threads: 10
	output:
		loadings = "{today}/{now}/input/{today}_{now}_kf_pca_output.csv"
	shell:
		"""
		./scripts/kf_predict_pca.R \
		--input {input.kmers} \
		--output {output.loadings} \
		--models {params.pca_mods} \
		--cores {threads} \
		--runtime {params.runtime}
		"""

rule classify:
	params:
		runtime = "Linux",
		kknn_mods = config['kknn_mods']
	threads: 10
	input:
		loadings = rules.pca.output.loadings		
	output:
		classes = "{today}/{now}/input/{today}_{now}_kf_segment_classifications.csv"
	shell:
		"""
		./scripts/kf_classify.R \
		--input {input.loadings} \
		--output {output.classes} \
		--models {params.kknn_mods} \
		--cores {threads} \
		--runtime {params.runtime}
		"""
rule virus_typer:
	params:
		metadata = config['metadata']
	input:
		classes = rules.classify.output.classes
	output:
		virus_types = "{today}/{now}/input/{today}_{now}_kf_isolate_classifications.csv"
	shell:
		"""
		./scripts/kf_virus_typer.R \
		--class {input.classes} \
		--output {output.virus_types} \
		--meta {params.metadata}
		"""
