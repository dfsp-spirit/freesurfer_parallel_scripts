#!/bin/bash
#
# Map morphometry (per-vertex) data from fsaverage to fsaverage6. Actually this can be any subjects.
#
# This works for native and standard space data:
# Note that template subject (standard space) data can just be treated as native space data for a subject
# that happens to be a template subject. So this script maps from native space of src_subject to native
# space of trg_subject. Whether these are templates (like fsaverage6) does not matter.
#
# USAGE:
# 1) Run this is a directory that has the FreeSurfer folders for the sourcve and target subjects
# 2) Place the data to be mapped in the surf/ dir of the source subject in the expected files,
# i.e., surf/lh.<measure> and surf/rh.<measure>.
#
# If you have the source data in MGH/MGZ format, you can convert it to curv format with the
# mris_convert tool using the -c switch (do not add a file extension to the output file).
#
# Written by TS, 2021-10-08.

### Settings ###
src_subject="fsaverage"
trg_subject="fsaverage6"
do_perform_smoothing="no"  # Needs to be "yes" if you want to smooth in target space after the mapping.

### Start of script ###

apptag="[MAP_PVD_BETWEEN_SUBJECTS]##### "

measure="$1"
if [ -z "$measure" ]; then
  echo "USAGE: $0 <measure>"
  echo "Note: The curv files with the measure data to be mapped are expected to be at:"
  echo "  * $src_subject/surf/lh.<measure>"
  echo "  * $src_subject/surf/rh.<measure>"
  exit 1
fi

export SUBJECTS_DIR=$(pwd)

if [ ! -d "$src_subject" ]; then
  echo "Missing source subject directory '$src_subject', please run in a directory that has it."
  exit 1
fi

if [ ! -d "$trg_subject" ]; then
  echo "Missing target subject directory '$strg_subject', please run in a directory that has it."
  exit 1
fi


for hemi in lh rh; do
  src_file="$src_subject/surf/${hemi}.$measure"
  if [ ! -f "$src_file" ]; then
    echo "$apptag ERROR: Missing hemi $hemi input file '$src_file'. Exiting."
    exit 1
  fi
  mapped_file="$src_subject/surf/${hemi}.${measure}.${trg_subject}.mgh"
  echo "$apptag Mapping '$measure' data for hemi $hemi from $src_subject to $trg_subject."
  echo "$apptag Reading source data for hemi $hemi from '$src_file', writing to '$mapped_file'."

  mris_apply_reg --src $src_file --streg $src_subject/surf/${hemi}.sphere.reg $trg_subject/surf/${hemi}.sphere.reg --trg $mapped_file
  if [ ! -f "$mapped_file" ]; then
    echo "$apptag ERROR: Expected output mapped file '$mapped_file' does not exist".
    exit 1
  else
    echo "$apptag Mapped file for hemi $hemi written to '$mapped_file'."
  fi

  # Optional: smooth data in target space.
  if [ "$do_perform_smoothing" = "yes" ]; then
    for fwhm in 0 5 10 15 20 25; do
      echo "$apptag Smoothing mapped data on surface of subject $trg_subject with fwhm $fwhm."
      mapped_smoothed_file="$src_subject/surf/${hemi}.${measure}.fwhm$fwhm.${trg_subject}.mgh"
      mri_surf2surf --prune --s $trg_subject --hemi ${hemi} --fwhm $fwhm --sval $mapped_file --tval $mapped_smoothed_file
      if [ ! -f "$mapped_file" ]; then
        echo "$apptag ERROR: Expected output mapped and smoothed file '$mapped_smoothed_file' does not exist".
        exit 1
      else
        echo "$apptag Smoothed file for hemi $hemi FWHM $fwhm written to '$mapped_smoothed_file'."
      fi
    done
  else
    echo "$apptag Not smoothing data in target space."
  fi

done
