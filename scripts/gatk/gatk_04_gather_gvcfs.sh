#!/bin/bash
#SBATCH --job-name=gather_and_index_ixodes
#SBATCH --time=12:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=40G
#SBATCH --partition=guest

## Load modules
module purge
module load gatk4/4.6

# --- CORRECTED to match variant_03_genotype_gvcfs.sh ---
BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKDIR=${BASEDIR}/genotyping

# Directory containing the scattered VCF chunks
INPUT_VCF_DIR=${WORKDIR}/genotyped_vcfs
INPUT_VCF_PREFIX="chunk_"
INPUT_VCF_SUFFIX="_genotyped.vcf.gz"

# Final output file path
FINAL_OUTPUT_DIR=${BASEDIR}/final_vcf
FINAL_VCF_NAME="combined_ixodes_all_variants.vcf.gz"
FINAL_VCF_PATH="${FINAL_OUTPUT_DIR}/${FINAL_VCF_NAME}"

## Create final output directory and scratch
mkdir -p "${FINAL_OUTPUT_DIR}"
mkdir -p /scratch/$SLURM_JOBID

echo "Starting Gather and Index process."
echo "Final VCF will be: ${FINAL_VCF_PATH}"
printf "\n"

# ----------------------------------------------------------------------
# 1. Prepare Input File List (Gather setup)
# ----------------------------------------------------------------------

echo "Searching for VCF chunk files in: ${INPUT_VCF_DIR}"
# Find and sort all chunk VCFs (0000 to 0019 for 20 chunks)
INPUT_VCFS=$(ls -1 ${INPUT_VCF_DIR}/${INPUT_VCF_PREFIX}????${INPUT_VCF_SUFFIX} 2>/dev/null | sort)

if [ -z "$INPUT_VCFS" ]; then
    echo "Error: No VCF chunks found in ${INPUT_VCF_DIR}. Exiting."
    exit 1
fi

INPUT_ARGS=""
for VCF in ${INPUT_VCFS}; do
    INPUT_ARGS="${INPUT_ARGS} -I ${VCF}"
done

echo "Found $(echo ${INPUT_VCFS} | wc -l) VCF chunks to gather."

## ----------------------------------------------------------------------
## 2. Run GATK GatherVcfs (Merge)
## ----------------------------------------------------------------------

echo "Starting GatherVcfs to create final VCF..."

gatk --java-options "-Xms4G -Xmx30G" \
    GatherVcfs \
    ${INPUT_ARGS} \
    -O ${FINAL_VCF_PATH} \
    --TMP_DIR /scratch/$SLURM_JOBID

if [ $? -ne 0 ]; then
    echo "Error: GatherVcfs failed."
    rm -rf /scratch/$SLURM_JOBID
    exit 1
fi

echo "GatherVcfs completed successfully. VCF file created."

# ----------------------------------------------------------------------
# 3. Run GATK IndexFeatureFile (Index Creation)
# ----------------------------------------------------------------------

echo "Starting IndexFeatureFile to create the required .tbi index..."

gatk --java-options "-Xms2G -Xmx8G" IndexFeatureFile \
    -I "${FINAL_VCF_PATH}"

# ----------------------------------------------------------------------
# 4. Validation and Cleanup
# ----------------------------------------------------------------------

if [ $? -ne 0 ]; then
    echo "Error: IndexFeatureFile failed during execution."
    rm -rf /scratch/$SLURM_JOBID
    exit 1
fi

if [ -f "${FINAL_VCF_PATH}.tbi" ]; then
    echo "✓ Indexing completed successfully. VCF is ready for filtering."
else
    echo "Error: Index file (.tbi) was not created. Check error log."
    exit 1
fi

echo "Cleaning up temporary scratch directory: /scratch/${SLURM_JOBID}"
rm -rf /scratch/$SLURM_JOBID

echo "Job finished at: $(date)"
printf "\n"
