#!/bin/bash -l

# Run this script as: sbatch submit.sh

#####################
# FreeSurfer job-array
#####################

#SBATCH --job-name=freesurfer

# 20 jobs will run in this array at the same time
#SBATCH --array=1-20

# Set run time. Note that this should be set to TIME_PER_SUBJECT * subjects_per_job, where the latter is computed by the
# Python script subjects_txt_to_jobarray_config.py and visible in jobarray_config.txt.
# The time per subject should be something between 10 and 20 hours for FreeSurfer, depending on the hardware.
#              d-hh:mm:ss
#SBATCH --time=0-20:00:00

# 500MB memory per core. currenlty not set.
# this is a hard limit
####SBATCH --mem-per-cpu=500MB

# you may not place bash commands before the last SBATCH directive. Place them below this line.

fsparallel_dir=$HOME/develop/freesurfer_parallel_scripts

# TODO: do we need to load the GNU parallel shell module?
# module load parallel

# define and create a unique scratch directory
SCRATCH_DIRECTORY=/global/work/${USER}/freesurfer/${SLURM_JOBID}  # TODO: adapt this
mkdir -p ${SCRATCH_DIRECTORY}
cd ${SCRATCH_DIRECTORY}

# we run FreeSurfer, which should be available as a software on all nodes, so we do
# not need to copy a custom application.
# We copy the config though.
cp ${SLURM_SUBMIT_DIR}/jobarray_config.txt ${SCRATCH_DIRECTORY}
cp ${fsparallel_dir}/cross-sectional/preproc_reconall_parallel.bash ${SCRATCH_DIRECTORY}
cp ${fsparallel_dir}/cross-sectional/preproc_reconall_single_subject.bash ${SCRATCH_DIRECTORY}

# each job will see a different ${SLURM_ARRAY_TASK_ID}
echo "now processing task id:: " ${SLURM_ARRAY_TASK_ID}


subjects_file="subjects${SLURM_ARRAY_TASK_ID}.txt"
./preproc_reconall_parallel.bash 20 me@blah.de "$subjects_file"

# we step out of the scratch directory and remove it
cd ${SLURM_SUBMIT_DIR}
rm -rf ${SCRATCH_DIRECTORY}

# happy end
exit 0

