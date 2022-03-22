#!/bin/bash
## reproc_single_subject_after_edits.bash -- preprocess a single subject in FreeSurfer
##
## There should be no need to run this script. It is called by the parallel wrapper script, preproc_reconall_parallel.bash. Run that one instead.
##
## Usage: preproc_single_subject.bash <subject_id>

APPTAG="[reproc_after_edits_single_subject]"
SUBJECT_ID="$1"


if [ -z "${SUBJECT_ID}" ]; then
    echo "USAGE: $0 <subject_id>"
    exit 1
fi

if [[ "${SUBJECT_ID}" == *gm ]]; then
    echo "$APPTAG Reprocessing subject $SUBJECT_ID after only gray matter edits..."
    recon-all -autorecon-pial -sd `pwd` -subjid $subjid -no-isrunning && recon-all -sd "${SUBJECTS_DIR}" -subjid $subjid -qcache
elif [[ "${SUBJECT_ID}" == *wm ]]; then
    echo "$APPTAG Reprocessing subject $SUBJECT_ID after white matter edits..."
    recon-all -autorecon2-wm -autorecon3 -sd `pwd` -subjid $subjid -no-isrunning && recon-all -sd "${SUBJECTS_DIR}" -subjid $subjd -qcache
else
  echo "WARNING: The name of subject '${SUBJECT_ID}' does not match edited directory names (_gm, _wm), skipping."
fi
