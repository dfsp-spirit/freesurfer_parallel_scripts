#!/bin/bash
# map_to_fsaverage_single_subject.bash -- run recon-all -qcache for a measure (i.e., map it to fsaverage) unless the expected output file already exists.
# Note that you can run this from map_to_fsaverage_parallel.bash to apply it to several subjects in parallel.

APPTAG="[MAP_SINGLE]"

if [ -z "$2" ]; then
  echo "$APPTAG ERROR: Arguments missing."
  echo "$APPTAG Usage: $0 <subject> <measure> [[[<template_subject>] <force>] <rename_only>]"
  echo "$APPTAG * Note that the environment variable SUBJECTS_DIR must also be set correctly."
  echo "$APPTAG   The SUBJECTS_DIR is set to: '$SUBJECTS_DIR'."
  echo "$APPTAG Arguments:"
  echo "$APPTAG  <subject> the subject you want to map. its recon-all output dir must exist in SUBJECTS_DIR."
  echo "$APPTAG  <measure> the native space descriptor you want to map. Typically something like 'thickness', 'pial_lgi', 'area'."
  echo "$APPTAG  <template_subject> the template subject to use. Defaults to 'fsaverage'."
  echo "$APPTAG  <force> 'YES' or 'NO', whether to re-map the data even if the ouput files already exist. Defaults to 'NO'."
  echo "$APPTAG  <rename_only> 'YES' or 'NO', whether to rename the files only and convert to MGH. See script for details. Defaults to 'NO'."
  exit 1
else
  SUBJECT="$1"
  MEASURE="$2"
fi

TEMPLATE_SUBJECT="fsaverage"

if [ -n "$3" ]; then
  TEMPLATE_SUBJECT="$3"
fi

#### Settings ####

# Whether to run even if the output files already exist. Set to 'YES' for yes, or anything else for no.
# Setting this to NO will save you *a lot* of time if parts of your subjects are already done.
FORCE="NO"
if [ -n "$4" ]; then
    FORCE="$4"
fi

# Whether to really run the mapping. Set to NO for a dry-run that prints what it would do.
DO_RUN="YES" # Ignore this, leave at "YES". It is for development/testing only.

### Read this section to understand the parameter 'rename_only'. ###
# Set the next value to YES only if the per-vertex data you want to map has been computed on a down-sampled native space mesh that is
# equivalent to the target template you are using (e.g., you downsampled native space meshes to fsaverage6-equivalent vertex count, computed
# some descriptor on them, and do now only want to smooth those data).
# In that case, the curv files containing the data will simply be smoothed and renamed (and the format converted to MGH) to the expected filename.
# If you did a more standard analysis and simply want to map native space data to a template like fsaverage or
# fsaverage6 (where the vertex counts of the native space brain and the template differ), the setting needs to be "NO".
#
# If in doubt,set this to "NO". An example where this is typically set to "YES" would be geodesic distances, which are often computed on
# downsampled meshes (with vertex count identical to fsaverage6!) as they take too long on full resolution meshes. In that
# case, TEMPLATE_SUBJECT would be "fsaverage6" instead of the default "fsaverage".
SOURCE_PER_VERTEX_DATA_IS_ALREADY_IN_TARGET_TEMPLATE_SPACE="NO"
if [ -n "$5" ]; then
    SOURCE_PER_VERTEX_DATA_IS_ALREADY_IN_TARGET_TEMPLATE_SPACE="$5"
fi

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

LH_EXPECTED_INPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.${MEASURE}"
RH_EXPECTED_INPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.${MEASURE}"
if [ -f "${LH_EXPECTED_INPUT}" -a -f "${RH_EXPECTED_INPUT}" ]; then
    echo "$APPTAG Measure ${MEASURE} for subject '${SUBJECT}: expected input files found."
else
    echo "$APPTAG WARNING: Measure ${MEASURE} for subject '${SUBJECT}': expected input files '${LH_EXPECTED_INPUT}' and/or '${RH_EXPECTED_INPUT}' missing."
fi


#### ok, lets go

LH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.${MEASURE}.${TEMPLATE_SUBJECT}.mgh"
RH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.${MEASURE}.${TEMPLATE_SUBJECT}.mgh"



if [ -f "${LH_EXPECTED_OUTPUT}" -a -f "${RH_EXPECTED_OUTPUT}" ]; then
    if [ "$FORCE" != "YES" ]; then
        DO_RUN="NO"
        echo "$APPTAG Measure ${MEASURE} done already for subject '${SUBJECT}', skipping."
    else
        echo "$APPTAG Measure ${MEASURE} done already for subject '${SUBJECT}', but FORCE is set, re-running."
    fi
