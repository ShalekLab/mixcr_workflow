# By jgatter [at] broadinstitute.org, created October 2019
# A publicly available WDL workflow made by Shalek Lab for the mixcr tool.
# FULL DISCLOSURE: many optional parameters remain untested, contact me with bug reports or feature requests
# mixcr tool made by the mixcr team
# mixcr documentation: https://mixcr.readthedocs.io/en/master/install.html
# ------------------------------------------------------------------------------------------------------------------------------------------
# Snapshot 21 - Oct 22nd, 2019
# Labeled optional, task-specific parameters with their respective task instead of the mixcr workflow (Now easier to interpret each variable)
# Made minimal_clone_fraction type String? and minimal_clone_count type Int?
# ------------------------------------------------------------------------------------------------------------------------------------------
# Current expected task run times and costs: Based on two FASTQ files (R1 & R2) each 6.8 GB in size
# Need at least 8GB memory
# PARAMETERS													| Al ETA| ACTUAL RUN TIMES Al, As, Ex, TOTAL	| TOTAL COST
# For task_memory= 8GB number_cpu_threads= 4 max_heap_size=  2G | 5h23m | 5h18m+6m, Fail(snap13heap)			| $0.23
# For task_memory=32GB number_cpu_threads= 8 max_heap_size=  2G | 2h36m | 2h31m+13m, Fail(snap13heap)			| $0.26
# For task_memory=32GB number_cpu_threads= 4 max_heap_size=  2G | 4h04m | Aborted(lazy)							| N/A
# For task_memory=16GB number_cpu_threads= 8 max_heap_size= 12G | 3h01m | 2h50m+24m, 1h57m, 6m, 5h27m			| $0.40
# For task_memory=16GB number_cpu_threads= 8 max_heap_size=3.2G | 2h50m | 2h48m+18m, 13h+Aborted				| $0.74
# For task_memory=16GB number_cpu_threads= 8 max_heap_size=  2G | 3h01m | 2h54m+14m, 13h+Aborted				| $0.74
# For task_memory=16GB number_cpu_threads= 8 max_heap_size= 16G | 2h56m | 2h52m+16m, 1h47m, 7m, 5h07m			| $0.38
# For task_memory=32GB number_cpu_threads=16 max_heap_size= 28G | 1h21m | 1h17m+13m, 1h10m, 5m, 2h54m			| $0.40
# For task_memory=32GB number_cpu_threads=16 max_heap_size= 32G | 1h21m | 1h19m+17m, 2h06m, 6m, 3h56m			| $0.53 (1 align retry)
# For task_memory=32GB number_cpu_threads=16 max_heap_size= 24G | 1h20m | 1h19m+21m, 1h19m, 6m, 3h03m 			| $0.41
# For task_memory=32GB number_cpu_threads=16 max_heap_size= 20G | 1h19m | 1h17m+10m, 1h18m, 5m, 2h50m			| $1.38 (2 align retries) 
# For task_memory=32GB number_cpu_threads=16 max_heap_size= 16G | 1h16m	| 1h16m+14m, 1h26m, 5m, 3h06m			| $0.44
# ------------------------------------------------------------------------------------------------------------------------------------------

version 1.0 # WDL Version

workflow mixcr {
	input { # GLOBAL MIXCR WORKFLOW VARIABLES
		# ALL TASKS
		String version = "3.0.10" # tagged dockerfile found at https://cloud.docker.com/u/shaleklab/repository/docker/shaleklab/mixcr
		String bucket
		String output_path
		String alignments_basename = "alignments"
		String clones_basename = "clones"
		Int preemptible = 2
		String zones = "us-east1-d us-west1-a us-west1-b"
		String disks = "local-disk 32 SSD"
		String task_memory = "32GB" # At least 16GB is recommended

		# ALIGN
		File R1_fastq
		File? R2_fastq # OPTIONAL
		String species # hsa for Homo sapiens, mma for Mus musculus, and more (see documentation)

		# ALIGN AND ASSEMBLE
		Int number_cpu_threads = 16 # Can try up to 32

		# ASSEMBLE AND EXPORT
		String init_heap_size = "64M"
		String max_heap_size = "16G"
	}
	call align {
		input:
			bucket_slash=sub(bucket, "/+$", "") + '/',
			output_path_slash=sub(output_path, "/+$", '') + '/',
			version=version,
			species=species,
			R1_fastq=R1_fastq,
			R2_fastq=R2_fastq,
			alignments_basename=sub(sub(alignments_basename, "(\.txt)+$", ''), "(\.vdjca)+$", ''),
			zones=zones,
			preemptible=preemptible,
			number_cpu_threads=number_cpu_threads,
			task_memory=task_memory,
			disks=disks
	}
	call assemble {
		input:
			bucket_slash=sub(bucket, "/+$", "") + '/',
			output_path_slash=sub(output_path, "/+$", '') + '/',
			version=version,
			init_heap_size=init_heap_size,
			max_heap_size=max_heap_size,
			alignments_binary=align.alignments_binary,
			clones_basename=sub(sub(clones_basename, "(\.txt)+$", ''), "(\.clns)+$", ''),
			alignments_binary=align.alignments_binary,
			number_cpu_threads=number_cpu_threads,
			zones=zones,
			preemptible=preemptible,
			task_memory=task_memory,
			disks=disks
	}
	call export {
		input:
			bucket_slash=sub(bucket, "/+$", "") + '/',
			output_path_slash=sub(output_path, "/+$", '') + '/',
			version=version,
			clones_basename=sub(sub(clones_basename, "(\.txt)+$", ''), "(\.clns)+$", ''),
			clones_binary=assemble.clones_binary,
			zones=zones,
			preemptible=preemptible,
			task_memory=task_memory,
			init_heap_size=init_heap_size,
			max_heap_size=max_heap_size,
			disks=disks
	}
	
	output {
		File assemble_clones_report = assemble.assemble_clones_report
		File clones = export.clones
		File alignment_report = align.align_report
	}
}

