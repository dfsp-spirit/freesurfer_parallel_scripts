#!/bin/bash
# Compute anatomical stats for a one or more custom measures of a single subject. Can be run in parallel with wrapper 'parallel_anatomical_stats_outer.bash'.
# This script runs sequentially for one subject, and should be called via the parallel wrapper 'parallel_anatomical_stats_outer.bash' to run in parallel for multiple subjects.
# Written by Tim, 2023-06-22

APPTAG="[RUN_ANAT_STATS_SUBJECT]"


if [ -z "$1" ]; then
  echo "$APPTAG ERROR: Arguments missing."
  echo "$APPTAG Usage: $0 <subject>"
  echo "$APPTAG Note that the environment variable SUBJECTS_DIR must also be set correctly."
  exit 1
else
  SUBJECT="$1"
fi


if [ -z "$SUBJECTS_DIR" ]; then
    echo "$APPTAG ERROR: Environment variable SUBJECTS_DIR not set, you must export it."
    exit 1
fi

if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
    echo "$APPTAG ERROR: Directory for subject '${SUBJECT}' not found in SUBJECTS_DIR '${SUBJECTS_DIR}'. Exiting."
    exit 1
fi


### Settings ###

MEASURES="thickness area volume"
HEMIS="lh rh"
ATLAS="aparc.a2009s"

do_exit_on_missing_input="no" # only for missing input files. set to "yes" or "no".
do_exit_on_write_error="no" # only for write errors. we still exit if input files are missing. set to "yes" or "no".
skip_for_existing_files="yes" # set to "yes" or "no". whether to skip computation if the output file already exists.

### End Of Settings ####




for HEMI in $HEMIS; do
    for MEASURE in ${MEASURES}; do
        OUTPUT_FILE="${SUBJECTS_DIR}/${SUBJECT}/stats/${HEMI}.${ATLAS}.${MEASURE}.stats"

        if [ "${skip_for_existing_files}" = "yes" -a -f "${OUTPUT_FILE}" ]; then
            echo "$APPTAG Skipping subject $SUBJECT hemi $HEMI measure $MEASURE atlas $ATLAS because output file '${OUTPUT_FILE}' already exists."
            continue
        fi

        # Check for input files, as mris_anatomical_stats still does (useless) stuff if they are missing
        INPUT_FILE_ATLAS="${SUBJECTS_DIR}/${SUBJECT}/label/${HEMI}.${ATLAS}.annot"
        if [ ! -f "${INPUT_FILE_ATLAS}" ]; then
            if [ $do_exit_on_missing_input = "yes" ]; then
                echo "$APPTAG ERROR: Subject $SUBJECT: Input atlas file '${INPUT_FILE_ATLAS}' for atlas '${ATLAS}' hemi '${HEMI}' missing. Exiting."
                exit 1
            else
                echo "$APPTAG ERROR: Subject $SUBJECT: Input atlas file '${INPUT_FILE_ATLAS}' for atlas '${ATLAS}' hemi '${HEMI}' missing. Skipping."
                continue
            fi
        fi
        INPUT_FILE_MEASURE="${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE}"
        if [ ! -f "${INPUT_FILE_MEASURE}" ]; then
            if [ $do_exit_on_missing_input = "yes" ]; then
                echo "$APPTAG ERROR: Subject $SUBJECT: Input measure file (per-vertex data overlay) '${INPUT_FILE_MEASURE}' for measure '${MEASURE}' hemi '${HEMI}' missing. Exiting."
                exit 1
            else
                echo "$APPTAG ERROR: Subject $SUBJECT: Input measure file (per-vertex data overlay) '${INPUT_FILE_MEASURE}' for measure '${MEASURE}' hemi '${HEMI}' missing. Skipping."
                continue
            fi
        fi

        CMD="mris_anatomical_stats -a ${ATLAS}.annot -t ${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE} -f ${OUTPUT_FILE} ${SUBJECT} ${HEMI}"
        echo "$APPTAG ***Running for subject $SUBJECT hemi $HEMI measure $MEASURE with command: '$CMD'"
        $CMD
        if [ $? -eq 1 ]; then
            if [ "$do_exit_on_write_error" = "yes" ]; then
                echo "$APPTAG Call to mris_anatomical_stats failed (see above). Exiting."
                exit 1
            else
                echo "$APPTAG Call to mris_anatomical_stats failed (see above). No output file written for subject $SUBJECT hemi $HEMI measure $MEASURE atlas $ATLAS."
                continue
            fi
        fi

        echo "$APPTAG ***Done for subject $SUBJECT hemi $HEMI measure $MEASURE. Check output file '${OUTPUT_FILE}'."
        if [ ! -f "$OUTPUT_FILE" ]; then
            if [ "$do_exit_on_write_error" = "yes" ]; then
                echo "$APPTAG ERROR: Expected output file '${OUTPUT_FILE}' for subject $SUBJECT hemi $HEMI measure $MEASURE atlas $ATLAS missing. Check output above for errors. Exiting."
                exit 1
            else
                echo "$APPTAG ERROR: Expected output file '${OUTPUT_FILE}' for subject $SUBJECT hemi $HEMI measure $MEASURE atlas $ATLAS missing. Check output above for errors."
                continue
            fi
        fi
    done

done
