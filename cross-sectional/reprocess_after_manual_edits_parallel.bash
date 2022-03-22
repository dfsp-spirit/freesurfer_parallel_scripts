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
for SUBJECT_ID in $SUBJECTS; do
    if [ ! -d "${SUBJECTS_DIR}"/"${SUBJECT_ID}" ]; then
        echo "Missing data dir for subject '$SUBJECT_ID' under SUBJECTS_DIR '$SUBJECTS_DIR'. Exiting."
        exit 1
    fi
done

EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
PATH_TO_SSCRIPT="$EXEC_PATH_OF_THIS_SCRIPT/$SCRIPT_FOR_SINGLE_SUBJECT"
if [ ! -f "$PATH_TO_SSCRIPT" ]; then
    echo "$APPTAG ERROR: Script to process a single subject '${SCRIPT_FOR_SINGLE_SUBJECT}' not found."
    exit 1
fi

cat ${SUBJECTS_FILE} | parallel --workdir . --joblog LOGFILE_REPROCESS_AFTER_EDITS.txt "$PATH_TO_SSCRIPT {}"
