#!/bin/bash
# parallel_lgi_native.bash -- compute LGI in parallel over a number of subjects. This computes the lgi on the native surface of the subject, it does NOT map the results to fsaverage. Use the subpar script for that.
#
######################### IMPORTANT #############################
# Adapt the JOB SETTINGS at the end of this file to configure   #
# the command to run for each of the subject!                   #
######################### IMPORTANT #############################
#
# Written by Tim.
#
# I would recommend to run this from a `screen` session:
#   screen -S lgi_mydataset
#   cd data/lgi_mydataset
#   export SUBJECTS_DIR=$(pwd)
#   /path/to/this/script/parallel_lgi_native.bash subjects.txt
#
#   Then detach the screen session:
#     C-a d
#
#
####### USAGE:
# Make sure you have a subjects.txt file with one subject per line. Then, in BASH shell:
# 1) cd /path/to/my/reconall-output
# 2) export SUBJECTS_DIR=$(pwd)
# 3) path/to/parallel_lgi_native.bash ./subjects.txt

APPTAG="[PAR_LGI]"

##### General settings #####

# Number of consecutive GNU Parallel jobs. Note that 0 for 'as many as possible'. Maybe set something a little bit less than the number of cores of your machine if you want to do something else while it runs.
# See 'man parallel' for details. On MacOS, try `sysctl -n hw.ncpu` to find the number of cores you have.
NUM_CONSECUTIVE_JOBS=44
###### End of job settings #####



## check some stuff
if [ -z "${SUBJECTS_DIR}" ]; then
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR not set."
    exit 1
fi

if [ -d "${SUBJECTS_DIR}/bert" ]; then
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR seems to point at the subjects dir of the FreeSurfer installation: '${SUBJECTS_DIR}'. Configure it to point at your data!"
fi

if [ ! -f "${FREESURFER_HOME}/license.txt" ]; then
    echo "$APPTAG FreeSurfer license.txt file ńot found (or FREESURFER_HOME environment variable not set properly). RUn would fail, exiting."
    exit 1
fi

if [ -n "$1" ]; then
    SUBJECTS_FILE="$1"
    ## Check for given subjects file.
    if [ ! -f "$SUBJECTS_FILE" ]; then
        echo "$APPTAG ERROR: Subjects file '$SUBJECTS_FILE' not found."
        exit 1
    fi
else
    echo "$APPTAG ERROR: Must specify subjects_file. Exiting."
    echo "$APPTAG Usage: $0 <subjects_file> <job_arg1>..."
    exit 1
fi



SUBJECTS=$(cat "${SUBJECTS_FILE}" | tr '\n' ' ')
SUBJECT_COUNT=$(echo "${SUBJECTS}" | wc -w | tr -d '[:space:]')

if [ $NUM_CONSECUTIVE_JOBS -gt $SUBJECT_COUNT ]; then
    NUM_CONSECUTIVE_JOBS=$SUBJECT_COUNT
    echo "$APPTAG INFO: Reducing number of threads to the number of subjects, which is $SUBJECT_COUNT."
fi

echo "$APPTAG Parallelizing over the ${SUBJECT_COUNT} subjects in file '${SUBJECTS_FILE}' using $NUM_CONSECUTIVE_JOBS threads."

# We can check already whether the subjects exist.
for SUBJECT in $SUBJECTS; do
  if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
    echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
    exit 1
  fi
done


## recon-all -localLGI requires Matlab on the path
if [ -z "${MATLABPATH}" ]; then
    echo "$APPTAG WARNING: Environment variable MATLABPATH not set. Set it to your Matlab installation directory."
    echo "$APPTAG: (cont.) Example for BASH: 'export MATLABPATH=/Applications/MATLAB_R2019a.app/'"
fi

MATLAB_BINARY=$(which matlab)
if [ -z "${MATLAB_BINARY}" ]; then
    echo "$APPTAG: ERROR: Matlab executable is not on your path, but that is required by recon-all for lgi computation. Add MATLABPATH/bin/ to your PATH. Exiting."
    echo "$APPTAG: (cont.) Example for BASH: 'export PATH=\$PATH:\$MATLABPATH/bin'"
    exit 1
fi


################### JOB SETTINGS -- adjust this ##################

#echo ${SUBJECTS} | tr ' ' '\n' | parallel "echo {}"            # Debug: This only print one subject per line.

## The full command that will be run for each subject. The {} will be replaced by the subject id. You could get additional args from whereever and add them (e.g., from $2 .. $n of this script. Keep in mind that $1 is already in use!).


## A simple example for a command.
#PER_SUBJECT_CMD="recon-all -s {} -qcache -measure ${MEASURE}"

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
CARGO_SCRIPT="${EXEC_PATH_OF_THIS_SCRIPT}/compute_lgi.bash"

if [ ! -x "${CARGO_SCRIPT}" ]; then
    echo "$APPTAG ERROR: Cargo script at ${CARGO_SCRIPT} not found or not executable. Check path and/or run 'chmod +x <file>' on it to make it executable. Exiting."
    exit
fi

############ execution, no need to mess with this. ############
DATE_TAG=$(date '+%Y-%m-%d_%H-%M-%S')
echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_PARALLEL_LGI_${DATE_TAG}.txt "$CARGO_SCRIPT {}"


