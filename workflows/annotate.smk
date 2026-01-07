################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025
## Optional Snakemake workflow to create DAIS-ribosome GEN file
##
################################################################################

singularity: 'docker://cdcgov/dais-ribosome:latest'

configfile: 'annotate_config.ymal'

today = config['today']
now = config['now']

rule all:
	input:
		annotation = expand("{today}/{now}/input/{today}_{now}_DAIS-ribosome.genome", today = config['today'], now = config['now'])

rule annotate:
	params:
		prefix = "{today}/{now}/input/{today}_{now}_DAIS-ribosome"
	input:
		fasta = config['infile']
	output:
		annotation = "{today}/{now}/input/{today}_{now}_DAIS-ribosome.genome"
	threads: config['cores']
	shell:
		"""
		ribosome \
		--module INFLUENZA \
		{input.fasta} \
		{params.prefix}.seq \
		{params.prefix}.ins \
		{params.prefix}.idel \
		{output.annotation}
		"""
