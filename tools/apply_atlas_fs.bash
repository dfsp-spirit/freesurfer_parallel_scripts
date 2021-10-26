#!/bin/bash
# apply_atlas_fs.bash -- apply a brain parcellation atlas to a list of subjects (which have been pre-processed in FreeSurfer)
#
# written by Tim Schaefer, http://rcmd.org/ts/, 2019-03-19
#
# USAGE: Set SUBJECTS_DIR as usual (it's a FreeSurfer standard environment variable), then adapt the settings below to your needs.
# You will most likely have to change only ATLAS_INSTALL_DIR and ATLAS_ANNOT_FILE_NAME_NO_HEMI, and maybe OUTPUT_SEGMENTATION_FILE_NAME.
#
# The currently set values are examples for usage with the following atlas:
#
#    Schaefer A, Kong R, Gordon EM, Laumann TO, Zuo XN, Holmes AJ, Eickhoff SB, Yeo BTT. Local-Global parcellation of the
#    human cerebral cortex from intrinsic functional connectivity MRI, Cerebral Cortex, 29:3095-3114, 2018
#
#    See https://github.com/ThomasYeoLab/CBIG/tree/master/stable_projects/brain_parcellation/Schaefer2018_LocalGlobal for the download.
#
# (To prevent any confusion: that atlas was NOT made by the author of this shell script, even though we have the same last name.)



##### Settings #####

# The following subjects must exist as directories under $SUBJECTS_DIR
SUBJECTS="tim"

# The input files of that atlas that should be applied
ATLAS_INSTALL_DIR="${HOME}/Downloads/Parcellations/FreeSurfer5.3/fsaverage/label"
ATLAS_ANNOT_FILE_NAME_NO_HEMI="Schaefer2018_400Parcels_7Networks_order.annot"
ATLAS_ANNOT_FILE_NAME_LH="lh.${ATLAS_ANNOT_FILE_NAME_NO_HEMI}"
ATLAS_ANNOT_FILE_NAME_RH="rh.${ATLAS_ANNOT_FILE_NAME_NO_HEMI}"
ATLAS_ANNOT_FILE_LH="${ATLAS_INSTALL_DIR}/${ATLAS_ANNOT_FILE_NAME_LH}"
ATLAS_ANNOT_FILE_RH="${ATLAS_INSTALL_DIR}/${ATLAS_ANNOT_FILE_NAME_RH}"

# The output annotation (cortex parcellation) files, i.e., the file names for the output labels for each individual subject. Will be saved in the subject's label/ directory.
OUTPUT_ANNOT_FILE_NAME_NO_HEMI_NO_EXT="Schaefer2018_400Parcels_7Networks_order"
OUTPUT_ANNOT_FILE_NAME_LH="lh.${OUTPUT_ANNOT_FILE_NAME_NO_HEMI_NO_EXT}.annot"    # naming them after the atlas they originate from is not a bad idea
OUTPUT_ANNOT_FILE_NAME_RH="rh.${OUTPUT_ANNOT_FILE_NAME_NO_HEMI_NO_EXT}.annot"

# The output segmentation files. Will be stored in the subject's mri/ directory. Should have mgh or mgz file extension.
OUTPUT_SEGMENTATION_FILE_NAME="outputfile.mgz"

##### Check stuff #####

APPTAG="[APPLY_ATLAS]"
if [ -z "${SUBJECTS_DIR}" ]; then
    echo "${APPTAG} ERROR: Environment variable SUBJECTS_DIR is not set. Exiting."
    exit 1
fi

if [ ! -d "${SUBJECTS_DIR}" ]; then
    echo "${APPTAG} ERROR: The SUBJECTS_DIR environment variable points at '${SUBJECTS_DIR}', but that is not a valid directory. Exiting."
    exit 1
fi



##### Start pipeline #####

for SUBJECT in $SUBJECTS;
do
    if [ ! -d "${SUBJECTS_DIR}/${SUBJECT}" ]; then
        echo "${APPTAG} ERROR: Missing directory for subject $SUBJECT: not found at path '${SUBJECTS_DIR}/${SUBJECT}'. Exiting."
        exit 1
    fi
    echo "${APPTAG} Running mri_surf2surf for left hemisphere..."
    mri_surf2surf --srcsubject fsaverage --trgsubject $SUBJECT --hemi lh --sval-annot ${ATLAS_ANNOT_FILE_LH} --tval "${SUBJECTS_DIR}/${SUBJECT}/label/${OUTPUT_ANNOT_FILE_NAME_LH}"
    echo "${APPTAG} Running mri_surf2surf for right hemisphere..."
    mri_surf2surf --srcsubject fsaverage --trgsubject $SUBJECT --hemi rh --sval-annot ${ATLAS_ANNOT_FILE_RH} --tval "${SUBJECTS_DIR}/${SUBJECT}/label/${OUTPUT_ANNOT_FILE_NAME_RH}"
    echo "${APPTAG} Running mri_aparc2aseg..."
    mri_aparc2aseg --s $SUBJECT --annot "${OUTPUT_ANNOT_FILE_NAME_NO_HEMI_NO_EXT}" --o "${SUBJECTS_DIR}/${SUBJECT}/mri/${OUTPUT_SEGMENTATION_FILE_NAME}"
done
