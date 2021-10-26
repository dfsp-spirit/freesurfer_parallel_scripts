#!/bin/bash
# parallel_gen_mid_surface.bash -- compute mid surface (50% thickness between white and pial) in parallel over a number of subjects.
#
# HOW TO TO USE THIS script
#  1) Copy it wherever you like and make sure it is executable (run `chmod +x parallel_gen_mid_surface.bash`)
#  2) Set your SUBJECTS_DIR environment variable and change into your SUBJECTS_DIR. You should have a subjects.txt file in there.
#  3) Run: `path/to/parallel_gen_mid_surface.bash subjects.txt`
#
# Written by Tim, 2019-05-10
#
# This script run mris_expand, which takes roughly 8 minutes per subject when run single-threaded. The speedup you get from using this
# parallel script depends on the NUM_CONSECUTIVE_JOBS you set below (provided you have enough cores, see below).

APPTAG="[PAR_MID_SURF]"

##### General settings #####

# Number of consecutive GNU Parallel jobs. Note that 0 for 'as many as possible'. Maybe set something a little bit less than the number of cores of your machine if you want to do something else while it runs.
# See 'man parallel' for details. On MacOS, try `sysctl -n hw.ncpu` to find the number of cores you have.
NUM_CONSECUTIVE_JOBS=7
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


echo "$APPTAG Parallelizing over the ${SUBJECT_COUNT} subjects in file '${SUBJECTS_FILE}' using $NUM_CONSECUTIVE_JOBS threads."

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


############ execution, no need to mess with this. ############

# Test only
#echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_MAP_PARALLEL_MIDSURF.txt "cd ${SUBJECTS_DIR}/{}/surf/ && touch testfile_{}.txt"

#echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_MAP_PARALLEL_MIDSURF.txt "cd ${SUBJECTS_DIR}/{}/surf/ && mris_expand -thickness lh.white 0.5 lh.graymid"

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
CARGO_SCRIPT="${EXEC_PATH_OF_THIS_SCRIPT}/parallel_gen_mid_surface_inner_cargo.bash"

if [ ! -x "${CARGO_SCRIPT}" ]; then
    echo "ERROR: Cargo script not found or not executable at '${CARGO_SCRIPT}'."
    exit 1
fi

DATE_TAG=$(date '+%Y-%m-%d_%H-%M-%S')
echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_MAP_PARALLEL_MIDSURF_${DATE_TAG}.txt "${CARGO_SCRIPT} {}"
