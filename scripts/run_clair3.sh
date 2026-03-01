#!/bin/bash

echo "===== Member 2 Mini Pipeline Starting ====="

# Create required directories
mkdir -p alignment
mkdir -p results/clair3_output_1M

# Subset FASTQ (1 million reads)
echo "Subsetting FASTQ..."
seqtk sample -s100 fastq/HG002_sub.fastq 1000000 > fastq/HG002_sub_1M.fastq

# Check FASTQ
if [ ! -s fastq/HG002_sub_1M.fastq ]; then
    echo "ERROR: FASTQ subset failed!"
    exit 1
fi

# Extract 10Mb of chromosome 1
echo "Extracting reference chunk..."
samtools faidx ref/GRCh38.fa 1:1-10000000 > ref/GRCh38_chr1_10Mb.fa

# Index reference
echo "Indexing reference..."
bwa index ref/GRCh38_chr1_10Mb.fa

# Align reads
echo "Aligning reads..."
bwa mem -t 4 ref/GRCh38_chr1_10Mb.fa fastq/HG002_sub_1M.fastq | \
samtools view -bS - > alignment/1M_chr1_10Mb.bam

# Check BAM
if [ ! -s alignment/1M_chr1_10Mb.bam ]; then
    echo "ERROR: BAM file not created!"
    exit 1
fi

# Sort BAM
echo "Sorting BAM..."
samtools sort -@ 4 alignment/1M_chr1_10Mb.bam -o alignment/1M_chr1_10Mb.sorted.bam

# Index BAM
echo "Indexing BAM..."
samtools index alignment/1M_chr1_10Mb.sorted.bam

# Check sorted BAM
if [ ! -s alignment/1M_chr1_10Mb.sorted.bam ]; then
    echo "ERROR: Sorted BAM not created!"
    exit 1
fi

# Run Clair3
echo "Running Clair3..."
$CONDA_PREFIX/bin/run_clair3.sh \
alignment/1M_chr1_10Mb.sorted.bam \
ref/GRCh38_chr1_10Mb.fa \
results/clair3_output_1M \
HG002_test_1M \
hifi

echo "===== Pipeline Finished ====="
echo "Check results in: results/clair3_output_1M/"

