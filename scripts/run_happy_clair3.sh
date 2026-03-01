#!/bin/bash
singularity exec \
  --bind $PWD:/data \
  --env HGREF=/data/ref/GRCh38.fa \
  hap.py_v0.3.12.sif \
  /opt/hap.py/bin/hap.py \
  /data/truth_chr1_1M_nochr.vcf.gz \
  /data/clair3_fixed.vcf.gz \
  -r /data/ref/GRCh38.fa \
  -f /data/giab/HG002_chr1_1M_nochr.bed \
  --engine=vcfeval \
  --pass-only \
  -o /data/benchmark_out/clair3_bench
