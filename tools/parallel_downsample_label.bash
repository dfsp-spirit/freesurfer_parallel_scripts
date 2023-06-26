#!/bin/bash
# parallel_downsample_label.bash -- downsample a label (like <subject>/label/lh.cortex.label) in parallel for many subjects.
#
# HOW TO TO USE THIS script
#  1) Copy it wherever you like and make sure it is executable (run `chmod +x parallel_downsample_label.bash`)
#  2) Set your SUBJECTS_DIR environment variable and change into your SUBJECTS_DIR. You should have a subjects.txt file in there.
#  3) Run: `path/to/parallel_gen_mid_surface.bash subjects.txt`
#
# Written by Tim, 2023-06-26
#
# IMPORTANT: Run this from inside your recon-all output directory!

APPTAG="[PAR_DOWNSAMPLE_LABEL]"

##### General settings #####

# Number of consecutive GNU Parallel jobs. Note that 0 for 'as many as possible'. Maybe set something a little bit less than the number of cores of your machine if you want to do something else while it runs.
# See 'man parallel' for details. On MacOS, try `sysctl -n hw.ncpu` to find the number of cores you have.
NUM_CONSECUTIVE_JOBS=7
LABEL="cortex"
ICO_ORDER=6
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
    echo "$APPTAG Usage: $0 <subjects_file> [<label> [<ico_order>]]"
    echo "$APPTAG <subjects_file> : str, path to text file with one subject ID per line"
    echo "$APPTAG <label>         : str, the label, without hemi and '.label' suffix. Default: 'cortex'"
    echo "$APPTAG <ico_order>      : int, target hemisphere ICO order (mesh resolution). Must be 6, 5, 4, or 3. Default: 6.)"
    echo "$APPTAG Example: $0 subjects.txt"
    exit 1
fi


if [ -n "$2" ]; then
    LABEL=$2
fi

if [ -n "$3" ]; then
    ICO_ORDER=$3
fi


SUBJECTS=$(cat "${SUBJECTS_FILE}" | tr '\n' ' ')
SUBJECT_COUNT=$(echo "${SUBJECTS}" | wc -w | tr -d '[:space:]')


echo "$APPTAG Parallelizing over the ${SUBJECT_COUNT} subjects in file '${SUBJECTS_FILE}' using $NUM_CONSECUTIVE_JOBS threads."
echo "$APPTAG Label: '${LABEL}', ICO order: ${ICO_ORDER}."

# We can check already whether the subjects exist.
for SUBJECT in $SUBJECTS; do
  if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
    echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
    exit 1
  fi
done



EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
CARGO_SCRIPT="${EXEC_PATH_OF_THIS_SCRIPT}/downsample_label.bash"

if [ ! -x "${CARGO_SCRIPT}" ]; then
    echo "ERROR: Cargo script not found or not executable at '${CARGO_SCRIPT}'."
    exit 1
fi

DATE_TAG=$(date '+%Y-%m-%d_%H-%M-%S')
echo ${SUBJECTS} | tr ' ' '\n' | parallel --jobs ${NUM_CONSECUTIVE_JOBS} --workdir . --joblog LOGFILE_MAP_PARALLEL_DOWNSAMPLE_LABEL_${DATE_TAG}.txt "${CARGO_SCRIPT} {} $LABEL $ICO_ORDER"
