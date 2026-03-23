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
        for sampleid in config["samples"][patient]:
            o.append(f"results/basecall_dorado/{patient}/{sampleid}.bam")
            o.append(f"results/summary_dorado/{patient}/{sampleid}.txt")
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
