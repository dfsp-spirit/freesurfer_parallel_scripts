#!/bin/bash
# Compute anatomical stats for a custom measure and join them for all subjects into a table.
# Written by Tim, 2019-08-27

APPTAG="[RUN_ANAT_STATS]"

if [ -z "$SUBJECTS_DIR" ]; then
    echo "$APPTAG ERROR: Environment variable SUBJECTS_DIR not set, you must export it."
    exit 1
fi

SUBJECTS_FILE="${SUBJECTS_DIR}/subjects.txt"

echo "$APPTAG Using subjects file from '${SUBJECTS_FILE}'"

ALL_SUBJECT_IDS=$(cat "${SUBJECTS_FILE}" | tr '\n' ' ')
SUBJECT_COUNT=$(echo "$ALL_SUBJECT_IDS" | wc -w | tr -d '[:space:]')

MEASURE="pial_lgi"
HEMIS="lh rh"
ATLAS="aparc"

for HEMI in $HEMIS; do
    for SUBJECT in ${ALL_SUBJECT_IDS}; do
        OUTPUT_FILE="${SUBJECTS_DIR}/${SUBJECT}/stats/${HEMI}.${ATLAS}.${MEASURE}.stats"

        # Check for input files, as mris_anatomical_stats still does (useless) stuff if they are missing
        INPUT_FILE_ATLAS="${SUBJECTS_DIR}/${SUBJECT}/label/${HEMI}.${ATLAS}.annot"
        if [ ! -f "${INPUT_FILE_ATLAS}" ]; then
            echo "$APPTAG ERROR: Subject $SUBJECT: Input atlas file '${INPUT_FILE_ATLAS}' for atlas '${ATLAS}' hemi '${HEMI}' missing."
            exit 1
        fi
        INPUT_FILE_MEASURE="${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE}"
        if [ ! -f "${INPUT_FILE_MEASURE}" ]; then
            echo "$APPTAG ERROR: Subject $SUBJECT: Input measure file '${INPUT_FILE_MEASURE}' for measure '${MEASURE}' hemi '${HEMI}' missing."
            exit 1
        fi

        CMD="mris_anatomical_stats -a ${ATLAS}.annot -t ${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE} -f ${OUTPUT_FILE} ${SUBJECT} ${HEMI}"
        echo "$APPTAG ***Running for subject $SUBJECT hemi $HEMI with command: '$CMD'"
        $CMD
        if [ $? -eq 1 ]; then
            echo "$APPTAG Call to mris_anatomical_stats failed (see above). Exiting."
            exit 1
        fi

        echo "$APPTAG ***Done for subject $SUBJECT hemi $HEMI. Check output file '${OUTPUT_FILE}'."
        if [ ! -f "$OUTPUT_FILE" ]; then
            echo "$APPTAG ERROR: Expected output file '${OUTPUT_FILE}' missing.  Check output above for errors."
            exit 1
        fi
    done

    echo "$APPTAG Running aparcstats2table for all subjects, hemi '${HEMI}'."
    OUTPUT_TABLE_FILE="${ATLAS}.${MEASURE}_${HEMI}.txt"
    aparcstats2table --subjectsfile=${SUBJECTS_FILE} --hemi ${HEMI} --meas thickness --parc ${ATLAS}.${MEASURE} --tablefile ${OUTPUT_TABLE_FILE}
    if [ $? -eq 1 ]; then
        echo "$APPTAG Call to aparcstats2table failed (see above). Exiting."
        exit 1
    fi
    if [ ! -f "${OUTPUT_TABLE_FILE}" ]; then
        echo "$APPTAG ERROR: Expected output table file '${OUTPUT_TABLE_FILE}' missing. Check output above for errors."
        exit 1
    fi
    echo "$APPTAG aparcstats2table completed, check output file '${OUTPUT_TABLE_FILE}'."
    echo "$APPTAG IMPORTANT: The statistics are stored in the 'thickness' column in the per-subject output files (there is no column for custom measures), but they are still for your measure '${MEASURE}'."

done
