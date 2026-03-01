#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.fastq = "fastq/HG002_sub.fastq"
params.ref   = "ref/GRCh38.fa"

process ALIGN_FASTQ {

    executor 'slurm'
    container 'docker://biocontainers/bwa:v0.7.17_cv1'

    cpus 8
    memory '16 GB'
    time '6h'

    input:
    path fastq
    path ref

    output:
    path "HG002.sorted.bam"
    path "HG002.sorted.bam.bai"

    script:
    """
    bwa mem -t ${task.cpus} $ref $fastq | samtools sort -o HG002.sorted.bam
    samtools index HG002.sorted.bam
    """
}

workflow {
    fastq_ch = Channel.fromPath(params.fastq)
    ref_ch   = Channel.fromPath(params.ref)

    ALIGN_FASTQ(fastq_ch, ref_ch)
}

