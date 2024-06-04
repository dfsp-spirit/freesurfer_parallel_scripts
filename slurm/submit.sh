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

# define and create a unique scratch directory
SCRATCH_DIRECTORY=/global/work/${USER}/freesurfer/${SLURM_JOBID}  # TODO: adapt this
mkdir -p ${SCRATCH_DIRECTORY}
cd ${SCRATCH_DIRECTORY}

# we run FreeSurfer, which should be available as a software on all nodes, so we do
# not need to copy a custom application.
# We copy the config though.
cp ${SLURM_SUBMIT_DIR}/jobarray_config.txt ${SCRATCH_DIRECTORY}

# each job will see a different ${SLURM_ARRAY_TASK_ID}
echo "now processing task id:: " ${SLURM_ARRAY_TASK_ID}

echo "Parsing file '$config' with $num_lines lines (including 1 header line). Using SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID."
num_subjects=$(awk -F' ' -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $2}' $config)
subjects_string=$(awk -F' ' -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $3}' $config)

echo "SLURM_ARRAY_TASK_ID: '$SLURM_ARRAY_TASK_ID', num_subjects: '$num_subjects', subjects: '$subjects_string'"

IFS=$IFS,  # Add the comma to the list of field separators (since the subjects in the $subjects_string are separated by ','.)
subjects=()
for subj in $subjects_string; do subjects+=($subj) ; done

# Run FreeSurfer for each subject:
for subj in ${subjects[@]};
do
    echo "Processing subject $subj in FreeSurfer"
    # TODO: run FreeSurfer for the subject $subj here, with the recon-all command line of your choice:
    #SUBJECTS_DIR=/blah recon-all ... $subj ...
done

# after the job is done we copy our output back to $SLURM_SUBMIT_DIR
# We do not need this as FreeSurfer writes stuff to the SUBJECTS_DIR directly, not to the scratch dir.
#cp output_${SLURM_ARRAY_TASK_ID}.txt ${SLURM_SUBMIT_DIR}

# we step out of the scratch directory and remove it
cd ${SLURM_SUBMIT_DIR}
rm -rf ${SCRATCH_DIRECTORY}

# happy end
exit 0

