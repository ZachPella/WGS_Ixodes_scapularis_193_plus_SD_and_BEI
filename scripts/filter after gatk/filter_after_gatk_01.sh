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

# --- Define paths to match variant_03b_gather_vcfs.sh ---
BASEDIR=/work/fauverlab/zachpella/scatter_100
FINAL_VCF_DIR="${BASEDIR}/final_vcf"

# INPUT_VCF from the gather script output
INPUT_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants.vcf.gz"

# Output SNPs-only VCF
OUTPUT_SNP_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_only.vcf.gz"

echo "Starting SelectVariants to extract SNPs..."
echo "Input VCF: ${INPUT_VCF}"
echo "Output SNPs VCF: ${OUTPUT_SNP_VCF}"

gatk --java-options "-Xms2G -Xmx75G" SelectVariants \
    --variant "${INPUT_VCF}" \
    --select-type-to-include SNP \
    --output "${OUTPUT_SNP_VCF}"

if [ $? -ne 0 ]; then
    echo "Error: SelectVariants (SNPs) failed."
    exit 1
fi

echo "SelectVariants completed successfully."
echo "SNPs-only VCF: ${OUTPUT_SNP_VCF}"
