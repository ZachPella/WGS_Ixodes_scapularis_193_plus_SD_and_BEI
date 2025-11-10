#!/bin/bash
#SBATCH --job-name=add_read_groups_array
#SBATCH --time=2-00:00:00
#SBATCH --output=%x_%j_%a.out
#SBATCH --error=%x_%j_%a.err
#SBATCH --nodes=1
#SBATCH --mem=35G
#SBATCH --array=1-9
#SBATCH --partition=guest       # Using 'guest' partition

## --- USER-DEFINED PATHS ---
BASEDIR="/work/fauverlab/zachpella/scatter_100"
INPUTDIR="${BASEDIR}/bam_files"
WORKDIR="${BASEDIR}/readgroups"
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
INPUT_BAM="${INPUTDIR}/${SAMPLE}.sorted.bam"
OUTPUT_BAM="${WORKDIR}/${SAMPLE}.rg.sorted.bam"
OUTPUT_BAI="${WORKDIR}/${SAMPLE}.rg.sorted.bai"

## Confirm variables are assigned correctly
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "Input BAM: ${INPUT_BAM}"
echo "Output BAM: ${OUTPUT_BAM}"
echo "Adding read groups for ${SAMPLE} at: $(date)"
printf "\n"

## Check if input BAM file exists
if [ ! -f "${INPUT_BAM}" ]; then
    echo "✗ Error: Input BAM file not found: ${INPUT_BAM}"
    exit 1
fi

## Load modules
module purge
module load picard
module load samtools/1.20

# --- MAIN PROCESSING (Picard AddOrReplaceReadGroups) ---

echo "Adding read groups using Picard..."
# RGID is SAMPLE for uniqueness
# RGLB (Library) and RGPU (Platform Unit) are set to FC1 for flowcell consistency
picard AddOrReplaceReadGroups \
    I="${INPUT_BAM}" \
    O="${OUTPUT_BAM}" \
    RGID="${SAMPLE}" \
    RGLB=FC1 \
    RGPL=ILLUMINA \
    RGPU=FC1 \
    RGSM="${SAMPLE}" \
    SORT_ORDER=coordinate

## Verify output file was created
if [[ -f "${OUTPUT_BAM}" && -s "${OUTPUT_BAM}" ]]; then
    echo "✓ Read groups added successfully for ${SAMPLE}"

    # Index the new BAM file using samtools
    echo "Indexing new BAM file..."
    samtools index "${OUTPUT_BAM}"

    if [ -f "${OUTPUT_BAI}" ]; then
        echo "✓ Index (.bai) created successfully."
    else
        echo "✗ Error: Index (.bai) file not created."
    fi
else
    echo "✗ Error: Read group BAM file not created or is empty for ${SAMPLE}"
    exit 1
fi

echo "Completed at: $(date)"
