#!/bin/bash
#SBATCH --job-name=fastp_trimming
#SBATCH --time=1-06:00:00
#SBATCH --output=%x_%j_%a.out
#SBATCH --error=%x_%j_%a.err
#SBATCH --ntasks=1
#SBATCH --mem=15G
#SBATCH --cpus-per-task=4
#SBATCH --array=1-9
#SBATCH --partition=guest

BASEDIR="/work/fauverlab/zachpella/scatter_100"
READSDIR="${BASEDIR}/concatenated_reads"
WORKDIR="${BASEDIR}/trimmed_reads"
SAMPLE_LIST="${BASEDIR}/sample_list.txt"

# Create output directory
mkdir -p "${WORKDIR}"

# --- ARRAY LOGIC ---
if [ ! -f "${SAMPLE_LIST}" ]; then
    echo "Error: Sample list file not found: ${SAMPLE_LIST}"
    exit 1
fi

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SAMPLE_LIST}")

if [[ -z "$SAMPLE" ]]; then
    echo "Error: Sample name is empty for array task ${SLURM_ARRAY_TASK_ID}. Check SAMPLE_LIST file."
    exit 1
fi

READS1="${SAMPLE}_R1_merged.fastq.gz"
READS2="${SAMPLE}_R2_merged.fastq.gz"
READS1_TRIMMED="${SAMPLE}_R1_trimmed.fastq.gz"
READS2_TRIMMED="${SAMPLE}_R2_trimmed.fastq.gz"

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing Sample: ${SAMPLE}"
echo "Forward Reads Input: ${READSDIR}/${READS1}"
echo "Starting fastp at: $(date)"

# --- EXECUTION ---
if [ ! -f "${READSDIR}/${READS1}" ] || [ ! -f "${READSDIR}/${READS2}" ]; then
    echo "✗ Error: Concatenated input files not found for ${SAMPLE}"
    exit 1
fi

module purge
module load fastp

cd "${WORKDIR}"
fastp \
    --in1 "${READSDIR}/${READS1}" \
    --in2 "${READSDIR}/${READS2}" \
    --out1 "${READS1_TRIMMED}" \
    --out2 "${READS2_TRIMMED}" \
    -l 50 \
    -h "${SAMPLE}.fastp.html" \
    -j "${SAMPLE}.fastp.json" \
    --thread 4

# --- VERIFICATION ---
if [[ -f "${WORKDIR}/${READS1_TRIMMED}" && -f "${WORKDIR}/${READS2_TRIMMED}" ]]; then
    echo "✓ fastp completed successfully for ${SAMPLE}"
else
    echo "✗ Error: fastp output files not created for ${SAMPLE}"
    exit 1
fi

echo "Completed at: $(date)"
