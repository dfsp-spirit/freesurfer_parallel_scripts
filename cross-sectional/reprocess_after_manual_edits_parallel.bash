#!/bin/bash
# reprocess subjects in parallel after manual edits.
# the subject names must end with '_gm' or '_wm', all others will be ignored.

export SUBJECTS_DIR=$(pwd)
APPTAG="[REPROC_EDITS_PARALLEL]"

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
NUM_CORES_TO_USE=47                                       # Should be slighly *below* total core count. If you use all, it will be a pain to anything on the machine while this runs. Leave 1 or 2 cores alone.
SCRIPT_FOR_SINGLE_SUBJECT="reprocess_after_manual_edits_single_subject.bash"


SUBJECTS_FILE=$1
if [ -z "$SUBJECTS_FILE" ]; then                              # name of subjects file that will be generated (and used) by this script
  echo "USAGE: $0 <subjects_file> [<num_cores>]"
  echo " <subjects_files>: str, path to text file containing one subject dir name after edits per line."
  echo "                   I.e., the names must end with '_gm' or '_wm'. Other subjects will be ignored."
  echo "Note: The SUBJECTS_DIR environment variable must also be set properly."
  echo "      SUBJECTS_DIR currently points at '$SUBJECTS_DIR'."
  exit 1
fi

if [ ! -f "$SUBJECTS_FILE" ]; then
  echo "$APPTAG Cannot read subjects_file $SUBJECTS_FILE, exiting."
  exit 1
fi

if [ -n "$2" ]; then
  NUM_CORES_TO_USE=$2
fi



# Check for GNU parallel
PARALLEL_BINARY=$(which parallel)
if [ -z "${PARALLEL_BINARY}" ]; then
    echo "$APPTAG ERROR: Could not find 'parallel' on the PATH. Ensure that 'GNU Parallel' is installed. Exiting."
    exit 1
fi

NUM_SUBJECTS=$(cat ${SUBJECTS_FILE} | wc -l | tr -d '[:space:]')
echo "$APPTAG Running recon-all reprocessing after edits in parallel for ${NUM_SUBJECTS} subjects from file $SUBJECTS_FILE using $NUM_CORES_TO_USE cores."

SUBJECTS=$(cat ${SUBJECTS_FILE} | tr '\n' ' ')

num_subects_will_be_handled=0
num_subects_will_be_skipped=0

# Some sanity checks.
for SUBJECT_ID in $SUBJECTS; do
  # check whether subject dir exists.
    if [ ! -d "${SUBJECTS_DIR}"/"${SUBJECT_ID}" ]; then
        echo "$APPTAG Missing data dir for subject '$SUBJECT_ID' under SUBJECTS_DIR '$SUBJECTS_DIR'. Exiting."
        exit 1
    fi
    # Check whether subject names have the correct patterns.
    if [[ "${SUBJECT_ID}" == "*gm" -o "${SUBJECT_ID}" == "*wm" ]]; then
        num_subects_will_be_handled=$((num_subects_will_be_handled+1))
    else
        num_subects_will_be_skipped=$((num_subects_will_be_skipped+1))
        echo "$APPTAG WARNING: Subject '${SUBJECT_ID}' does not follow naming convention ('_gm' / '_wm' suffix) and will be skipped."
    fi
done

if [ $num_subects_will_be_handled -eq 0 ]; then
    echo "$APPTAG None of the $NUM_SUBJECTS subjects in the subjects file adhere to the required naming convention ('_gm' / '_wm' suffix). Would not do anything. Stopping now."
fi

echo "$APPTAG Out of the $NUM_SUBJECTS subjects in the subjects file, $num_subects_will_be_handled will be re-processed and $num_subects_will_be_skipped will be ignored because they do not adhere to the required naming convention ('_gm' / '_wm' suffix)."

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
PATH_TO_SSCRIPT="$EXEC_PATH_OF_THIS_SCRIPT/$SCRIPT_FOR_SINGLE_SUBJECT"
if [ ! -f "$PATH_TO_SSCRIPT" ]; then
    echo "$APPTAG ERROR: Script to process a single subject '${SCRIPT_FOR_SINGLE_SUBJECT}' not found."
    exit 1
fi

cat ${SUBJECTS_FILE} | parallel --workdir . --joblog LOGFILE_REPROCESS_AFTER_EDITS.txt "$PATH_TO_SSCRIPT {}"
