# cfDNA ONT Analysis

## Samples

Carla Cortina's samples 
1. Health control (Male) 
    * Extraction QIAamp MinElute ccfDNA Manual (3mL de plasma). 
    * DNA input 11,29ng. DNA loaded 9.28ng (82.2% yield).
    Loading molarity 71 fmol.
    * Run 26 sept 2024:
    flow_cell_id=PAW91195
    sample_id=CNIO4
    Data location: /var/lib/minknow/data/./CNIO4cfDNA_quiagen/CNIO4/20240926_1655_P2S-00806-A_PAW91195_5fc7f251

2. Tumor sample (female)
    * Breast cancer patient (3 stage). 
    * Extraction Qiagen cfDNA kit (3mL de plasma).
    * DNA input 28ng.
    DNA loaded 21,89ng (78,2% yield).
    Molarity 168,64 fmol. 
    * Run 1 oct 2024:
    flow_cell_id=PAW90485
    sample_id=JGS885
    Data location: /var/lib/minknow/data/./JGS855cfDNA_quiagen/JGS885/20241001_1605_P2S-00806-A_PAW90485_6dc14a84

## Pipeline

Based on: ``myeloma-epi-sv`` from Tomás Di Domenico and Francisco J. Villena

## Run

```sh
screen –r ont
ctrl+a [ #scrolling mode
snakemake --use-conda -j unlimited --executor slurm --verbose -n #dry run
ctrl+a d
```
> after ctrl+a stop pressing the buttoms before trying d or [

## Description

### Config Alterations

1. Sample's source
2. Model's source
3. Slurm extra
    * Changed from: 
    ```sh
    resources: 
        basecall_dorado: 
            slurm_extra: "--gres=gpu:A100:1" 
    ```
    * To: 
    ```sh
    resources: 
        basecall_dorado: 
            gres: "gpu:A100:1"
    ```

4. Reference Genome and Gen annotations (tbh)
5. Default run time
6. Pyroqc mem_mb

### Dorado Basecall
 > change in resources: ``gres=get_resource("basecall_dorado", "gres"),`` 

### Summary Dorado 
(no changes)

### PyroQC
The monstuous amount of reads (derived from the short length of the reads) increases the size of the file. 
so the config states 200GB of RAM needed and increasing the default run time to 60min.

