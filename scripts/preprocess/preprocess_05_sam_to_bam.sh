#!/bin/bash
#SBATCH --job-name=sam_to_bam_array
#SBATCH --time=4-00:00:00
#SBATCH --output=%x_%j_%a.out  # Added %a for array job output
#SBATCH --error=%x_%j_%a.err    # Added %a for array job errors
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=50G
#SBATCH --array=1-9             # Must match the number of samples in your list
#SBATCH --partition=guest       # Changed partition to 'guest'

## --- USER-DEFINED PATHS ---
BASEDIR="/work/fauverlab/zachpella/scatter_100"
SAMDIR="${BASEDIR}/sam_files"
WORKDIR="${BASEDIR}/bam_files"
REFERENCEDIR="${BASEDIR}/reference"
SAMPLE_LIST="${BASEDIR}/sample_list.txt"

# Reference file name
REFERENCE="masked_ixodes_ref_genome.fasta"
# Target BED file for coverage stats (created from the reference)
TARGETS="${REFERENCEDIR}/${REFERENCE}.bed"

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
SAM_INPUT="${SAMDIR}/${SAMPLE}.sam"
BAM_UNSORTED="${WORKDIR}/${SAMPLE}.bam"
BAM_SORTED="${WORKDIR}/${SAMPLE}.sorted.bam"
BAM_MAPPED="${WORKDIR}/${SAMPLE}.sorted.mapped.bam"


## Confirm variables are assigned correctly
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "SAM Input File: ${SAM_INPUT}"
echo "Starting SAM-to-BAM conversion and stats summaries for ${SAMPLE}..."
printf "\n"

## Check if SAM file exists
if [ ! -f "${SAM_INPUT}" ]; then
    echo "✗ Error: SAM file not found: ${SAM_INPUT}"
    exit 1
fi

## Load modules
module purge
module load samtools/1.20

# --- MAIN PROCESSING (SAM to BAM, Sort, Index) ---

echo "Converting SAM to unsorted BAM..."
samtools view -@ 2 -b "${SAM_INPUT}" > "${BAM_UNSORTED}"

echo "Sorting BAM file..."
# Use 16G of memory for sorting, reserving the rest for other processes
samtools sort -@ 2 -m 16G "${BAM_UNSORTED}" -o "${BAM_SORTED}" -T "${WORKDIR}/${SAMPLE}.reads.tmp"

# Only remove SAM and unsorted BAM files if sorted BAM was successful and non-empty
if [ -s "${BAM_SORTED}" ]; then
    rm "${SAM_INPUT}"
    rm "${BAM_UNSORTED}"
    echo "✓ SAM-to-BAM conversion successful for ${SAMPLE}. Temporary files cleaned."
else
    echo "✗ Error: Sorted BAM file is empty or conversion failed. Keeping intermediate files for debugging."
    exit 1
fi

# Index the main sorted BAM file immediately
samtools index "${BAM_SORTED}"

# --- STATS GENERATION ---
echo "Generating statistics..."

# 1. samtools flagstat (Basic mapping summary)
samtools flagstat "${BAM_SORTED}" > "${WORKDIR}/flagstats.${SAMPLE}.out"

# 2. samtools stats (Detailed coverage and quality stats)
# NOTE: Requires a BED file for targeted coverage. Assuming TARGETS file exists.
if [ -f "${TARGETS}" ]; then
    # Run samtools stats for coverage thresholds 5x and 10x
    for cov in 5 10; do
        samtools stats -t "${TARGETS}" --cov-threshold ${cov} "${BAM_SORTED}" > "${WORKDIR}/stats.${cov}x.${SAMPLE}.out"
    done
else
    # Run samtools stats without targets file if it's missing (general genome stats)
    echo "Warning: Target BED file not found. Running samtools stats without coverage threshold."
    samtools stats "${BAM_SORTED}" > "${WORKDIR}/stats.general.${SAMPLE}.out"
fi

# 3. Calculate average depth of coverage (DOC)
samtools depth -a "${BAM_SORTED}" > "${WORKDIR}/${SAMPLE}.depth"
AVGDOC=$(awk '{ total += $3; count++ } END { print total/count }' "${WORKDIR}/${SAMPLE}.depth")
echo "Average depth of coverage: ${AVGDOC}" > "${WORKDIR}/averageDOC.${SAMPLE}.out"

# 4. Calculate by-contig coverage stats and histogram
samtools coverage -o "${WORKDIR}/coverage.${SAMPLE}.out" "${BAM_SORTED}"
samtools coverage --plot-depth -o "${WORKDIR}/hist.coverage.${SAMPLE}.out" "${BAM_SORTED}"

# 5. Generate a sorted BAM file with only mapped reads
# -F 4 excludes unmapped reads
samtools view -@ 2 -b -F 4 "${BAM_SORTED}" > "${BAM_MAPPED}"

# 6. Index the final mapped BAM file
samtools index "${BAM_MAPPED}"

# --- FINAL CONFIRMATION ---
echo "✓ Processing for ${SAMPLE} completed successfully."
echo "Output files are in: ${WORKDIR}"
printf "\n"
