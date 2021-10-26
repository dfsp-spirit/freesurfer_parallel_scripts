#!/bin/bash
# smooth_stddata_custom_subject.bash -- smooth standard space data with a custom FWHM setting, i.e.,
# typically something other than the settings 0, 5, 10, 15, 20, 25 which are produced by default.
#
# This script assumes that the measure data has already been mapped to standard space, i.e., the
# files <subject>/surf/?h.<measure>.fsaverage.mgh must already exist for all subjects.
#
# Note that you can run this from smooth_stddata_custom_parallel.bash to apply it to several subjects in parallel.
#
# Written by Tim Schaefer, 2020-06-11

APPTAG="[SMOOTH_CUSTOM]"

if [ -z "$3" ]; then
  echo "$APPTAG ERROR: Arguments missing."
  echo "$APPTAG Usage: $0 <subject> <measure> <fwhm> [<template_subject>]"
  echo "$APPTAG Note that the environment variable SUBJECTS_DIR must also be set correctly."
  echo "$APPTAG If you omit <template_subject>, we assume fsaverage."
  exit 1
else
  SUBJECT="$1"
  MEASURE="$2"
  FWHM="$3"
fi

TEMPLATE_SUBJECT="fsaverage"
if [ -n "$4" ]; then
    TEMPLATE_SUBJECT="$4"
fi


#### settings ####

# Whether to run even if the output files already exist. Set to 'YES' for yes, or anything else for no.
FORCE="NO"

#### check some basic stuff first

if [ -z "${SUBJECTS_DIR}" ]; then
  echo "$APPTAG ERROR: Environment variable SUBJECTS_DIR not set. Exiting."
  exit 1
fi

if [ ! -d "${SUBJECTS_DIR}" ]; then
  echo "$APPTAG ERROR: Environment variable SUBJECTS_DIR points to '${SUBJECTS_DIR}' but that directory does NOT exist. Exiting."
  exit 1
fi


if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
  echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
  exit 1
fi


LH_EXPECTED_INPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.${MEASURE}.${TEMPLATE_SUBJECT}.mgh"
RH_EXPECTED_INPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.${MEASURE}.${TEMPLATE_SUBJECT}.mgh"
if [ -f "${LH_EXPECTED_INPUT}" -a -f "${RH_EXPECTED_INPUT}" ]; then
    echo "$APPTAG Measure ${MEASURE} for subject '${SUBJECT}: expected input files found."
else
    echo "$APPTAG ERROR: Measure ${MEASURE} for subject '${SUBJECT}': expected input files '${LH_EXPECTED_INPUT}' and/or '${RH_EXPECTED_INPUT}' missing."
    exit 1
fi


#### ok, lets go

LH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.${MEASURE}.fwhm${FWHM}.${TEMPLATE_SUBJECT}.mgh"
RH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.${MEASURE}.fwhm${FWHM}.${TEMPLATE_SUBJECT}.mgh"


DO_RUN="YES"
if [ -f "${LH_EXPECTED_OUTPUT}" -a -f "${RH_EXPECTED_OUTPUT}" ]; then
    if [ "$FORCE" != "YES" ]; then
        DO_RUN="NO"
        echo "$APPTAG Measure ${MEASURE} at FWHM ${FWHM} done already for subject '${SUBJECT}', skipping."
    else
        echo "$APPTAG Measure ${MEASURE} at FWHM ${FWHM} done already for subject '${SUBJECT}', but FORCE is set, re-running."
    fi
else
    echo "$APPTAG Measure ${MEASURE} at FWHM ${FWHM} not done yet for subject '$SUBJECT.' Running..."
fi

if [ "$DO_RUN" = "YES" ]; then

    if [ ! -d "${SUBJECTS_DIR}/${TEMPLATE_SUBJECT}" ]; then
        echo "Template subject directory does not exist at '${SUBJECTS_DIR}/${TEMPLATE_SUBJECT}', please fix. Exiting."
        exit 1
    fi
    for HEMI in lh rh; do
        ##### Smooth data:
        MAPPED_DATA_FILE_SMOOTHED="${SUBJECT}/surf/${HEMI}.${MEASURE}.fwhm${FWHM}.${TEMPLATE_SUBJECT}.mgh"
        mri_surf2surf --prune --s ${TEMPLATE_SUBJECT} --hemi ${HEMI} --fwhm ${FWHM} --sval ${SUBJECT}/surf/${HEMI}.${MEASURE}.${TEMPLATE_SUBJECT}.mgh --tval ${MAPPED_DATA_FILE_SMOOTHED}
    done
fi
