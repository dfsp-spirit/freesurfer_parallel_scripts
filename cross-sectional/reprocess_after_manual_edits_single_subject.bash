#!/bin/bash
## reprocess_after_manual_edits_single_subject.bash -- reprocess a single subject in FreeSurfer after edits
##
## There should be no need to run this script. It is called by the parallel wrapper script 'reprocess_after_manual_edits_parallel.bash' for each subject instead.
##
## Usage: reprocess_after_manual_edits_single_subject.bash <subject_id>, where the ID must end with '_gm' or '_wm'

APPTAG="[reproc_after_edits_single_subject]"
SUBJECT_ID="$1"


if [ -z "${SUBJECT_ID}" ]; then
    echo "USAGE: $0 <subject_id>"
    echo " <subject_id>: str, the subject directory name afte edits, must end with '_gm' or '_wm'."
    echo "Note: The SUBJECTS_DIR environment variable must be set properly."
    echo "      SUBJECTS_DIR currently points at '$SUBJECTS_DIR'."
    exit 1
fi

if [[ "${SUBJECT_ID}" == "*gm" ]]; then
    echo "$APPTAG Reprocessing subject $SUBJECT_ID after only gray matter edits..."
    recon-all -autorecon-pial -sd `pwd` -subjid $SUBJECT_ID -no-isrunning && recon-all -sd "${SUBJECTS_DIR}" -subjid $SUBJECT_ID -qcache
elif [[ "${SUBJECT_ID}" == "*wm" ]]; then
    echo "$APPTAG Reprocessing subject $SUBJECT_ID after white matter edits..."
    recon-all -autorecon2-wm -autorecon3 -sd `pwd` -subjid $SUBJECT_ID -no-isrunning && recon-all -sd "${SUBJECTS_DIR}" -subjid $SUBJECT_ID -qcache
else
  echo "$APPTAG WARNING: The name of subject '${SUBJECT_ID}' does not match edited directory names (_gm, _wm), skipping."
fi
