#!/bin/bash
#SBATCH --job-name=mark_dups_array
#SBATCH --time=22:00:00
#SBATCH --output=%x_%j_%a.out  
#SBATCH --error=%x_%j_%a.err    
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH --array=1-9            
#SBATCH --partition=guest       

## --- USER-DEFINED PATHS ---
BASEDIR="/work/fauverlab/zachpella/scatter_20"
INPUTDIR="${BASEDIR}/readgroups"
WORKDIR="${BASEDIR}/dedup"
SAMPLE_LIST="${BASEDIR}/sample_list.txt"

# Create working directory if it doesn't exist
mkdir -p "${WORKDIR}"

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
INPUT_BAM="${INPUTDIR}/${SAMPLE}.rg.sorted.bam"
OUTPUT_BAM="${WORKDIR}/${SAMPLE}.dedup.rg.sorted.bam"
METRICS_FILE="${WORKDIR}/${SAMPLE}.dedup_metrics.txt"
OUTPUT_BAI="${OUTPUT_BAM}.bai" # Expected index file name

## Confirm variables are assigned correctly
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "Input BAM: ${INPUT_BAM}"
echo "Output BAM: ${OUTPUT_BAM}"
echo "Metrics file: ${METRICS_FILE}"
echo "Marking duplicates for ${SAMPLE} at: $(date)"

## Check if input BAM file exists
if [ ! -f "${INPUT_BAM}" ]; then
    echo "✗ Error: Input BAM file not found: ${INPUT_BAM}"
    exit 1
fi

## Load modules
module purge
module load picard/3.0
module load samtools/1.20

# --- MAIN PROCESSING (Picard MarkDuplicates) ---

echo "Marking duplicates in ${INPUT_BAM}..."
# Using the -Xmx120g flag inside the picard call to explicitly allocate JVM memory.
picard -Xmx120g MarkDuplicates \
    I="${INPUT_BAM}" \
    O="${OUTPUT_BAM}" \
    M="${METRICS_FILE}" \
    REMOVE_DUPLICATES=true \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
    CREATE_INDEX=true

## Verify output file and index were created
if [[ -f "${OUTPUT_BAM}" && -s "${OUTPUT_BAM}" && -f "${OUTPUT_BAI}" ]]; then
    echo "✓ Duplicate removal completed successfully for ${SAMPLE}"
    echo "  Output BAM: ${OUTPUT_BAM}"
    echo "  Metrics file: ${METRICS_FILE}"
    echo "  Index (.bai) created successfully."
else
    echo "✗ Error: Deduplicated BAM file or index not created for ${SAMPLE}"
    exit 1
fi

echo "Completed at: $(date)"