else
    echo "$APPTAG Measure ${MEASURE} not done yet for subject '$SUBJECT.' Running..."
fi

if [ "$DO_RUN" = "YES" ]; then
    #if [ "$TEMPLATE_SUBJECT" = "fsaverage" ]; then
    if [ "$TEMPLATE_SUBJECT" = "__no_such__template__" ]; then # This branch is currently disabled, we can handle fsaverage also in the branch below and THIS branch does not work for longitufinally processed subjects.
        recon-all -s $SUBJECT -qcache -no-isrunning -measure ${MEASURE}
    else
        if [ ! -d "${SUBJECTS_DIR}/${TEMPLATE_SUBJECT}" ]; then
            echo "$APPTAG Template subject directory does not exist at '${SUBJECTS_DIR}/${TEMPLATE_SUBJECT}', please fix. Exiting."
            exit 1
        fi
        for HEMI in lh rh; do
            ###### Map native space data to the template subject:
            MAPPED_DATA_FILE_UNSMOOTHED="${SUBJECT}/surf/${HEMI}.${MEASURE}.${TEMPLATE_SUBJECT}.mgh"
            if [ "$SOURCE_PER_VERTEX_DATA_IS_ALREADY_IN_TARGET_TEMPLATE_SPACE" = "YES" ]; then
                mri_convert "${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE}" "${MAPPED_DATA_FILE_UNSMOOTHED}"
            else
                mris_apply_reg --src ${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.${MEASURE} --streg ${SUBJECTS_DIR}/${SUBJECT}/surf/${HEMI}.sphere.reg ${SUBJECTS_DIR}/${TEMPLATE_SUBJECT}/surf/${HEMI}.sphere.reg --trg ${MAPPED_DATA_FILE_UNSMOOTHED}
            fi

            if [ ! -f "${MAPPED_DATA_FILE_UNSMOOTHED}" ]; then
                echo "$APPTAG ERROR: Could not create unsmoothed standard space data file '${MAPPED_DATA_FILE_UNSMOOTHED}' for subject ${SUBJECT} hemi '${HEMI}'."
            else
                for FWHM in 0 5 10 15 20 25; do
                    MAPPED_DATA_FILE_SMOOTHED="${SUBJECT}/surf/${HEMI}.${MEASURE}.fwhm${FWHM}.${TEMPLATE_SUBJECT}.mgh"
                    mri_surf2surf --prune --s ${TEMPLATE_SUBJECT} --hemi ${HEMI} --fwhm ${FWHM} --sval ${SUBJECT}/surf/${HEMI}.${MEASURE}.${TEMPLATE_SUBJECT}.mgh --tval ${MAPPED_DATA_FILE_SMOOTHED}
                    if [ ! -f "${MAPPED_DATA_FILE_SMOOTHED}" ]; then
                        echo "$APPTAG ERROR: Failed to create smoothed standard space data file '${MAPPED_DATA_FILE_SMOOTHED}' for subject ${SUBJECT} hemi '${HEMI}' at FWHM ${FWHM}."
                    fi
                done
            fi

            #### Generate sphere reg file (surface registration of our subject with the template subject). This will take a while. Requires the reg template TIFF file for the template subject.
            #### For template subjects that come with FreeSurfer like fsaverage5, it is in the respective folder, so we load it from there.
            ## This is commented out because it is not needed with the mri_surf2surf solution below. The registration is also quite slow.
            ## mris_register -curv ${SUBJECT}/surf/${HEMI}.sphere ${TEMPLATE_SUBJECT}/${HEMI}.reg.template.tif ${SUBJECT}/surf/${HEMI}.${TEMPLATE_SUBJECT}.sphere.reg

            ##### Smooth the result with several kernels:
            # #####   mri_surf2surf --prune --s $SUBJECT --hemi ${HEMI} --fwhm ${FWHM} --sval ${MAPPED_DATA_FILE_UNSMOOTHED} --tval ${MAPPED_DATA_FILE_SMOOTHED} --cortex
            #    mri_surf2surf --prune --s fsaverage6 --hemi lh --fwhm 5 --sval subject1/surf/lh.thickness.fsaverage6.mgz --tval subject1/surf/lh.thickness.fwhm5.fsaverage6.mgz
            #
            #
            # mri_surf2surf --prune --s subject1 --hemi lh --fwhm 5 --sval subject1/surf/lh.thickness --tval subject1/surf/lh.thickness.fwhm5.fsaverage6.mgz --srcsurfreg sphere.reg --trgsurfreg fsaverage6.sphere.reg
        done
    fi
fi
