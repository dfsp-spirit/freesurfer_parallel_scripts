# Neuroimaging BASH functions.
# Written by Tim Schaefer.
#
# USAGE:
# You should source this file in your scripts or in your shell startup config file. Then you can use the functions in your scripts or on the command line.
# Do NOT run this file, it's not gonna help.

# Example:
# $ source ni_bash_functions.bash
# $ create_subjectsfile_from_subjectsdir /Applications/freesurfer/subjects ~/fs_subjects_list.txt

create_subjectsfile_from_subjectsdir () {
    ## Function to find all valid FreeSurfer subjects in a SUBJECTS_DIR and create a SUBJECTS_FILE from the list.
    ## This function will check all subdirs of the given SUBJECTS_DIR for the typical FreeSurfer sub directory 'mri'.
    ## All sub dirs which contain it are considered subjects, and added to the list in the SUBJECTS_FILE.
    ## Note that a SUBJECTS_FILE is a text file containing one subject per line.
    ##
    ## This function can be used in scripts, and is thus a lot better than first running `ls -1 > subejcts.txt` in the
    ## directory and them manually removing all invalid entries (other files/dirs in the SUBJECTS_DIR, including
    ## at least the file subjects.txt itself) manually with a text editor.
    ##
    ## USAGE: create_subjectsfile_from_subjectsdir <SUBJECTS_DIR> <SUBJECTS_FILE> [<DO_SUBDIR_CHECK>]
    ## where <DO_SUBDIR_CHECK> is optional, and must be "YES" or "NO". Defaults to "YES".
    local SUBJECTS_DIR=$1
    local SUBJECTS_FILE=$2
    local DO_SUBDIR_CHECK=$3
    if [ -z "${SUBJECTS_DIR}" ]; then
        echo "ERROR: make_subjectsfile_in_subjectsdir(): Missing required 1st function parameter 'SUBJECTS_DIR'."
        return 1
    fi
    if [ -z "${SUBJECTS_FILE}" ]; then
        echo "ERROR: make_subjectsfile_in_subjectsdir(): Missing required 2nd function parameter 'SUBJECTS_FILE'."
        return 1
    fi
    if [ ! -d "${SUBJECTS_DIR}" ]; then
        echo "ERROR: make_subjectsfile_in_subjectsdir(): The given SUBJECTS_DIR '$SUBJECTS_DIR' does not exist or is not readable."
        return 1
    fi
    if [ -z "$DO_SUBDIR_CHECK" ]; then
        DO_SUBDIR_CHECK="YES"
    fi
    if [ "$DO_SUBDIR_CHECK" = "YES" ]; then
        echo "INFO: make_subjectsfile_in_subjectsdir(): Performing check for 'mri' subdir."
    else
        if [ "$DO_SUBDIR_CHECK" = "NO" ]; then
            echo "INFO: make_subjectsfile_in_subjectsdir(): NOT performing check for 'mri' subdir."
        else
            echo "ERROR: make_subjectsfile_in_subjectsdir(): Invalid parameter DO_SUBDIR_CHECK, must be 'YES' or 'NO' if given."
            return 1
        fi
    fi

    CURDIR=$(pwd)
    cd "${SUBJECTS_DIR}"
    VALID_FREESURFER_SINGLE_SUBJECT_DIRS=""
    SUBDIRS=$(ls -d */)
    NUM_SUBJECTS_FOUND=0
    if [ -n "$SUBDIRS" ]; then   # There may not be any.
        for SDIR in $SUBDIRS; do
            SDIR=${SDIR%/}     # strip potential trailing slash, which would otherwise become part of the subject ID.
            if [ "${DO_SUBDIR_CHECK}" = "NO" -o -d "${SDIR}/mri/" ]; then
                NUM_SUBJECTS_FOUND=$((NUM_SUBJECTS_FOUND+1))
                if [ -n "${VALID_FREESURFER_SINGLE_SUBJECT_DIRS}" ]; then
                    VALID_FREESURFER_SINGLE_SUBJECT_DIRS="${VALID_FREESURFER_SINGLE_SUBJECT_DIRS} "   # Add space for separation unless this is the first entry.
                fi
                VALID_FREESURFER_SINGLE_SUBJECT_DIRS="${VALID_FREESURFER_SINGLE_SUBJECT_DIRS}${SDIR}"
            fi
        done
    fi
    echo "Found ${NUM_SUBJECTS_FOUND} FreeSurfer subjects under dir '${SUBJECTS_DIR}', writing subjects file '${SUBJECTS_FILE}'."
    # Currently the dirs are separated by spaces, but we want them separated by newlines
    FSDIR_PER_LINE=$(echo "${VALID_FREESURFER_SINGLE_SUBJECT_DIRS}" | tr ' ' '\n')
    cd "${CURDIR}" && echo "${FSDIR_PER_LINE}" > "${SUBJECTS_FILE}"
    return 0
}
