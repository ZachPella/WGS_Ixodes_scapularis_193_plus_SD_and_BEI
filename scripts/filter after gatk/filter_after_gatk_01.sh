#!/bin/bash
#SBATCH --job-name=select_snps_ixodes
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=80G
#SBATCH --time=5-00:00:00
#SBATCH --error=%x_%j.err
#SBATCH --output=%x_%j.out

module purge
module load gatk4/4.6

# --- Define paths based on variant_03b_gather_vcfs.sh output ---
# BASEDIR is now '/work/fauverlab/zachpella/outgroup_ixodes_all_preprocess_and_gatk'
BASEDIR=/work/fauverlab/zachpella/outgroup_ixodes_all_preprocess_and_gatk
FINAL_VCF_DIR="${BASEDIR}/final_vcf"

# INPUT_VCF is now 'combined_ixodes_all_variants.vcf.gz'
INPUT_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants.vcf.gz"

# New output name reflecting the new input file name
OUTPUT_SNP_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_only.vcf.gz"

# NOTE: The gather script (variant_03b) explicitly creates the index,
# so we can proceed directly to SelectVariants.

echo "Starting SelectVariants to extract SNPs..."

# Use -Xmx to match or slightly exceed the requested SBATCH --mem for the tool's heap size
# We use the full 60G requested by SBATCH --mem for safety and performance.
gatk --java-options "-Xms2G -Xmx80G" SelectVariants \
    --variant "${INPUT_VCF}" \
    --select-type-to-include SNP \
    --output "${OUTPUT_SNP_VCF}"

if [ $? -ne 0 ]; then
    echo "Error: SelectVariants (SNPs) failed."
    exit 1
fi

echo "SelectVariants completed. SNPs-only VCF: ${OUTPUT_SNP_VCF}"
