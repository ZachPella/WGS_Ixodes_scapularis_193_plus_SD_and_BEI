#!/bin/bash
#SBATCH --job-name=bwa_alignment
#SBATCH --time=6-00:00:00
#SBATCH --output=%x_%j_%a.out  # Added %a for array job output
#SBATCH --error=%x_%j_%a.err    # Added %a for array job errors
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH --mem=60G
#SBATCH --array=1-9             # Must match the number of samples in your list
#SBATCH --partition=guest       # Changed partition to 'guest'

## --- USER-DEFINED PATHS ---
BASEDIR="/work/fauverlab/zachpella/scatter_20"
SAMPLE_LIST="${BASEDIR}/sample_list.txt"
READSDIR="${BASEDIR}/trimmed_reads"
REFERENCEDIR="${BASEDIR}/reference"
WORKDIR="${BASEDIR}/sam_files"

# Reference file name
REFERENCE="masked_ixodes_ref_genome.fasta"

# Create output directory
mkdir -p ${WORKDIR}

# --- ARRAY LOGIC ---
if [ ! -f "${SAMPLE_LIST}" ]; then
    echo "Error: Sample list file not found: ${SAMPLE_LIST}"
    exit 1
fi

# Get sample name from the list based on the array task ID
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SAMPLE_LIST}")

if [[ -z "$SAMPLE" ]]; then
    echo "Error: Empty sample name for array task ${SLURM_ARRAY_TASK_ID}. Check SAMPLE_LIST file."
    exit 1
fi

## --- FILE VARIABLE ASSIGNMENTS ---
READS1_TRIMMED="${SAMPLE}_R1_trimmed.fastq.gz"
READS2_TRIMMED="${SAMPLE}_R2_trimmed.fastq.gz"

## Confirm variables are assigned correctly
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "SAMPLE NAME: ${SAMPLE}"
echo "REFERENCE: ${REFERENCEDIR}/${REFERENCE}"
echo "Starting bwa mem for ${SAMPLE} at: $(date)"
printf "\n"

## Check if input files exist
if [ ! -f "${READSDIR}/${READS1_TRIMMED}" ] || [ ! -f "${READSDIR}/${READS2_TRIMMED}" ]; then
    echo "✗ Error: Trimmed read files not found:"
    echo "  ${READSDIR}/${READS1_TRIMMED}"
    exit 1
fi

## Check if reference exists
if [ ! -f "${REFERENCEDIR}/${REFERENCE}" ]; then
    echo "✗ Error: Reference file not found: ${REFERENCEDIR}/${REFERENCE}"
    exit 1
fi

## Load modules
module purge
module load bwa/0.7

## Run BWA MEM alignment
echo "Running BWA MEM alignment..."
# BWA output is directed straight to the SAM file in the WORKDIR
bwa mem \
    -t 16 \
    -M \
    "${REFERENCEDIR}/${REFERENCE}" \
    "${READSDIR}/${READS1_TRIMMED}" "${READSDIR}/${READS2_TRIMMED}" \
    > "${WORKDIR}/${SAMPLE}.sam"

## Verify output file was created
if [[ -f "${WORKDIR}/${SAMPLE}.sam" && -s "${WORKDIR}/${SAMPLE}.sam" ]]; then
    echo "✓ BWA alignment completed successfully for ${SAMPLE}"
    echo "  Output SAM: ${WORKDIR}/${SAMPLE}.sam"
else
    echo "✗ Error: SAM file not created or is empty for ${SAMPLE}"
    exit 1
fi

echo "Completed at: $(date)"
