import os

configfile: "config/config.yaml"

def get_resource(rule, resource):
    try:
        return config["resources"][rule][resource]
    except KeyError:
        return config["resources"]["default"][resource]

regions = {}
with open(config["regions"]) as ifh:
    fields = ["chrom","start","end","label","score","strand"]
    for l in ifh:
        data = l.rstrip("\n").split()
        regions[data[3]] = dict(zip(fields,data))

def input_main(wc):
    o = []
    for patient in config["samples"]:
        o.append(f"results/methylartist_scoredist/{patient}.svg")
        for sampleid in config["samples"][patient]:
            # FILES COMMENTED TO AVOID THE RERUN AS IN TOMAS SNAKEFILE
            # o.append(f"results/basecall_dorado/{patient}/{sampleid}.bam")
            # o.append(f"results/summary_dorado/{patient}/{sampleid}.txt")
            o.append(f"results/pycoqc/{patient}/{sampleid}.html")
            # o.append(f"results/qsfilter/{patient}/{sampleid}.bam")
            # o.append(f"results/minimap2/{patient}/{sampleid}.bam")
            o.append(f"results/primary/{patient}/{sampleid}.bam") #changed to .bam
    return o


rule main:
    input:
        input_main,

rule basecall_dorado:
    input:
        lambda wc: config["samples"][wc.patient][wc.sampleid]["pod5"],
    output:
        "results/basecall_dorado/{patient}/{sampleid}.bam",
    log:
        "logs/basecall_dorado/{patient}/{sampleid}.log",
    benchmark:
        "logs/basecall_dorado/{patient}/{sampleid}.bmk"
    params:
        bin=config["dorado_bin"],
        model=get_resource("basecall_dorado", "params_model"),
        extra=get_resource("basecall_dorado", "params_extra"),
    threads: get_resource("basecall_dorado", "threads")
    resources:
        mem_mb=get_resource("basecall_dorado", "mem_mb"),
        runtime=get_resource("basecall_dorado", "runtime"),
        slurm_partition=get_resource("basecall_dorado", "partition"),
        gres=get_resource("basecall_dorado", "gres"),
    shell:
        """
        {params.bin} basecaller {params.model} {input} {params.extra} > {output} 2> {log}
    """


rule summary_dorado:
    input:
        "results/basecall_dorado/{patient}/{sampleid}.bam"
    output:
        "results/summary_dorado/{patient}/{sampleid}.txt"
    log:
        "logs/summary_dorado/{patient}/{sampleid}.log"
    benchmark:
        "logs/summary_dorado/{patient}/{sampleid}.bmk"
    params:
        bin=config["dorado_bin"]
    threads: get_resource("summary_dorado", "threads")
    resources:
        mem_mb=get_resource("summary_dorado", "mem_mb"),
        runtime=get_resource("summary_dorado", "runtime"),
        slurm_partition=get_resource("summary_dorado", "partition"),
        slurm_extra=get_resource("summary_dorado", "slurm_extra")
    shell:
        """
        {params.bin} summary {input} >> {output} 2> {log}
    """
rule pycoqc:
    input:
        "results/summary_dorado/{patient}/{sampleid}.txt",
    output:
        "results/pycoqc/{patient}/{sampleid}.html",
    log:
        "logs/pycoqc/{patient}/{sampleid}.log",
    benchmark:
        "logs/pycoqc/{patient}/{sampleid}.bmk"
    threads: get_resource("pycoqc", "threads")
    conda:
        "envs/pycoqc.yaml"
    resources:
        mem_mb=get_resource("pycoqc", "mem_mb"),
        runtime=get_resource("pycoqc", "runtime"),
        slurm_partition=get_resource("pycoqc", "partition"),
        slurm_extra=get_resource("pycoqc", "slurm_extra"),
    shell:
        """
       pycoQC -f {input} -o {output} > {log} 2>&1
    """    
rule qsfilter:
    input:
        "results/basecall_dorado/{patient}/{sampleid}.bam",
    output:
        "results/qsfilter/{patient}/{sampleid}.bam",
    log:
        "logs/qsfilter/{patient}/{sampleid}.log",
    benchmark:
        "logs/qsfilter/{patient}/{sampleid}.bmk"
    params:
        minq=config["minq"]
    threads: get_resource("qsfilter", "threads")
    resources:
        mem_mb=get_resource("qsfilter", "mem_mb"),
        runtime=get_resource("qsfilter", "runtime"),
        slurm_partition=get_resource("qsfilter", "partition"),
    conda:
        "envs/samtools.yaml"
    shell:
        """
        samtools view -e '[qs]>={params.minq}' {input} > {output} 2> {log}
    """

rule minimap2:
    input:
        reads="results/qsfilter/{patient}/{sampleid}.bam",
        ref=lambda wc: config["ref"],
    output:
        "results/minimap2/{patient}/{sampleid}.bam",
    log:
        "logs/minimap2/{patient}/{sampleid}.log",
    benchmark:
        "logs/minimap2/{patient}/{sampleid}.bmk"
    threads: get_resource("minimap2", "threads")
    resources:
        mem_mb=get_resource("minimap2", "mem_mb"),
        runtime=get_resource("minimap2", "runtime"),
        slurm_partition=get_resource("minimap2", "partition"),
    conda:
        "envs/minimap2.yaml"
    shell:
        """
        samtools fastq -T "*" {input.reads} 2>> {log} | minimap2 -a -x map-ont -y -t {threads} {input.ref} - 2>> {log} | samtools sort - -o {output} >> {log} 2>&1
        samtools index {output} >> {log} 2>&1
    """

rule primary:
    input:
        "results/minimap2/{patient}/{sampleid}.bam",
    output:
        bam="results/primary/{patient}/{sampleid}.bam",
        bai="results/primary/{patient}/{sampleid}.bam.bai",
    log:
        "logs/primary/{patient}/{sampleid}.log",
    benchmark:
        "logs/primary/{patient}/{sampleid}.bmk"
    threads: lambda wc: get_resource("primary", "threads")/2
    resources:
        mem_mb=get_resource("primary", "mem_mb"),
        runtime=get_resource("primary", "runtime"),
        slurm_partition=get_resource("primary", "partition"),
    conda:
        "envs/samtools.yaml"
    shell:
        """
        samtools view -@ {threads} -F 2308 -b {input} | samtools sort -@ {threads} -o {output.bam} 2> {log}
        samtools index {output.bam}
    """
def get_bams(wc):
        for sampleid in config["samples"][wc.patient]:
            yield f"results/primary/{wc.patient}/{sampleid}.bam"

rule methylartist_scoredist:
    input:
        bams=get_bams,
        # ref="results/decompress_ref/ref.fa",
        ref=lambda wc: config["ref"],
    output:
        "results/methylartist_scoredist/{patient}.svg",
    log:
        "logs/methylartist_scoredist/{patient}.log",
    benchmark:
        "logs/methylartist_scoredist/{patient}.bmk"
    resources:
        mem_mb=get_resource("methylartist_scoredist", "mem_mb"),
        runtime=get_resource("methylartist_scoredist", "runtime"),
        slurm_partition=get_resource("methylartist_scoredist", "partition"),
    params:
        bams=lambda wc: ",".join(get_bams(wc))
    conda:
        "envs/methylartist.yaml"
    shell:
        """
        methylartist scoredist --ref {input.ref} --motif CG -b {params.bams} -o {output} -m m --svg &> {log}
    """
