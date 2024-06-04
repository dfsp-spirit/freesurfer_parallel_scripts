#!/bin/bash

config=./jobarray_config.txt       # Path to file generated by Python script 'subjects_txt_to_jobarray_config.py'.

SLURM_ARRAY_TASK_ID=0  # automatically set in SLURM, we set it here manually for testing purposes.


echo "Parsing file '$config' with $num_lines lines (including 1 header line). Using SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID."
num_subjects=$(awk -F' ' -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $2}' $config)
subjects_string=$(awk -F' ' -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $3}' $config)


echo "SLURM_ARRAY_TASK_ID: '$SLURM_ARRAY_TASK_ID', num_subjects: '$num_subjects', subjects: '$subjects_string'"

IFS=$IFS,  # Add the comma to the list of field separators (since the subjects in the $subjects_string are separated by ','.)
subjects=()
for subj in $subjects_string; do subjects+=($subj) ; done

# Print for confirmation:
for subj in ${subjects[@]};
do
    echo "Processing subject $subj"
done
