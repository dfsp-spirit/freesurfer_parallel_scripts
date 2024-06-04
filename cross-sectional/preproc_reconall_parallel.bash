#!/bin/bash
## preproc_reconall_parallel.bash -- Perform the FreeSurfer recon-all structural MRI pipeline for a number of subjects in parallel, based on a directory with nifti (.nii) files.
## Written by Tim Schäfer, 2018-11-22
##
## This script uses GNU Parallel to fully utilize all cores of your machine.
## You also need FreeSurfer, of course.
#
# It is strongly recommended to run this script from a 'GNU screen' session with the 'screen' command to ensures it continues running on the remote machine when your
# local PC/MAC restarts for system updates or you accidently close the terminal window. E.g., start a session named "reconENIGMA" with 'screen -S reconENIGMA'. Make sure
# FreeSurfer is setup correctly in the session before running.

# Set SUBJECTS_DIR environment variable. This is require for the recon-all FreeSurfer command.
export SUBJECTS_DIR=$(pwd)
APPTAG="[PREPROC_PARALLEL]"

## Default settings. Do NOT adapt these, simply use command line arguments instead! There is no need to edit this script. ##

exec_path_of_this_script=$(dirname $0)

DO_CREATE_FREESURFER_DIR_STRUCTURE="yes"                  # Will create directory structure and the subjects.txt file. You need to do this for recon-all to work (unless you have already done it earlier).
DO_CREATE_SUBJECTS_FILE="yes"                             # Whether to scan dir for NIFTI files and create a subject file in case none exists (see below).
DO_KEEP_EXISTING_SUBJECTS_FILE="yes"                      # Whether to keep an existing subjects file in case it exists (even if DO_CREATE_SUBJECTS_FILE is yes)
DO_RUN_RECON_ALL="yes"                                    # This will run FreeSurfer. Takes several hours per subject, depending on your hardware. Assume roughly 12h for 2018 hardware.
DO_CHECK_FOR_COMPLETION="no"
FINISH_NOTIFICATION_EMAIL_ADDRESS="none"                  # set to "none" if you do not want an email. Using this requires a working sendmail/MX setup on the workstation.
NUM_CORES_TO_USE=47                                       # Should be slighly *below* total core count. If you use all, it will be a pain to anything on the machine while this runs. Leave 1 or 2 cores alone.
SUBJECTS_FILE="subjects.txt"                              # name of subjects file that will be generated (and used) by this script
SCRIPT_FOR_SINGLE_SUBJECT="preproc_reconall_single_subject.bash"   # Only the file name, the full path to thisis derived exec path of this script (i.e., it must be in the same dir as this script, no matter where this script is called from).

## End of settings. Do not mess with stuff below unless you know what you are doing.



## Parse command line arguments
MODE=$1
if [ -z $MODE ]; then
    NUM_SYS_CORES=$(getconf _NPROCESSORS_ONLN)
    echo "$APPTAG preproc_reconall_parallel -- Run FreeSurfer Pre-processing in parallel over many subjects"
    echo "$APPTAG USAGE: $0 <mode> [<num_cpu> [<email>] [<subjects_file>]]]"
    echo "$APPTAG     <mode>    : One of 'fsdir', 'recon', 'fsdir+recon' or 'status'."
    echo "$APPTAG     <num_cpu> : Number of CPUs to use for parallel, optional. Put the number of cores your machine has minus one. Defaults to 20 if omitted. Note: This system seems to have ${NUM_SYS_CORES} cores."
    echo "$APPTAG     <email>   : Email to notify when recon-all completed, optional. Requires working sendmail setup. Ignored in all modes which do not include 'recon'. Supply 'none' if you dont want emails."
    echo "$APPTAG     <subjects_file> : custom subjects file name to use. Optional. Will be created based on dir contents if it does not exist yet."
    echo "$APPTAG EXAMPLES"
    echo "$APPTAG     - Run complete pipeline (first dir creation, then recon-all) using 10 cores and report to me@blah.de using sendmail when it finished:"
    echo "$APPTAG         $0 fsdir+recon 10 me@blah.de"
    echo "$APPTAG     - Create FreeSurfer output directory structure only, using 5 cores:"
    echo "$APPTAG         $0 fsdir 5"
    echo "$APPTAG     - Run recon-all only, i.e., without first creating the FreeSurfer output directory structure, using 15 cores (will fail unless the dir structure already exists):"
    echo "$APPTAG         $0 recon 15"
    echo "$APPTAG     - When the pipeline is running, check its status (from another shell, in the same working directory):"
    echo "$APPTAG         $0 status"
    exit 1
