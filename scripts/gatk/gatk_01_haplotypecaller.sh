#!/bin/bash
#SBATCH --job-name=haplotype_scatter_combined
#SBATCH --time=1-00:00:00        # 1 day
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=20       # 20 chunks × 1 cpu/chunk
#SBATCH --mem=200G               # Keeping at 300G for buffer
#SBATCH --array=1-193            # Launch all 193 samples concurrently
#SBATCH --partition=guest

## Record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

## Set directories and variables
BASEDIR=/work/fauverlab/zachpella/scatter_100
WORKDIR=${BASEDIR}/genotyping
REFERENCEDIR=${BASEDIR}/reference
REFERENCE=masked_ixodes_ref_genome.fasta

# Global directory where the intervals were split ONE TIME (must be pre-run)
GLOBAL_INTERVAL_DIR=${BASEDIR}/global_intervals

SAMPLE_LIST=${BASEDIR}/sample_list.txt
BAMDIR=${BASEDIR}/dedup
SCATTER_COUNT=20                  # 20 genomic chunks per sample
CPUS_PER_CHUNK=1
MEM_PER_CHUNK=3  # in GB (3G per GATK job)

## --- Error checking and validation ---
if [ ! -f "$SAMPLE_LIST" ]; then
    echo "Error: Sample list file not found: $SAMPLE_LIST"
    exit 1
fi

TOTAL_SAMPLES=$(wc -l < "$SAMPLE_LIST")
if [ ${SLURM_ARRAY_TASK_ID} -gt ${TOTAL_SAMPLES} ]; then
    echo "Error: Array task ID ${SLURM_ARRAY_TASK_ID} exceeds number of samples (${TOTAL_SAMPLES})"
    exit 1
fi

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
if [[ -z "$SAMPLE" ]]; then
    echo "Error: Empty sample name for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

## Create sample-specific directories
mkdir -p ${WORKDIR}/scattered_gvcfs/${SAMPLE}

## Find BAM file
if [ -f "${BAMDIR}/${SAMPLE}.dedup.rg.sorted.bam" ]; then
    BAM_FILE="${BAMDIR}/${SAMPLE}.dedup.rg.sorted.bam"
    echo "Found BAM: ${BAM_FILE}"
else
    echo "Error: Input BAM file not found for ${SAMPLE}: ${BAMDIR}/${SAMPLE}.dedup.rg.sorted.bam"
    exit 1
fi

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing Sample: ${SAMPLE}"
echo "Scatter count (Intervals): ${SCATTER_COUNT}"
echo "Memory per chunk: ${MEM_PER_CHUNK}G"
echo "Using global intervals from: ${GLOBAL_INTERVAL_DIR}"

## Load modules
module purge
module load gatk4/4.6

cd ${WORKDIR}

## Step 1: Split intervals (REMOVED - now performed in a pre-run script)

## Step 2: Run HaplotypeCaller chunks in parallel (all 20 at once)
echo "Running ${SCATTER_COUNT} parallel HaplotypeCaller jobs with ${MEM_PER_CHUNK}G memory each..."
for i in $(seq 0 $((SCATTER_COUNT-1))); do
    CHUNK=$(printf "%04d" $i)
    # Use the global path to find the interval list
    SCATTERED_INTERVAL="${GLOBAL_INTERVAL_DIR}/${CHUNK}-scattered.interval_list"

    # Quick check for the global interval file existence
    if [ ! -f "${SCATTERED_INTERVAL}" ]; then
        echo "Error: Global scattered interval file not found: ${SCATTERED_INTERVAL}. Did you run split_intervals.sh?"
        exit 1
    fi

    CHUNK_GVCF="scattered_gvcfs/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf"
    gatk --java-options "-Xmx${MEM_PER_CHUNK}G -Djava.io.tmpdir=/tmp" HaplotypeCaller \
        -R ${REFERENCEDIR}/${REFERENCE} \
        -I ${BAM_FILE} \
        -native-pair-hmm-threads ${CPUS_PER_CHUNK} \
        -L ${SCATTERED_INTERVAL} \
        -ploidy 2 \
        -O ${CHUNK_GVCF} \
        --ERC GVCF &
done

## Wait for all jobs to finish
echo "Waiting for all HaplotypeCaller jobs to complete..."
wait

## Verify all scattered GVCF files were created
echo "Verifying all scattered GVCF files were created..."
ALL_CREATED=true
for i in $(seq 0 $((SCATTER_COUNT-1))); do
    CHUNK=$(printf "%04d" $i)
    CHUNK_GVCF="scattered_gvcfs/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf"
    if [ ! -f "${CHUNK_GVCF}" ]; then
        echo "Error: Scattered GVCF file not created: ${CHUNK_GVCF}"
        ALL_CREATED=false
    fi
done

if [ "$ALL_CREATED" = false ]; then
    echo "Error: Not all scattered GVCF files were created for ${SAMPLE}"
    exit 1
fi

echo "✓ Scatter-Gather HaplotypeCaller completed successfully for ${SAMPLE}"
echo "  Individual GVCFs are located in: scattered_gvcfs/${SAMPLE}/"
echo "  Created ${SCATTER_COUNT} scattered GVCF files"
echo "Completed at: $(date)"
printf "\n"
