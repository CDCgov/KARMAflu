################################################################################
# Matthew Wersebe
# Influenza Division, CDC
# KARMAflu
# 06/02/2025
## KARMAflu sequence quality control workflow.
##
################################################################################
singularity: 'library://uee9/laiv_finder/laiv_finder:v0.0.0'

configfile: 'quality_control_config.yaml'

rule all:
        input:
                quality_controlled = expand("{today}/{now}/input/{today}_{now}_DAIS-ribosome_qc.genome", today = config['today'], now = config['now'])
rule qc:
	params:
		refs_dir = config['refs']
	input:
		genome_file = config['infile']
	output:
		quality_controlled = "{today}/{now}/input/{today}_{now}_DAIS-ribosome_qc.genome",
		qc_report = "{today}/{now}/input/{today}_{now}_DAIS-ribosome_qc_report.csv"
	shell:
		"""
		./scripts/kf_qc.R \
		--input {input.genome_file} \
		--output {output.quality_controlled} \
		--report {output.qc_report} \
		--refsdir {params.refs_dir}
		"""
