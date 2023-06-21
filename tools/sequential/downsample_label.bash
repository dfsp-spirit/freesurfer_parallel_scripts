#!/bin/bash
# downsample a label, e.g., downsample lh.cortex.label (ico7) to lh.cortex6.label (ico6) for a subject.
# The downsampled label can be used to find the cortical vertices (as opposed to the medial wall) for a subject on its ico6 surface.
# Usage: bash downsample_label.bash

APPTAG="[DS_LABEL]"
SUBJECT="subject1"
LABEL="cortex"
ICO_ORDER=6

export SUBJECTS_DIR=$(pwd)

if [ ! -d "${SUBJECT}" ]; then
    echo "${APPTAG} ERROR: Directory '${SUBJECT}' not found. Please run this script from the directory it is stored in."
    exit 1
fi

lh_output_label="./${SUBJECT}/label/lh.${LABEL}${ICO_ORDER}.label"
rh_output_label="./${SUBJECT}/label/rh.${LABEL}${ICO_ORDER}.label"
mri_label2label --srclabel ./${SUBJECT}/label/lh.${LABEL}.label --srcsubject "${SUBJECT}" --trglabel "${lh_output_label}" --trgsubject ico --regmethod surface --hemi lh --trgicoorder ${ICO_ORDER}
mri_label2label --srclabel ./${SUBJECT}/label/rh.${LABEL}.label --srcsubject "${SUBJECT}" --trglabel "${rh_output_label}" --trgsubject ico --regmethod surface --hemi rh --trgicoorder ${ICO_ORDER}

echo "${APPTAG} Done. Check for error messages above."
echo "${APPTAG} If everything went fine, labels were written to:"
echo "${APPTAG}  * lh: ${lh_output_label}"
echo "${APPTAG}  * rh: ${rh_output_label}"