#!/bin/bash
## preproc_single_subject.bash -- preprocess a single subject in FreeSurfer
##
## There should be no need to run this script. It is called by the parallel wrapper script, preproc_reconall_parallel.bash. Run that one instead.
##
## Usage: preproc_single_subject.bash <subject_id>

APPTAG="[preproc_single_subject.bash]"
SUBJECT_ID="$1"

# Set path to an optional t2-weighted image for the subject. If you have no t2 image, you can set this to the empty string to avoid the warning message that the file is missing.
#T2_FILE_PATH="T2/${SUBJECT_ID}_T2.nii"
FLAIR_FILE_PATH="T2/${SUBJECT_ID}_FLAIR.nii"
T2_FILE_PATH="T2/${SUBJECT_ID}_FRFSE.nii"


if [ -z "${SUBJECT_ID}" ]; then
    echo "USAGE: $0 <subject_id>"
    exit 1
fi


# Check for T2 data
T2_OPTIONS=""
if [ -n "${FLAIR_FILE_PATH}" ]; then
    if [ -f "${FLAIR_FILE_PATH}" ]; then
        T2_OPTIONS="-FLAIR ${FLAIR_FILE_PATH} -FLAIRpial"
    else
        echo "$APPTAG NOTICE: Checked for FLAIR image for subject ${SUBJECT_ID} at '${FLAIR_FILE_PATH}' but found none for this subject."
    fi
fi

if [ -n "${T2_FILE_PATH}" ]; then
    if [ -z "T2_OPTIONS" ]; then  # if this is not empty anymore, a FLAIR image is available, and we want to use that instread of the T2.
        if [ -f "${T2_FILE_PATH}" ]; then
            T2_OPTIONS="-T2 ${T2_FILE_PATH} -T2pial"
        else
            echo "$APPTAG NOTICE: Checked for t2-weighted image for subject ${SUBJECT_ID} at '${T2_FILE_PATH}' but found none for this subject."
        fi
    fi
fi

recon-all -autorecon-all -sd `pwd` -subjid $SUBJECT_ID $T2_OPTIONS -no-isrunning -qcache
