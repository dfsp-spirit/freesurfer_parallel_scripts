#!/bin/bash
#
# Get aparc stats with FreeSurfer 6.
#
# Note that for FS7, aparcstats is a shell script and must thus not be run with Python anymore,
# it is a wrapper that calls its own Python interpreter in the FREESURFER_HOME.

### Settings ###

# auto-detect FS6 vs FS7.
if [ -z "$FREESURFER_HOME" ]; then
    echo "ERROR: Environment variable FREESURFER_HOME not set, you must export it and point it to your FreeSurfer installation."
    exit 1
fi
grep_res = $(fgrep 'x86_64-stable-pub-v6.' $FREESURFER_HOME/build-stamp.txt)
if [ -n "${grep_res}" ]; then
    is_fs7="no"
else
    is_fs7="yes"
fi

### End of settings ###

apptag="[GET_STATS_TBL]"

if [ "$is_fs7" = "yes" ]; then
  echo "$apptag Assuming FreeSurfer v7 from auto-detection. Please overwrite setting 'is_fs7' manually if this is incorrect. If you are using FreeSurfer 6.x or below, this script will fail later."
else
    echo "$apptag Assuming FreeSurfer v6.x or below from auto-detection. Please overwrite setting 'is_fs7' manually if this is incorrect. If you are using FreeSurfer 7.x., this script will fail later."
fi

#is_fs7="no" # uncomment this line to force FS6 mode.

### Settings ###
python2_bin=$(which python2) # Only needed for FS6.
#python2_bin=/usr/local/bin/python2

###
aparcstats2table_bin=$(which aparcstats2table)
asegstats2table_bin=$(which asegstats2table)

### Command line args ###
subjects_dir=$1
subjects_file=$2

#### sanity checks

if [ -z "$subjects_file" ]; then
    echo "USAGE: $0 <subjects_dir> <subjects_file>"
    exit 1
fi

if [ ! -d $subjects_dir ];  then
    echo "ERROR: Subjects dir '$subjects_dir' does not exist."
    exit 1
fi

if [ ! -f $subjects_file ];  then
    echo "ERROR: Subjects file '$subjects_file' does not exist."
    exit 1
fi

if [ "$is_fs7" != "yes" ]; then

    if [ -z "$python2_bin" ]; then
        echo "ERROR: Could not autodetect path to python2 binary, please adapt setting 'python2_bin' in this script."
        exit 1
    fi

    if [ ! -x "$python2_bin" ]; then
        echo "ERROR: Cannot execute python2 binary at '$python2_bin'"
        exit 1
    fi
fi

export SUBJECTS_DIR="${subjects_dir}"

#### run commands

subjects=$(cat $subjects_file | tr '\n' ' ')
num_subjects=$(echo "${subjects}" | wc -w | tr -d '[:space:]')

echo "Getting stats for $num_subjects subjects."

for hemi in lh rh; do
    for measure in thickness area volume; do # Feel free to add more measures here, see the help of aparcstats2table for options.
        aparc_output_table="${hemi}.aparc_table_${measure}.tsv"
	# You many want to add more command line options to the call in the next line. E.g., '--skip' or '--common-parcs' may come in handy.
        if [ "$is_fs7" = "yes" ]; then
            $aparcstats2table_bin --subjectsfile $subjects_file --meas $measure --hemi $hemi -t $aparc_output_table && echo " * output file '$aparc_output_table' written."
        else
            $python2_bin $aparcstats2table_bin --subjectsfile $subjects_file --meas $measure --hemi $hemi -t $aparc_output_table && echo " * output file '$aparc_output_table' written."
        fi
    done

    aseg_output_table="aseg_table.tsv"
    if [ "$is_fs7" = "yes" ]; then
        $asegstats2table_bin --subjectsfile $subjects_file -t $aseg_output_table && echo " * output file '$aseg_output_table' written."
    else
        $python2_bin $asegstats2table_bin --subjectsfile $subjects_file -t $aseg_output_table && echo " * output file '$aseg_output_table' written."
    fi

done

echo "All done, exiting."
exit 0