task align {
	input {
		String bucket_slash
		String output_path_slash
		String version
		Int number_cpu_threads
		Int preemptible
		String zones
		String task_memory
		String disks
		File R1_fastq
		File? R2_fastq
		String species
		String alignments_basename
		
		File? library
		String? parameter_name
		Int? number_reads_limit
		Boolean? save_reads
		Boolean? no_merge_paired_reads
		Boolean? write_unaligned_R1
		Boolean? write_unaligned_R2
		String? override_v_parameter_equals_value
		String? override_d_parameter_equals_value
		String? override_j_parameter_equals_value
		String? override_c_parameter_equals_value
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr align \
			--species ~{species} \
			--report ~{alignments_basename}_report.txt \
			--verbose \
			~{"--parameters " + parameter_name} \
			~{"--threads " + number_cpu_threads} \
			~{"--limit " + number_reads_limit} \
			--library ~{default="imgt.201918-4.sv5" library} \
			~{true="--save-reads " false='' save_reads} \
			~{true="--no-merge " false='' no_merge_paired_reads} \
			~{true="--not-aligned-R1 " false='' write_unaligned_R1} \
			~{true="--not-aligned-R2 " false='' write_unaligned_R2} \
			~{"-OvParameters."+override_v_parameter_equals_value} \
			~{"-OdParameters."+override_d_parameter_equals_value} \
			~{"-OjParameters."+override_j_parameter_equals_value} \
			~{"-OcParameters."+override_c_parameter_equals_value} \
			~{R1_fastq} ~{R2_fastq} ~{alignments_basename}.vdjca
		
		gsutil -m cp ~{alignments_basename}_report.txt ~{bucket_slash}~{output_path_slash} \
		& gsutil -m cp ~{alignments_basename}.vdjca ~{bucket_slash}~{output_path_slash}
	}
	output {
		File alignments_binary = alignments_basename+".vdjca"
		File align_report = alignments_basename+"_report.txt"
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
		preemptible: preemptible
		zones: "~{zones}"
		memory: "~{task_memory}"
		cpu: number_cpu_threads
		disks: "~{disks}"
	}
}

task assemble {
	input {
		String bucket_slash
		String output_path_slash
		String version
		Int number_cpu_threads
		String init_heap_size
		String max_heap_size
		Int preemptible
		String zones
		String task_memory
		String disks
		File alignments_binary
		String clones_basename

		Int? bad_quality_threshold
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr ~{"-Xms"+init_heap_size} ~{"-Xmx"+max_heap_size} assemble \
			--report ~{clones_basename}_report.txt \
			~{"--threads " + number_cpu_threads } \
			~{"-ObadQualityThreshold="+bad_quality_threshold} \
			~{alignments_binary} ~{clones_basename}.clns

		gsutil -m cp ~{clones_basename}_report.txt ~{bucket_slash}~{output_path_slash} \
		& gsutil -m cp ~{clones_basename}.clns ~{bucket_slash}~{output_path_slash} 
	}
	output {
		File clones_binary = clones_basename+".clns"
		File assemble_clones_report = clones_basename+"_report.txt"
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
		preemptible: preemptible
		zones: "~{zones}"
		memory: "~{task_memory}"
		cpu: number_cpu_threads
		disks: "~{disks}"
	}
}

task export {
	input {
		String bucket_slash
		String output_path_slash
		String version
		String init_heap_size
		String max_heap_size
		Int preemptible
		String zones
		String task_memory
		String disks
		File clones_binary
		String clones_basename

		String? chains
		String? preset
		File? preset_file
		Boolean? print_with_spaces
		Boolean? filter_out_of_frames
		Boolean? filter_stops
		Int? minimal_clone_count
		String? minimal_clone_fraction
	}
	command {
		set -e
		export TMPDIR=/tmp

		mixcr ~{"-Xms"+init_heap_size} ~{"-Xmx"+max_heap_size} exportClones \
			~{"--chains " + chains} \
			~{"--preset " + preset} \
			~{"--preset-file " + preset_file} \
			~{true="--with-spaces " false='' print_with_spaces} \
			~{true="--filter-out-of-frames " false='' filter_out_of_frames} \
			~{true="--filter-stops " false='' filter_stops} \
			~{"--minimal-clone-count " + minimal_clone_count} \
			~{"--minimal-clone-fraction " + minimal_clone_fraction} \
			~{clones_binary} ~{clones_basename}.txt

		gsutil -m cp ~{clones_basename}.txt ~{bucket_slash}~{output_path_slash}
	}
	output {
		File clones = clones_basename+".txt"
	}
	runtime {
		docker: "shaleklab/mixcr:~{version}"
		preemptible: preemptible
		zones: "~{zones}"
		memory: "~{task_memory}"
		disks: "~{disks}"
	}
}