else
    if [ $MODE = 'fsdir' ]; then
        echo "$APPTAG Running the FreeSurfer directory structure creation only."
        DO_RUN_RECON_ALL="no"
    elif [ $MODE = 'recon' ]; then
        echo "$APPTAG Running only recon-all. (The FreeSurfer directory structure should already be present for all subjects.)"
        DO_CREATE_FREESURFER_DIR_STRUCTURE="no"
    elif [ $MODE = 'fsdir+recon' ]; then
        echo "$APPTAG Running both FreeSurfer directory structure creation and recon-all."
    elif [ $MODE = 'status' ]; then
        echo "$APPTAG Checking status only."
        DO_CREATE_FREESURFER_DIR_STRUCTURE="no"
        DO_CREATE_SUBJECTS_FILE="no"
        DO_RUN_RECON_ALL="no"
        DO_CHECK_FOR_COMPLETION="yes"
    else
        echo "$APPTAG ERROR: Invalid mode: '$MODE'. Run without any arguments to see usage help. Exiting."
        exit 1
    fi

    if [ -n "$2" ]; then
        NUM_CORES_TO_USE=$2
    fi

    if [ ! $MODE = 'status' ]; then
        echo "$APPTAG Using ${NUM_CORES_TO_USE} cores."
    fi

    if [ -n "$3" ]; then
        FINISH_NOTIFICATION_EMAIL_ADDRESS=$3
    fi

    if [ -n "$4" ]; then
        SUBJECTS_FILE=$4
    fi

    if [ $MODE = "recon" -o $MODE = "fsdir+recon" ]; then
        if [ -n ${FINISH_NOTIFICATION_EMAIL_ADDRESS} ]; then
            echo "$APPTAG Will send email to ${FINISH_NOTIFICATION_EMAIL_ADDRESS} once recon-all finished."
        else
            echo "$APPTAG Not sending any notification email, no e-mail address given."
        fi
    fi
fi



## Start script
echo "$APPTAG Starting in mode '$MODE'. Using subjects file '$SUBJECTS_FILE'."
#NUM_NII_FILES=$(find . -name "*.nii" -depth 1 | wc -l | tr -d '[:space:]') # macos
NUM_NII_FILES=$(find . -name "*.nii" | wc -l | tr -d '[:space:]') # macos

# Check for GNU parallel
PARALLEL_BINARY=$(which parallel)
if [ -z "${PARALLEL_BINARY}" ]; then
    echo "$APPTAG ERROR: Could not find 'parallel' on the PATH. Ensure that 'GNU Parallel' is installed. Exiting."
    exit 1
fi


## Create FreeSurfer Directory Structure
if [ ${DO_CREATE_FREESURFER_DIR_STRUCTURE} = "yes" ]; then
    if [ ${NUM_NII_FILES} -lt 1 ]; then
        echo "$APPTAG ERROR: No niftii files found, cannot create directory structure. Exiting."
        exit 1
    fi
    echo "$APPTAG Creating FreeSurfer directory structure for $NUM_NII_FILES detected niftii files."
	ls *.nii | parallel -S $NUM_CORES_TO_USE/: "recon-all -sd `pwd` -i {} -s {.}"
else
    echo "$APPTAG NOT creating dir structure."
fi

