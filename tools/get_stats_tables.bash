#!/bin/bash

### Settings ###
python2_bin=$(which python2)
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

if [ -z "$python2_bin" ]; then
    echo "ERROR: Could not autodetect path to python2 binary, please adapt setting 'python2_bin' in this script."
    exit 1
fi

if [ ! -x "$python2_bin" ]; then
    echo "ERROR: Cannot execute python2 binary at '$python2_bin'"
    exit 1
fi


#### run commands

subjects=$(cat $subjects_file | tr '\n' ' ')
num_subjects=$(echo "${subjects}" | wc -w | tr -d '[:space:]')

echo "Getting stats for $num_subjects subjects."

for hemi in lh rh; do
    for measure in thickness area; do
        aparc_output_table="${hemi}.aparc_table_${measure}.tsv"
        $python2_bin $aparcstats2table_bin --subjectsfile $subjects_file --meas $measure --hemi $hemi -t $aparc_output_table && echo " * output file '$aparc_output_table' written."
    done

    aseg_output_table="aseg_table.tsv"
    $python2_bin $asegstats2table_bin --subjectsfile $subjects_file -t $aseg_output_table && echo " * output file '$aseg_output_table' written."
done

echo "All done, exiting."
exit 0
