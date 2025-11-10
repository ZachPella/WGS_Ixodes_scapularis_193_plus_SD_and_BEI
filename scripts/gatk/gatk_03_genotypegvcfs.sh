#!/bin/bash
#SBATCH --job-name=genotype_gvcfs_ticks_na
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=200G
#SBATCH --time=7-00:00:00
#SBATCH --array=0-19              
#SBATCH --error=%x_%A_%a.err
#SBATCH --output=%x_%A_%a.out

module purge
module load gatk4/4.6

# Set up working directories and variables
START_DIR=$(pwd)

# --- Updated to match scatter_100 structure ---
BASEDIR=/work/fauverlab/zachpella/scatter_100
WORKDIR=${BASEDIR}/genotyping
REFERENCEDIR=${BASEDIR}/reference
REFERENCE=masked_ixodes_ref_genome.fasta

# Use the global intervals directory
INTERVAL_ROOT_DIR=${BASEDIR}/global_intervals

# --------------------------------------------------

# The interval list and GenomicsDB workspace for this specific job will be selected based on the array task ID
CHUNK=$(printf "%04d" ${SLURM_ARRAY_TASK_ID})

# **CRITICAL PATHS**
INTERVAL_LIST_CHUNK="${INTERVAL_ROOT_DIR}/${CHUNK}-scattered.interval_list"
GENOMICSDB_CHUNK_PATH="${WORKDIR}/genomicsdb_chunks/chunk_${CHUNK}"

# Set output paths
FINAL_OUTPUT_DIR=${WORKDIR}/genotyped_vcfs
OUTPUT_VCF_NAME="chunk_${CHUNK}_genotyped.vcf.gz"

# Create job-specific directories on scratch
mkdir -p /scratch/$SLURM_JOBID/tmp
mkdir -p /scratch/$SLURM_JOBID/output

# ----------------------------------------------------------------------
# Record relevant job info
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"
echo "Chunk: ${CHUNK}"
echo "Interval List: ${INTERVAL_LIST_CHUNK}"
echo "GenomicsDB Path: ${GENOMICSDB_CHUNK_PATH}"
printf "\n"
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Copy required inputs to scratch
# ----------------------------------------------------------------------
echo "Copying inputs to scratch for chunk ${CHUNK}..."

# 1. Reference files
cp "${REFERENCEDIR}/${REFERENCE}" /scratch/$SLURM_JOBID/
cp "${REFERENCEDIR}/${REFERENCE}.fai" /scratch/$SLURM_JOBID/
cp "${REFERENCEDIR}/${REFERENCE%.*}.dict" /scratch/$SLURM_JOBID/

# 2. Interval List
if [ -f "${INTERVAL_LIST_CHUNK}" ]; then
    cp "${INTERVAL_LIST_CHUNK}" /scratch/$SLURM_JOBID/
else
    echo "Error: Interval list not found at ${INTERVAL_LIST_CHUNK}. Exiting."
    exit 1
fi

# 3. GenomicsDB Chunk (The largest file transfer)
if [ -d "${GENOMICSDB_CHUNK_PATH}" ]; then
    # Note: We copy the whole directory and rename it to the simple chunk name on scratch
    cp -r "${GENOMICSDB_CHUNK_PATH}" "/scratch/$SLURM_JOBID/chunk_${CHUNK}"
else
    echo "Error: GenomicsDB chunk not found at ${GENOMICSDB_CHUNK_PATH}. Did GenomicsDBImport run successfully?"
    exit 1
fi
echo "Input files copied to scratch."

# ----------------------------------------------------------------------
# Run GenotypeGVCFs for the current chunk
# ----------------------------------------------------------------------
# Use basename to get just the filename of the interval list on scratch
INTERVAL_FILE_SCRATCH=$(basename "${INTERVAL_LIST_CHUNK}")

echo "Starting GenotypeGVCFs for chunk ${CHUNK}..."
gatk --java-options "-Djava.io.tmpdir=/scratch/$SLURM_JOBID/tmp -Xms2G -Xmx180G -XX:ParallelGCThreads=2" \
    GenotypeGVCFs \
    -R /scratch/$SLURM_JOBID/${REFERENCE} \
    -V "gendb:///scratch/$SLURM_JOBID/chunk_${CHUNK}" \
    -O /scratch/$SLURM_JOBID/output/"${OUTPUT_VCF_NAME}" \
    -L /scratch/$SLURM_JOBID/${INTERVAL_FILE_SCRATCH}

echo "GenotypeGVCFs completed."

# ----------------------------------------------------------------------
# Copy results back and Clean up
# ----------------------------------------------------------------------
echo "Copying final VCF and index to ${FINAL_OUTPUT_DIR} for chunk ${CHUNK}..."
mkdir -p "${FINAL_OUTPUT_DIR}"
# Copy VCF and its index (.tbi or .idx) back
cp /scratch/$SLURM_JOBID/output/"${OUTPUT_VCF_NAME}" "${FINAL_OUTPUT_DIR}/"
# Note: GenotypeGVCFs typically outputs a .tbi index for VCF.GZ
cp /scratch/$SLURM_JOBID/output/"${OUTPUT_VCF_NAME}".{tbi} "${FINAL_OUTPUT_DIR}/" 2>/dev/null

echo "Cleaning up scratch directory: /scratch/${SLURM_JOBID}"
rm -rf /scratch/${SLURM_JOBID}

echo "Job finished for chunk ${CHUNK}."
printf "\n"
