#!/bin/bash

APPTAG="[CREATE_FSDIR]"

subject="$1"
subject_nii_file="$2"


if [ -z "$subject" ]; then
    echo "$APPTAG USAGE: $0 <subject> [<nifti_file>]"
    exit 1
fi

if [ -z "$subject_nii_file" ]; then
    subject_nii_file="${subject}.nii"
    echo "$APPTAG Assuming nifti file '$subject_nii_file' for subject '$subject'."
fi


if [ ! -f "$subject_nii_file" ]; then
    echo "$APPTAG ERROR: NIFTI file '$subject_nii_file' for subject '$subject' does not exist or cannot be read."
    exit 1
fi

echo "$APPTAG Using the current dir as working dir."

recon-all -sd `pwd` -i ${subject} -s ${subject_nii_file}"



