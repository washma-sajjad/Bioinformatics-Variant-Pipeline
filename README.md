# Bioinformatics-Variant-Pipeline

A bioinformatics pipeline for variant calling and benchmarking using DeepVariant and Clair3, evaluated against the GIAB HG002 truth set.

> **Execution Environment:** This assignment was run on a **SLURM HPC cluster** using **Singularity** containers. The DeepVariant variant calling step was additionally orchestrated using **Nextflow**.

---

## Project Overview

This project aligns short-read sequencing data from the HG002 sample to the GRCh38 reference genome, calls variants using two state-of-the-art tools (DeepVariant and Clair3), and benchmarks the results against the GIAB NISTv4.2.1 truth set using hap.py.

- **Sample:** HG002 (Ashkenazim Trio Son)
- **Region:** chr1, 1–10 Mb
- **Reference:** GRCh38
- **Truth Set:** GIAB NISTv4.2.1
- **Course:** Special Topics in Bioinformatics

---

## Repository Files

| File / Folder | Description |
|---|---|
| `main.nf` | Nextflow pipeline script used to run the DeepVariant variant calling step |
| `chr1.bed` | BED file defining the chr1 1–10 Mb target region used for variant calling and benchmarking |
| `scripts/` | Shell/SLURM batch scripts for alignment, Clair3 variant calling, and hap.py benchmarking |
| `outputs/` | Output files including VCFs and hap.py benchmark summary CSVs |
| `README.md` | Project documentation |

---

## Pipeline Steps

### Step 1 — Alignment

Download the HG002 dataset and GRCh38 reference, then align reads using BWA-MEM. Submitted as a SLURM job using Singularity:

```bash
bwa mem ref/GRCh38.fa reads_R1.fastq.gz reads_R2.fastq.gz | \
  samtools sort -o alignment/sorted.bam
samtools index alignment/sorted.bam
```

---

### Step 2 — Clair3 Variant Calling

Run Clair3 via Singularity, submitted as a SLURM job:

```bash
singularity exec clair3.sif /opt/bin/run_clair3.sh \
  --bam_fn=alignment/sorted.bam \
  --ref_fn=ref/GRCh38.fa \
  --threads=4 \
  --platform=ilmn \
  --model_path=/opt/models/ilmn \
  --output=clair3/
```

Output: `clair3/merge_output.vcf.gz`

---

### Step 3 — DeepVariant Variant Calling (Nextflow)

DeepVariant was run using the **Nextflow** pipeline defined in `main.nf`, which orchestrates the run on the SLURM cluster via Singularity containers:

```bash
nextflow run main.nf
```

Internally, `main.nf` executes:

```bash
singularity exec deepvariant.sif /opt/deepvariant/bin/run_deepvariant \
  --model_type=WGS \
  --ref=ref/GRCh38.fa \
  --reads=alignment/sorted.bam \
  --output_vcf=deepvariant/deepvariant.vcf.gz \
  --num_shards=4
```

Output: `deepvariant/deepvariant.vcf.gz`

---

### Step 4 — Benchmarking with hap.py

#### Download GIAB truth set

```bash
wget -P giab/ https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed
```

#### Prepare VCFs (index and fix contig names)

```bash
# Fix contig names and recompress
zcat deepvariant.vcf.gz | sed 's/1:1-10000000/1/g' | bgzip > deepvariant_fixed.vcf.gz
tabix -p vcf deepvariant_fixed.vcf.gz

zcat clair3.vcf.gz | sed 's/1:1-10000000/1/g' | bgzip > clair3_fixed.vcf.gz
tabix -p vcf clair3_fixed.vcf.gz

# Strip chr prefix from truth VCF and BED
zcat truth.vcf.gz | sed 's/^##contig=<ID=chr/##contig=<ID=/; s/^\(chr\)//' | bgzip > truth_nochr.vcf.gz
tabix -p vcf truth_nochr.vcf.gz
sed 's/^chr//' giab/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed > giab/HG002_nochr.bed
```

#### Run hap.py for DeepVariant

```bash
singularity exec --bind $PWD:/data --env HGREF=/data/ref/GRCh38.fa hap.py_v0.3.12.sif \
  /opt/hap.py/bin/hap.py \
  /data/truth_nochr.vcf.gz \
  /data/deepvariant_fixed.vcf.gz \
  -r /data/ref/GRCh38.fa \
  -f /data/giab/HG002_nochr.bed \
  --engine=vcfeval \
  --pass-only \
  -o /data/benchmark/deepvariant_bench
```

#### Run hap.py for Clair3

```bash
singularity exec --bind $PWD:/data --env HGREF=/data/ref/GRCh38.fa hap.py_v0.3.12.sif \
  /opt/hap.py/bin/hap.py \
  /data/truth_nochr.vcf.gz \
  /data/clair3_fixed.vcf.gz \
  -r /data/ref/GRCh38.fa \
  -f /data/giab/HG002_nochr.bed \
  --engine=vcfeval \
  --pass-only \
  -o /data/benchmark/clair3_bench
```

---

## Benchmark Results

Evaluated against GIAB HG002 NISTv4.2.1 truth set on chr1 1–10 Mb region.

| Type | Metric | DeepVariant | Clair3 |
|---|---|---|---|
| SNP | Recall | 0.0381 | 0.0000 |
| SNP | Precision | 0.0488 | 0.0000 |
| SNP | F1 Score | 0.0428 | 0.0000 |
| INDEL | Recall | 0.0264 | 0.0000 |
| INDEL | Precision | 0.0980 | 0.0000 |
| INDEL | F1 Score | 0.0416 | 0.0000 |

### Notes

- **Clair3** produced only `RefCall` entries with no variant calls, likely due to insufficient sequencing coverage (~2x). Meaningful variant calling requires at least 20–30x coverage.
- **DeepVariant** metrics are low due to the limited 1 Mb evaluation region and low coverage.
- Full hap.py output available in `outputs/deepvariant_bench.summary.csv` and `outputs/clair3_bench.summary.csv`.

---

## Tools & Versions

| Tool | Version |
|---|---|
| BWA-MEM | 0.7.17 |
| Samtools | 1.9 |
| DeepVariant | Latest (Singularity via Nextflow) |
| Clair3 | Latest (Singularity) |
| hap.py | v0.3.12 |
| RTG Tools (vcfeval) | Bundled with hap.py |
| Nextflow | Latest |
| Singularity | Latest |

---

## Execution Environment

This assignment was executed on a **SLURM** high-performance computing cluster:

- **SLURM** was used as the job scheduler to submit and manage all pipeline steps as batch jobs.
- **Singularity** containers were used to run all bioinformatics tools (DeepVariant, Clair3, hap.py) in a reproducible, portable environment.
- **Nextflow** (`main.nf`) was used specifically to orchestrate the **DeepVariant** step, managing process execution and resource allocation on the SLURM cluster.

---

## References

- [GIAB Truth Sets](https://www.nist.gov/programs-projects/genome-bottle)
- [DeepVariant](https://github.com/google/deepvariant)
- [Clair3](https://github.com/HKU-BAL/Clair3)
- [hap.py](https://github.com/Illumina/hap.py)
- [GRCh38 Reference](https://www.ncbi.nlm.nih.gov/assembly/GCF_000001405.26/)
- [Nextflow](https://www.nextflow.io/)

---

## Submitted By

- Washma Sajjad
- Nawal Babar
- Ashna Abrar
- Manaal Tufail
