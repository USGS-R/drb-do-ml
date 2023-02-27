#!/bin/bash
#SBATCH --job-name=DO_pipe             # human-readable label for squeue output
#SBATCH --time=10:00:00                  # maximum time for this job
#SBATCH --output=do_mk_%u_%j.out        # user's output file (password here!)
#SBATCH --partition=batch                 # which SLURM partition to use
#SBATCH --nodes=1                       # only request one node
#SBATCH --ntasks-per-node=32             # only request one core

####################
#This script is designed to be run with the container name as an sbatch argument. 
#The container needs to be located in /caldera/projects/usgs/water/impd/pump/drb-inland-salinity/containers/
#Example:
# sbatch run-tar_make.slurm mycontainer.sif
####################

module load singularity

#Container path
#argument 1 is the name of the container to use.
CONTAINER="/scratch/jsadler/do-ml_v0.4.sif"

# Run the tar_make() command
#singularity exec ${CONTAINER} Snakemake ../../../out/models/0_baseline_LSTM/nstates_10/nep_100/rep_3/val_preds.feather -s 2a_model/src/model s/0_baseline_LSTM/Snakefile  --configfile 2a_model/src/models/0_baseline_LSTM/config.yml -j --unlock && Snakemake ../../../out/models/0_baseline_LSTM/nstates_10/nep_100/rep_3/val_preds.feather -s 2a_model/src/model s/0_baseline_LSTM/Snakefile  --configfile 2a_model/src/models/0_baseline_LSTM/config.yml -j --rerun-incomplete  
singularity exec ${CONTAINER} Rscript -e "source('_targets.R'); tar_make()"
