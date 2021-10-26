#!/bin/bash
# parallel_gen_mid_surface_inner_cargo.bash -- generate mid surface and standard measures for it.
# Note that you can run this from parallel_gen_mid_surface.bash to apply it to several subjects in parallel.

APPTAG="[MIDSURF_INNER]"

if [ -z "$1" ]; then
  echo "$APPTAG ERROR: Arguments missing."
  echo "$APPTAG Usage: $0 <subject>"
  echo "$APPTAG Note that the environment variable SUBJECTS_DIR must also be set correctly."
  exit 1
else
  SUBJECT="$1"
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


##### OK, lets go: Create the surfaces #####

THICKNESS_LEVEL="0.5"         # part of thickness to use from white to pial. 0 would be a duplicate of white, 0.5 would be halfway from white to pial, 1.0 would be a duplicate of pial.
SURF_NAME="mid"              # "mid" will lead to "lh.mid" and "rh.mid" as surface file names

LH_EXPECTED_OUTPUT_SURFACE="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.${SURF_NAME}"
RH_EXPECTED_OUTPUT_SURFACE="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.${SURF_NAME}"

cd "${SUBJECTS_DIR}/${SUBJECT}/surf/"

if [ -f "${LH_EXPECTED_OUTPUT_SURFACE}" -a -f "${RH_EXPECTED_OUTPUT_SURFACE}" ]; then
    echo "$APPTAG Surface done already for subject '${SUBJECT}', skipping."
else
    echo "$APPTAG Surface not done yet for subject '$SUBJECT.' Running..."
    mris_expand -thickness lh.white ${THICKNESS_LEVEL} lh.${SURF_NAME}
    mris_expand -thickness rh.white ${THICKNESS_LEVEL} rh.${SURF_NAME}
fi

##### Now compute the area of the new surfaces #####

if [ ! -f "${LH_EXPECTED_OUTPUT_SURFACE}" ]; then
    echo "$APPTAG ERROR: Required lh surface file '${LH_EXPECTED_OUTPUT_SURFACE}' missing. Should have been created in last step. Exiting."
    exit 1
fi
if [ ! -f "${RH_EXPECTED_OUTPUT_SURFACE}" ]; then
    echo "$APPTAG ERROR: Required rh surface file '${RH_EXPECTED_OUTPUT_SURFACE}' missing. Should have been created in last step. Exiting."
    exit 1
fi

LH_EXPECTED_OUTPUT_AREA_FILE="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.area.${SURF_NAME}.mgh"
RH_EXPECTED_OUTPUT_AREA_FILE="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.area.${SURF_NAME}.mgh"

mri_surf2surf --s ${SUBJECT} --sval-area ${SURF_NAME} --hemi lh --trgval lh.area.${SURF_NAME}.mgh
mri_surf2surf --s ${SUBJECT} --sval-area ${SURF_NAME} --hemi rh --trgval rh.area.${SURF_NAME}.mgh

if [ ! -f "${LH_EXPECTED_OUTPUT_AREA_FILE}" ]; then
    echo "$APPTAG ERROR: lh area file '${LH_EXPECTED_OUTPUT_AREA_FILE}' missing. Should have been created in last step. Exiting."
    exit 1
fi
if [ ! -f "${RH_EXPECTED_OUTPUT_AREA_FILE}" ]; then
    echo "$APPTAG ERROR: rh area file '${RH_EXPECTED_OUTPUT_AREA_FILE}' missing. Should have been created in last step. Exiting."
    exit 1
fi

# Note that we do not compute the thickness and volume files here. Thickness is trivial (we set it to 0.5 of the lh/rh.thickness value),
#  and volume can be computed from thickness and area. Curvature can be computed for the new surface using mris_curvature.
