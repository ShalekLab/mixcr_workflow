version 1.0

workflow mixcr {

	String version = "latest"
	String bucket
	String output_path

	#Boolean run_analyze_amplicons

	String species # hs for Homo sapiens
	String? align_report_filename = "align_report"
	String? parameter_name = "default"
	Int? number_cpu_threads
	String? library = "default"
	Boolean save_reads = false
	Boolean no_merge_paired_reads = false
	Boolean write_unaligned_R1 = false
	Boolean write_unaligned_R2 = false
	#String? override_parameter_equals_value

	File R1_fastq
	File? R2_fastq
	String output_filename = "alignments"

	String clones_filename = "clones"
	String assemble_report_filename = "assemble_report"


	call align {
		input:
			version=version,
			report_filename=align_report_name,
			parameter_name=parameter_name,

			R1_fastq=R1_fastq,
			R2_fastq=R2_fastq,
			alignments_filename=sub(sub(alignments_filename, ".txt+$", ''), ".vdjca+$", '')

	}
	call assemble {
		alignments=align.alignments,
		clones_filename=sub(sub(clones_filename, ".txt+$", ''), ".clns+$", '')
	}
	call export {
		clones_filename=sub(sub(clones_filename, ".txt+$", ''), ".clns+$", '')
	}
	
	output {
		File assemble_clones_report = assemble.assemble_clones_report
		File clones = export.clones
		File alignment_report = align.align_report
		File alignments = export.alignments
	}
}

task align {
	input {
		String version
		String report_filename
		String? parameter_name
		Int? 
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr align \
			--species ~{species} \
			--report ~{report_filename} \
			~{"--parameters " parameter_name} \
			~{"--threads " number_cpu_threads} \
			~{"--limit " number_reads_limit} \
			~{"--library " libary} \
			~{true="--save-reads " false='' save_reads} \
			~{true="--no-merge " false='' no_merge_paired_reads} \
			~{true="--not-aligned-R1 " false='' write_unaligned_R1} \
			~{true="--not-aligned-R2 " false='' write_unaligned_R2} \
			#~{"-O" override_parameter_equals_value} \
			~{input_R1} ~{input_R2} ~{alignments_filename}.vdjca
		
		if [ -e ~{report_filename} ]; then gsutil -m cp report_filename ~{bucket_slash}~{output_path_slash}; fi
		gsutil -m cp ~{alignments_filename}.vdjca ~{bucket_slash}~{output_path_slash} 
	}
	output {
		File alignments_binary = alignments_filename+".vdjca"
		File align_report = report_filename
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
	}
}

task assemble {
	input {
		File alignments_binary
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr assemble \
			--report ~{report_filename} \
			~{"--threads " number_cpu_threads } \
			#--write-alignments \
			#~{"-O" override_parameter_equals_value} \
			~{alignments_binary} ~{clones_filename}.clns

		gsutil -m cp report_filename ~{bucket_slash}~{output_path_slash} \
		& gsutil -m cp ~{clones_filename}.clns ~{bucket_slash}~{output_path_slash} 
	}
	output {
		File clones_binary = clones_filename+".clns"
		File assemble_clones_report = report_filename
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
	}
}

task export {
	input {
		File? preset_file
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr exportClones \
			~{"--chains " chains} \
			~{"--preset " preset} \
			~{"--preset-file " preset_file} \
			~{true="--with-spaces " false='' print_with_spaces} \
			~{"--limit " number_records_limit}
			~{"--filter-out-of-frames " filter_out_of_frames} \
			~{"--filter-stops "	filter_stops} \
			~{"--minimal-clone-count " minimal_clone_count} \
			~{"--minimal-clone-fraction " minimal_clone_fraction} \
			~{clones_binary} ~{clones_filename}.txt \
		& mixcr exportAlignments \
			~{"--chains " chains} \
			~{"--preset " preset} \
			~{"--preset-file " preset_file} \
			~{true="--with-spaces " false='' print_with_spaces} \
			~{"--limit " number_records_limit} \
			~{alignments_binary} ~{alignments_filename}.txt

		gsutil -m cp ~{clones_filename}.txt ~{bucket_slash}~{output_path_slash} \
		& gsutil -m cp ~{alignments_filename}.txt ~{bucket_slash}~{output_path_slash}
	}
	output {
		File clones = clones_filename+".txt"
		File alignments = alignments_filename+".txt"
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
	}
}
