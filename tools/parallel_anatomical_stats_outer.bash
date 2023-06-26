#!/bin/bash
# parallel_anatomical_stats_outer.bash -- compute anatomical stats in parallel over a number of subjects.
#
# HOW TO TO USE THIS script
#  1) Copy it wherever you like and make sure it is executable
#  2) Set your SUBJECTS_DIR environment variable and change into your SUBJECTS_DIR. You should have a subjects.txt file in there.
#  3) Run: `path/to/parallel_anatomical_stats_outer.bash subjects.txt`
#
# Written by Tim, 2023-06-22
#


APPTAG="[PAR_ANAT_STATS]"

##### General settings #####

# Number of consecutive GNU Parallel jobs. Note that 0 for 'as many as possible'. Maybe set something a little bit less than the number of cores of your machine if you want to do something else while it runs.
# See 'man parallel' for details. On MacOS, try `sysctl -n hw.ncpu` to find the number of cores you have. On Linux, use 'nproc'.

# auto-determine number of parallel jobs
OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
    NUM_PARALLEL_JOBS="$(nproc --all)"
elif [ "$OS" = "Darwin" ] || \
        [ "$(echo "$OS" | grep -q BSD)" = "BSD" ]; then
    NUM_PARALLEL_JOBS="$(sysctl -n hw.ncpu)"
else
    NUM_PARALLEL_JOBS="$(getconf _NPROCESSORS_ONLN)"  # glibc/coreutils fallback
fi
# feel free to override manually here:
# NUM_PARALLEL_JOBS=8

#############################################################################################################################
## IMPORTANT: Make sure the correct atlas, hemi and measure is configured in the 'parallel_anatomical_stats_inner.bash' file.
#############################################################################################################################

###### End of job settings #####



## check some stuff
if [ -z "${SUBJECTS_DIR}" ]; then
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR not set."
fi

if [ -d "${SUBJECTS_DIR}/bert" ]; then
    echo "$APPTAG WARNING: Environment variable SUBJECTS_DIR seems to point at the subjects dir of the FreeSurfer installation: '${SUBJECTS_DIR}'. Configure it to point at your data!"
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
    echo "$APPTAG Usage: $0 <subjects_file>"
    exit 1
fi


SUBJECTS=$(cat "${SUBJECTS_FILE}" | tr '\n' ' ')
SUBJECT_COUNT=$(echo "${SUBJECTS}" | wc -w | tr -d '[:space:]')


echo "$APPTAG Parallelizing over the ${SUBJECT_COUNT} subjects in file '${SUBJECTS_FILE}' using $NUM_PARALLEL_JOBS threads."

# We can check already whether the subjects exist.
for SUBJECT in $SUBJECTS; do
  if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
    echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
    exit 1
  fi
done



EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
CARGO_SCRIPT="${EXEC_PATH_OF_THIS_SCRIPT}/parallel_anatomical_stats_inner.bash"

if [ ! -x "${CARGO_SCRIPT}" ]; then
    echo "ERROR: Cargo script not found or not executable at '${CARGO_SCRIPT}'."
    exit 1
fi

DATE_TAG=$(date '+%Y-%m-%d_%H-%M-%S')
echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_PARALLEL_JOBS} --workdir . --joblog LOGFILE_PARALLEL_ANATSTATS_${DATE_TAG}.txt "${CARGO_SCRIPT} {}"
