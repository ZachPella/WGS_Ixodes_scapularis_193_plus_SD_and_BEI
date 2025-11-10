#!/bin/bash
#SBATCH --mem=50G
#SBATCH --time=4-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --job-name=gatk4_genomicsdbimport
#SBATCH --error=gatk4_genomicsdbimport.%J.err
#SBATCH --output=gatk4_genomicsdbimport.%J.out
#SBATCH --partition=guest
#SBATCH --array=0-19              # Changed from 0-9 to 0-99 for 100 chunks
#SBATCH --cpus-per-task=2

module purge
module load gatk4/4.3

export TILEDB_DISABLE_FILE_LOCKING=1

## Record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

## Set working directory and variables
# NOTE: Updated BASEDIR to match scatter_100
BASEDIR=/work/fauverlab/zachpella/scatter_100
WORKDIR=${BASEDIR}/genotyping
REFERENCEDIR=${BASEDIR}/reference
REFERENCE=masked_ixodes_ref_genome.fasta
SCATTER_COUNT=20                 # Changed from 10 to 100
# The interval list for this specific job will be selected based on the array task ID
CHUNK=$(printf "%04d" ${SLURM_ARRAY_TASK_ID})

# Use the global intervals directory (matching your HaplotypeCaller script)
INTERVAL_LIST_CHUNK="${BASEDIR}/global_intervals/${CHUNK}-scattered.interval_list"

# Define the location where the GVCFs are stored
GVCF_INPUT_DIR=${BASEDIR}/genotyping/scattered_gvcfs

# Create job-specific directories on scratch partition
mkdir -p /scratch/$SLURM_JOBID/tmp
mkdir -p /scratch/$SLURM_JOBID/output

## Get the list of all GVCFs to import for this chunk
GVCF_INPUT=""
GVCF_COUNT=0
echo "Detecting GVCF files for chunk ${CHUNK}..."

for SAMPLE_GVCF in ${GVCF_INPUT_DIR}/*/*.${CHUNK}.g.vcf; do
    if [ -f "$SAMPLE_GVCF" ]; then
        GVCF_INPUT="${GVCF_INPUT} -V ${SAMPLE_GVCF}"
        ((GVCF_COUNT++))
    fi
done

if [ -z "$GVCF_INPUT" ]; then
    echo "Error: No GVCF files found for chunk ${CHUNK} in ${GVCF_INPUT_DIR}. Exiting."
    exit 1
fi
echo "Found a total of ${GVCF_COUNT} GVCF chunks to import for chunk ${CHUNK}."


## Set output path
FINAL_GENOMICSDB_PATH="${WORKDIR}/genomicsdb_chunks/chunk_${CHUNK}"
SCRATCH_GENOMICSDB_PATH="/scratch/$SLURM_JOBID/output/genomicsdb_chunk_${CHUNK}"

## Clean up old directory if it exists
if [ -d "$FINAL_GENOMICSDB_PATH" ]; then
    echo "Removing existing GenomicsDB directory from ${FINAL_GENOMICSDB_PATH}..."
    rm -rf ${FINAL_GENOMICSDB_PATH}
fi

## Create final output directory
mkdir -p "${WORKDIR}/genomicsdb_chunks"

# Run GenomicsDBImport for this chunk
echo "Running GenomicsDBImport on ${GVCF_COUNT} samples for chunk ${CHUNK}..."
gatk --java-options '-Djava.io.tmpdir=/scratch/$SLURM_JOBID -Xms2G -Xmx50G -XX:ParallelGCThreads=2' \
    GenomicsDBImport \
    --genomicsdb-workspace-path ${SCRATCH_GENOMICSDB_PATH} \
    --genomicsdb-shared-posixfs-optimizations true \
    --tmp-dir /scratch/$SLURM_JOBID/tmp \
    ${GVCF_INPUT} \
    -L ${INTERVAL_LIST_CHUNK} \
    --reference ${REFERENCEDIR}/${REFERENCE}

echo "GenomicsDBImport completed. Workspace created on scratch at ${SCRATCH_GENOMICSDB_PATH}"

# The /scratch space is available only while the job is running,
# so the generated output needs to be copied back to the working directory.
echo "Copying GenomicsDB from scratch to ${WORKDIR}..."
cp -r /scratch/$SLURM_JOBID/output/genomicsdb_chunk_${CHUNK}/ ${FINAL_GENOMICSDB_PATH}

echo "Final GenomicsDB workspace for chunk ${CHUNK} located at ${FINAL_GENOMICSDB_PATH}"
echo "Completed at: $(date)"
printf "\n"
