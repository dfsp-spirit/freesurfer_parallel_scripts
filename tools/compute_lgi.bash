#!/bin/bash
# compute_lgi.bash -- Compute local LGI for a subject on the native surface. This does NOT map the result to fsaverage, use the subpar script for that.
# Normally this script should not be called directly, run 'parallel_lgi_native.bash' instead, which calls this script.

APPTAG="[C_LGI]"

if [ -z "$1" ]; then
  echo "$APPTAG ERROR: Arguments missing."
  echo "$APPTAG Usage: $0 <subject>"
  echo "$APPTAG Note that the environment variable SUBJECTS_DIR must also be set correctly."
  exit 1
else
  SUBJECT="$1"
fi

# Whether to run even if the output lgi files already exist. Set to 'YES' for yes, or anything else for no.
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

if [ -z "${MATLABPATH}" ]; then
    echo "$APPTAG WARNING: Environment variable MATLABPATH not set. Set it to your Matlab installation directory."
    echo "$APPTAG: (cont.) Example for BASH: 'export MATLABPATH=/Applications/MATLAB_R2019a.app/'"
fi

MATLAB_BINARY=$(which matlab)
if [ -z "${MATLAB_BINARY}" ]; then
    echo "$APPTAG: ERROR: Matlab executable is not on your path, but that is required by recon-all for lgi computation. Add MATLABPATH/bin/ to your PATH. Exiting."
    echo "$APPTAG: (cont.) Example for BASH: 'export PATH=\$PATH:\$MATLABPATH/bin'"
    exit 1
fi

#### ok, lets go

LH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/lh.pial_lgi"
RH_EXPECTED_OUTPUT="${SUBJECTS_DIR}/${SUBJECT}/surf/rh.pial_lgi"

DO_RUN="YES"
if [ -f "${LH_EXPECTED_OUTPUT}" -a -f "${RH_EXPECTED_OUTPUT}" ]; then
    if [ "$FORCE" != "YES" ]; then
        DO_RUN="NO"
        echo "localGI done already for subject '${SUBJECT}', skipping."
    else
        echo "localGI done already for subject '${SUBJECT}', but FORCE is set, re-running."
    fi
else
    echo "localGI not done yet for subject '$SUBJECT.' Running..."
fi

if [ "$DO_RUN" = "YES" ]; then
    recon-all -s $SUBJECT -no-isrunning -localGI
fi