## Create subjects.txt file
if [ ${DO_CREATE_SUBJECTS_FILE} = "yes" ]; then
    if [ $DO_KEEP_EXISTING_SUBJECTS_FILE = "yes" -a -f "$SUBJECTS_FILE" ]; then
        NUM_IN_EXISING_FILE=$(cat ${SUBJECTS_FILE} | wc -l | tr -d '[:space:]')
        echo "$APPTAG Using existing subjects file '$SUBJECTS_FILE' containing $NUM_IN_EXISING_FILE subjects."
    else
        if [ ${NUM_NII_FILES} -lt 1 ]; then
            echo "$APPTAG ERROR: No niftii files found, cannot create subjects file. Exiting."
            exit 1
        fi
        echo -n > "$SUBJECTS_FILE"      # Clear contents
        NUM_NII=0
        for NIIFILE in *.nii
        do
            NUM_NII=$((NUM_NII + 1))
            echo ${NIIFILE%.*} >> "$SUBJECTS_FILE"
        done
        echo "$APPTAG Created subjects file '${SUBJECTS_FILE}' with $NUM_NII entries."
    fi
else
    echo "$APPTAG Not creating dir subjects file in mode '$MODE.'"
fi


## Run the script to process a single subject in parallel for all subjects in the subjects file
if [ "${DO_RUN_RECON_ALL}" = "yes" ]; then

    if [ ! -f ${SUBJECTS_FILE} ]; then
        echo "$APPTAG ERROR: Subjects file not found at '${SUBJECTS_FILE}'. Cannot run recon-all, exiting."
        exit 1
    fi

    EXEC_PATH_OF_THIS_SCRIPT=$(dirname $0)
    PATH_TO_SSCRIPT="$EXEC_PATH_OF_THIS_SCRIPT/$SCRIPT_FOR_SINGLE_SUBJECT"
    if [ ! -f "$PATH_TO_SSCRIPT" ]; then
        echo "$APPTAG ERROR: Script to process a single subject '${SCRIPT_FOR_SINGLE_SUBJECT}' not found."
        exit 1
    fi

    NUM_SUBJECTS=$(cat ${SUBJECTS_FILE} | wc -l | tr -d '[:space:]')
    echo "$APPTAG Running recon-all in parallel for ${NUM_SUBJECTS} subjects."

    # Delete the old log files (which will exist from the create dir structure run of recon-all).
    SUBJECTS=$(cat ${SUBJECTS_FILE} | tr '\n' ' ')
    for SUBJECT_ID in $SUBJECTS; do
        RECONALL_LOGFILE="${SUBJECT_ID}/scripts/recon-all.log"
        if [ -f "${RECONALL_LOGFILE}" ]; then
            rm "${RECONALL_LOGFILE}"
        fi
    done

	cat ${SUBJECTS_FILE} | parallel --workdir . --joblog LOGFILE.txt "$PATH_TO_SSCRIPT {}"

    if [ -n "${FINISH_NOTIFICATION_EMAIL_ADDRESS}" -a "${FINISH_NOTIFICATION_EMAIL_ADDRESS}" != "none"  ]; then

        # Check for sendmail
        SENDMAIL_BINARY=$(which sendmail)
        if [ -z "${SENDMAIL_BINARY}" ]; then
            echo "$APPTAG ERROR: Could not find 'sendmail' on the PATH. Ensure that sendmail is installed and configured. Cannot send completion email."
        fi

        TMP_MAIL_FILE="email.txt"
        echo "Subject: FreeSurfer pre-processing for ${NUM_SUBJECTS} in directory `pwd` finished. Please check the status for all subjects." > ${TMP_MAIL_FILE}
        sendmail ${FINISH_NOTIFICATION_EMAIL_ADDRESS}  < ${TMP_MAIL_FILE} && rm ${TMP_MAIL_FILE}
    fi
else
    echo "$APPTAG NOT running recon-all in mode '$MODE'."
fi

