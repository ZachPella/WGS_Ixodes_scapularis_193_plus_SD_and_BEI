#!/bin/bash
#SBATCH --job-name=select_passing_ixodes
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=80G
#SBATCH --time=4-22:00:00
#SBATCH --error=%x_%j.err
#SBATCH --output=%x_%j.out

# Purge any existing modules and load the required GATK version
module purge
module load gatk4/4.6

# --- Define paths to match variant_03b_gather_vcfs.sh ---
BASEDIR=/work/fauverlab/zachpella/scatter_100
FINAL_VCF_DIR="${BASEDIR}/final_vcf"

# INPUT_FILTERED_VCF from the previous VariantFiltration step
INPUT_FILTERED_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_filtered.vcf.gz"

# Output passing-only VCF
OUTPUT_PASSING_ONLY_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_passing_only.vcf.gz"

echo "Creating a VCF with only the variants that passed the filters..."
echo "Input filtered VCF: ${INPUT_FILTERED_VCF}"
echo "Output passing-only VCF: ${OUTPUT_PASSING_ONLY_VCF}"

# Use GATK's SelectVariants tool to select only the variants with the "PASS" flag.
# The expression 'vc.isNotFiltered()' selects variants that do NOT have a FILTER flag, i.e., they PASS.      
gatk --java-options "-Xms2G -Xmx75G" SelectVariants \
    --variant "${INPUT_FILTERED_VCF}" \
    --output "${OUTPUT_PASSING_ONLY_VCF}" \
    --select 'vc.isNotFiltered()'

if [ $? -ne 0 ]; then
    echo "Error: SelectVariants (passing only) failed."
    exit 1
fi

echo "SelectVariants completed successfully."
echo "VCF with passing-only variants created: ${OUTPUT_PASSING_ONLY_VCF}"
echo "Script finished successfully."
