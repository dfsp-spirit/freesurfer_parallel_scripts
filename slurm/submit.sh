#!/bin/bash -l

# Run this script as: sbatch submit.sh

#####################
# FreeSurfer job-array
#####################

#SBATCH --job-name=freesurfer

# 20 jobs will run in this array at the same time
#SBATCH --array=0-19

# Set run time. Note that this should be set to `TIME_PER_SUBJECT * max(subjects_per_job)`, where the latter is computed by the
# Python script subjects_txt_to_jobarray_config.py and visible in jobarray_config.txt.
# The time per subject should be something between 10 and 20 hours for FreeSurfer, depending on the hardware.
#              d-hh:mm:ss
#SBATCH --time=0-20:00:00

# 500MB memory per core. currenlty not set.
# this is a hard limit
####SBATCH --mem-per-cpu=500MB

# you may not place bash commands before the last SBATCH directive. Place them below this line.

test_mode="no"
test_tag=""
if [ -z "${SLURM_JOBID}" ]; then
    echo "WARNING: Not running from sbatch/slurm!"
    echo "         You should submit this script to slurm via the 'sbatch' command in production!"
    echo "         Assuming you just want to run a local test:"
    echo "             * Assigning some SLURM variables for testing purposes."
    echo "             * The commands will NOT actually be run, only printed for inspection."
    test_mode="yes"
    test_tag="[TEST]"
    SLURM_SUBMIT_DIR=$(pwd)
    SLURM_ARRAY_TASK_ID=1
fi

# This is the directory into which you cloned https://github-com/dfsp-spirit/freesurfer_parallel_scripts, via the `git clone` command.
fsparallel_dir=$HOME/develop/freesurfer_parallel_scripts
subjects_dir="/path/to/your_freesurfer_data"

# TODO: do we need to load the GNU parallel shell module? This depends on the cluster setup, ask your admins.
# module load parallel

# define and create a unique scratch directory
SCRATCH_DIRECTORY=$HOME/tmp/${USER}/freesurfer/${SLURM_JOBID}  # TODO: adapt this
mkdir -p ${SCRATCH_DIRECTORY}
cd ${SCRATCH_DIRECTORY}

## We run FreeSurfer, which should be available as a software on all nodes, so we do
## not need to copy a custom application. We need to copy some scripts and the subjects files though:
# Copy the subjects files:
cp ${SLURM_SUBMIT_DIR}/subjects_job* ${SCRATCH_DIRECTORY}
cp ${fsparallel_dir}/cross-sectional/preproc_reconall_parallel.bash ${SCRATCH_DIRECTORY}
chmod +x ${SCRATCH_DIRECTORY}/preproc_reconall_parallel.bash
cp ${fsparallel_dir}/cross-sectional/preproc_reconall_single_subject.bash ${SCRATCH_DIRECTORY}
chmod +x ${SCRATCH_DIRECTORY}/preproc_reconall_single_subject.bash

# each job will see a different ${SLURM_ARRAY_TASK_ID}

subjects_file="subjects_job${SLURM_ARRAY_TASK_ID}.txt"

echo "$test_tag Now processing slurm task with id: ${SLURM_ARRAY_TASK_ID}. Using subjects file '$subjects_file' and SUBJECTS_DIR='$subjects_dir'."


if [ "${test_mode}" = "yes" ]; then
    echo "$test_tag Would run command: SUBJECTS_DIR='${subjects_dir}' ./preproc_reconall_parallel.bash fsdir+recon 20 none '$subjects_file'"
else
    SUBJECTS_DIR="${subjects_dir}" ./preproc_reconall_parallel.bash fsdir+recon 20 none "$subjects_file"
fi

# Step out of the scratch directory and remove it. Stuff is saved in the SUBJECTS_DIR by FreeSurfer.
cd ${SLURM_SUBMIT_DIR}
rm -rf ${SCRATCH_DIRECTORY}

# happy end
exit 0