## Check for completion
if [ ${DO_CHECK_FOR_COMPLETION} = "yes" ]; then
    if [ ! -f ${SUBJECTS_FILE} ]; then
        echo "$APPTAG ERROR: Subjects file not found at '${SUBJECTS_FILE}'. Cannot check subjects for completion. Are you in the correct working directory?"
        exit 1
    fi

    echo "$APPTAG Gathering subjects from subjects file '${SUBJECTS_FILE}'..."
    SUBJECTS=$(cat ${SUBJECTS_FILE} | tr '\n' ' ')
    NUM_SUBJECTS=$(cat ${SUBJECTS_FILE} | wc -l | tr -d '[:space:]')
    echo "Checking status for $NUM_SUBJECTS subjects in subjects file '$SUBJECTS_FILE'."
    NUM_NOT_YET_RUNNING=0
    NUM_STILL_RUNNING=0
    NUM_FINISH_OK=0
    NUM_FINISH_ERROR=0
    NUM_SUBJECT_DIR_MISSING=0
    for SUBJECT_ID in $SUBJECTS; do
        RECONALL_LOGFILE="${SUBJECT_ID}/scripts/recon-all.log"
        if [ -f "${RECONALL_LOGFILE}" ]; then
            # The last line in the FreeSurfer recon-all log looks similar to this if the subject was processed successfully:
            #   'recon-all -s 101414625982_wm finished without error at Wed Nov  7 05:03:36 CET 2018'
            # In case of errors, the output will look like this (last 3 lines, 2nd is empty):
            #   recon-all -s H03511009 exited with ERRORS at Tue Dec 11 13:27:19 CET 2018
            #
            #   To report a problem, see http://surfer.nmr.mgh.harvard.edu/fswiki/BugReporting
            LOG_STATUS_LINE=$(tail -1 "${RECONALL_LOGFILE}" | tr -d '[:space:]')
            if [[ "$LOG_STATUS_LINE" == *"finishedwithouterror"* ]]; then
                echo "${SUBJECT_ID} finished: OK"
                NUM_FINISH_OK=$((NUM_FINISH_OK + 1))
            elif [[ "$LOG_STATUS_LINE" == *"reportaproblem"* ]]; then
                echo "${SUBJECT_ID} finished: ERRORS"
                NUM_FINISH_ERROR=$((NUM_FINISH_ERROR + 1))
            else
                echo "${SUBJECT_ID} still running (or aborted by user/power failure/whatever)."
                NUM_STILL_RUNNING=$((NUM_STILL_RUNNING + 1))
            fi
        else
            echo "${SUBJECT_ID} not started yet: could not find recon-all log file."
            NUM_NOT_YET_RUNNING=$((NUM_NOT_YET_RUNNING + 1))
            if [ ! -d "$SUBJECT_ID" ]; then
                echo "$APPTAG WARNING: Subject directory for subject '$SUBJECT_ID' not found."
                NUM_SUBJECT_DIR_MISSING=$((NUM_SUBJECT_DIR_MISSING + 1))
            fi
        fi
    done
    NUM_NOT_FINISHED=$(echo "$NUM_NOT_YET_RUNNING + $NUM_STILL_RUNNING" | bc)
    NUM_FINISHED=$(echo "$NUM_FINISH_OK + $NUM_FINISH_ERROR" | bc)
    echo "$APPTAG STATUS: Recon-all started for ${NUM_SUBJECTS} subjects total. Not finished: $NUM_NOT_FINISHED ($NUM_NOT_YET_RUNNING not started yet, $NUM_STILL_RUNNING still running or aborted)."
    echo "$APPTAG STATUS: Finished: $NUM_FINISHED ($NUM_FINISH_OK OK, $NUM_FINISH_ERROR finished with errors.)"
    if [ $NUM_SUBJECT_DIR_MISSING -gt 0 ]; then
        echo "$APPTAG STATUS: WARNING: For $NUM_SUBJECT_DIR_MISSING subjects in the subjects file, the subject directory does not exist. These subjects are part of the $NUM_NOT_YET_RUNNING subjects which were counted as 'not started yet'."
    fi
fi

echo "$APPTAG All done. Exiting."
