#!/bin/bash
#SBATCH --job-name=variant_filtration_ixodes
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=70G
#SBATCH --time=5-00:00:00
#SBATCH --error=%x_%j.err
#SBATCH --output=%x_%j.out

module purge
module load gatk4/4.6

# --- Define paths to match variant_03b_gather_vcfs.sh ---
BASEDIR=/work/fauverlab/zachpella/scatter_20
FINAL_VCF_DIR="${BASEDIR}/final_vcf"

# INPUT_SNP_VCF from the previous SelectVariants step
INPUT_SNP_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_only.vcf.gz"

# Output filtered VCF
OUTPUT_FILTERED_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_filtered.vcf.gz"

echo "Starting VariantFiltration for SNPs..."
echo "Input SNP VCF: ${INPUT_SNP_VCF}"
echo "Output filtered VCF: ${OUTPUT_FILTERED_VCF}"

gatk --java-options "-Xms4G -Xmx65G" VariantFiltration \
    --variant "${INPUT_SNP_VCF}" \
    --filter-expression "QD < 2.0" --filter-name "QD2" \
    --filter-expression "QUAL < 30.0" --filter-name "QUAL30" \
    --filter-expression "SOR > 3.0" --filter-name "SOR3" \
    --filter-expression "FS > 60.0" --filter-name "FS60" \
    --filter-expression "MQ < 40.0" --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    --output "${OUTPUT_FILTERED_VCF}"

if [ $? -ne 0 ]; then
    echo "Error: VariantFiltration failed."
    exit 1
fi

echo "VariantFiltration completed successfully."
echo "Filtered VCF: ${OUTPUT_FILTERED_VCF}"
