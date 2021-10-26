#!/bin/bash
# smooth_stddata_custom_parallel.bash -- run stuff in parallel over a number of subjects. By default, smooth std space data with custom FWHM kernel.
#
######################### IMPORTANT #############################
# Adapt the JOB SETTINGS at the end of this file to configure   #
# the command to run for each of the subject!                   #
######################### IMPORTANT #############################




APPTAG="[SMOOTH_PAR]"

##### General settings #####

# Number of consecutive GNU Parallel jobs. Note that 0 for 'as many as possible'. Maybe set something a little bit less than the number of cores of your machine if you want to do something else while it runs.
# See 'man parallel' for details.


###### End of job settings #####



## Check some stuff

# SUBJECTS_DIR must be set
if [ -z "${SUBJECTS_DIR}" ]; then
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR not set. Exiting."
    exit 1
fi

# By default, SUBJECTS_DIR gets set to the FreeSurfer subjects folder, but that makes no sense unless you want to work on example data.
if [ -d "${SUBJECTS_DIR}/bert" ]; then      # 'bert' is a FreeSurfer example subject.
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR seems to point at the subjects dir of the FreeSurfer installation: '${SUBJECTS_DIR}'. Configure it to point at your data!"
    echo "$APPTAG NOTE: You can ignore the last warning if you have a subject named 'bert' in your study."
fi

# When ppl install FreeSurfer on a new machine, it is a common error to forgot about the license file you have to manually copy into the installation dir.
# When the file is missing, FreeSurfer will refuse to work and all jobs in the parallel run will die.
# You can get a license.txt file for free by registering on the FreeSurfer website.
if [ ! -f "${FREESURFER_HOME}/license.txt" ]; then
    echo "$APPTAG ERROR: The FreeSurfer license file was not found at '${FREESURFER_HOME}/license.txt'. Run would fail, exiting now. (Get a free license on the Freesurfer website and copy it to that dir to fix this error.)"
    exit 1
fi


## Another example: feel free to use shell syntac to do stuff in the command.
# here, we use another argument from the command line of this script:
if [ -z "$3" ]; then
  echo "$APPTAG ERROR: Missing required arguments."
  echo "$APPTAG Usage: $0 <subjects_file> <measure> <fwhm> [<num_proc>] [<template_subject>]"
  echo "$APPTAG   Make sure SUBJECTS_DIR is set properly."
  echo "$APPTAG Details on arguments:"
  echo "$APPTAG   <subjects_file> : text file containing one subject id per line"
  echo "$APPTAG   <measure> : some FreeSurfer surface measure, e.g., 'area', 'curv', or 'area.pial'."
  echo "$APPTAG   <fwhm>    : smoothing kernel FWHM in mm, something like 1 or 18."
  echo "$APPTAG   <num_proc> : number of threads to run in parallel"
  echo "$APPTAG   <template_subject> : Optional, the template subject to map data to. Defaults to fsaverage."
  exit 1
else
  MEASURE="$2"
  FWHM="$3"
fi


SUBJECTS_FILE="$1"
## Check for given subjects file.
if [ ! -f "$SUBJECTS_FILE" ]; then
    echo "$APPTAG ERROR: Subjects file '$SUBJECTS_FILE' not found."
    exit 1
fi

NUM_CONSECUTIVE_JOBS="$4"
if [ -z "$NUM_CONSECUTIVE_JOBS" ]; then
    NUM_CONSECUTIVE_JOBS=22
    echo "$APPTAG Number of parallel jobs not specified on command line, defaulting to $NUM_CONSECUTIVE_JOBS jobs."
fi




# Check for borken line endings (Windows line endings, '\r\n') in subjects.txt file, a very common error.
# This script can cope with these line endings, but we still warn the user because other scripts may choke on them.
NUM_BROKEN_LINE_ENDINGS=$(grep -U $'\015' "${SUBJECTS_FILE}" | wc -l | tr -d '[:space:]')
if [ $NUM_BROKEN_LINE_ENDINGS -gt 0 ]; then
    echo "$APPTAG WARNING: Your subjects file '${SUBJECTS_FILE}' contains $NUM_BROKEN_LINE_ENDINGS incorrect line endings (Windows style line endings)."
    echo "$APPTAG WARNING: (cont.) While this script can work with them, you will run into trouble sooner or later, and you should definitely fix them (use  the 'tr' command or a proper text editor)."
fi

SUBJECTS=$(cat "${SUBJECTS_FILE}" | tr -d '\r' | tr '\n' ' ')    # fix potential windows line endings (delete '\r') and replace newlines by spaces as we want a list
SUBJECT_COUNT=$(echo "${SUBJECTS}" | wc -w | tr -d '[:space:]')


echo "$APPTAG Parallelizing over the ${SUBJECT_COUNT} subjects in file '${SUBJECTS_FILE}' using ${NUM_CONSECUTIVE_JOBS} threads."

# We can check already whether the subjects exist.
for SUBJECT in $SUBJECTS; do
  if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
    echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
    exit 1
  fi
done

################### JOB SETTINGS -- adjust this ##################

#echo ${SUBJECTS} | tr ' ' '\n' | parallel "echo {}"            # Debug: This only print one subject per line.

## The full command that will be run for each subject. The {} will be replaced by the subject id. You could get additional args from whereever and add them (e.g., from $2 .. $n of this script. Keep in mind that $1 is already in use!).


## A simple example for a command.
#PER_SUBJECT_CMD="recon-all -s {} -qcache -measure ${MEASURE}"



TEMPLATE_SUBJECT="fsaverage"
if [ -n "$5" ]; then
    TEMPLATE_SUBJECT="$5"
fi
echo "$APPTAG Using template subject '${TEMPLATE_SUBJECT}'."

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
CARGO_SCRIPT="${EXEC_PATH_OF_THIS_SCRIPT}/smooth_stddata_custom_subject.bash"

if [ ! -x "${CARGO_SCRIPT}" ]; then
    echo "$APPTAG ERROR: Cargo script at ${CARGO_SCRIPT} not found or not executable. Check path and/or run 'chmod +x <file>' on it to make it executable. Exiting."
    exit
fi

############ execution, no need to mess with this. ############
DATE_TAG=$(date '+%Y-%m-%d_%H-%M-%S')
echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_SMOOTH_FWHM_${FWHM}_PARALLEL_${DATE_TAG}.txt "$CARGO_SCRIPT {} $MEASURE $FWHM $TEMPLATE_SUBJECT"
