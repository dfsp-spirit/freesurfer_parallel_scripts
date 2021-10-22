#!/bin/bash
#
# This script runs the longitudinal FreeSurfer pipeline for all subjects in
# the current directory.
#
# It expects the following input:
#  - For each subject, you need to have MRI data that has already been pre-processed
#    in FreeSurfer with the standard (cross-sectional) recon-all command for both
#    timepoints. The 2 recon-all output directories must be named <subjectid>_MR1 and
#    <subjectid>_MR2. The '_MR1' and '_MR2' part at the end is mandatory!
#
# See the comments below after the steps for the produced output of this script.
#
#
# Written by Tim Schaefer, 2021-10-06
#
#
############## USAGE INFORMATION
# 1) Make sure GNU parallel is installed and adapt the number of cores below.
# 2) Run in the directory with the input prepared as mentioned above without any arguments to see help.
#
# This takes several hours for each input directory, depending on which parts you run, see comments below.


##################### Settings -- adapt to your system and needs ################

do_run_part1="NO"
do_run_part2="NO"
do_run_part3="YES" # Do not forget to set the 'measures' to compute below.
do_run_part3_in_parallel="YES" # Whether to use highly parallel version for part 3. This is much faster on multi-core systems and recommended.


nodes=44                      # The number of CPU cores to use. Adapt to your machine.

## The following settings are used in part3 only, you can ignore them if you do not run that part.
python2_command="python2"     # The command that calles a python2 interpreter (not python3, which is often what the command 'python' points to on modern systems).
measures="thickness"          # <=== Adapt this. Can be a list, e.g., measures="thickness area volume".


############################## End of settings #################################


export SUBJECTS_DIR=`pwd`

apptag="[FS_LONG]"
echo "$apptag Running in directory '$SUBJECTS_DIR' with '$nodes' CPU cores."

## You may want to run the parts below one after the other and check
##  intermediate results manually inbetween.



##### Determine for which subjects to run.
subjects_file="$1"
if [ -z "$subjects_file" ]; then
    echo "USAGE: $0 <subjects_file> | infer [<qdec_table>]"
    echo "  <subjects_file> : path to a text file containing 1 subject per line. (The file cannot be named 'infer', see below.) Used in Part I and II."
    echo "  infer           : alternative to specifying the subjects file, this keyword tells the script to auto-detect subjects in directory from _MR1 prefixes."
    echo "  <qdec_table>    : optional, the QDEC table file to use in Part III. Defaults to './qdec/long.qdec.table.dat'. Used in Part III only."
    echo "NOTE: You may want to adapt some settings in the script header, e.g., which parts to run and what measures to compute slopes for in part III."
    exit 1
fi

qdec_file="$2"
if [ -z "$qdec_file" ]; then
  qdec_file="./qdec/long.qdec.table.dat"
fi


if [ "$do_run_part1" = "YES" -o "$do_run_part2" = "YES" ]; then
  if [ "$subjects_file" = "infer" ]; then
      subjects_by_line=$(ls -d *_MR1 | cut -f 1 -d '_')
  else
      if [ ! -f "$subjects_file" ]; then
          echo "$apptag ERROR: Subjects file '$subjects_file' does not exist or cannot be read."
          exit 1
      fi
      subjects_by_line=$(cat "$subjects_file")
      # check for subject directories
      subjects_list=$(echo $subjects_by_line | tr '\n' ' ')
      echo "subjects list: $subjects_list"
      for subject in $subjects_list; do
          sjd="${SUBJECTS_DIR}/${subject}"
          if [ ! -d "$sjd" ]; then
              echo "$apptag ERROR: The directory for subject $subject does not exist at expected path '$sjd'. Please check your subjects file."
              exit 0
          fi
      done
  fi

  num_subjects=$(echo "${subjects_by_line}" | wc -l | tr -d '[:space:]')
fi



################################################################################
############################### Part I #########################################
################################################################################

## Create within-subject template.
## This produces the directory '<subjectid>' (the base template) from '<subjectid>_MR1' and '<subjectid>_MR2'.
## It takes a bit longer than a typical full recon-all cross-sectional run. You should expect this to run very roughly 16 hours per subject (on a single core), depending on your hardware.

if [ "${do_run_part1}" = "YES" ]; then
  echo "$apptag Running part I: Creation of within-subject template for $num_subjects subjects. This is gonna take a while..."
  echo "subjects: $subjects_by_line"
  echo "$subjects_by_line" | parallel -S ${nodes}/: --workdir . --joblog template.log "recon-all -base {} -tp {}_MR1 -tp {}_MR2 -all -no-isrunning"
else
  echo "$apptag SKIPPING part I as requested"
fi



################################################################################
############################## Part II #########################################
################################################################################

## Run longitudinal pipeline for MR1 and MR2
## This produces the directory '<subjectid>_long.MR1.<subject_id>'.
## This takes about 5 hours per subject per run (5h for _MR1, and another 5h for _MR2)
if [ "${do_run_part2}" = "YES" ]; then
  echo "$apptag Running part II: Longitudinal pipeline for $num_subjects subjects."
  echo "$apptag  - Running step IIa: Handling timepoint MR1"
  echo "$subjects_by_line" | parallel -S ${nodes}/: --workdir . --joblog MR1_longitudinal.log "recon-all -long {}_MR1 {} -all -no-isrunning"
  ## This produces the directory '<subjectid>_long.MR2.<subject_id>'.
  echo "$apptag  - Running step IIb: Handling timepoint MR2"
  echo "$subjects_by_line" | parallel -S ${nodes}/: --workdir . --joblog MR2_longitudinal.log "recon-all -long {}_MR2 {} -all -no-isrunning"
else
  echo "$apptag SKIPPING part II as requested"
fi


################################################################################
############################## Part III ########################################
################################################################################

## Produces the slopes for your measureof interest(e.g., cortical thickness) between the timepoints.
## This requires the file 'long.qdec.table.dat', which you will need to create based on the subject demographics (inter-scan period, etc). There is an
##  R function in the 'fsbrain' R package that can make it a lot easier (and less error-prone) to create that file. The function is: fsbrain::demographics.to.qdec.table.dat()
##
## See https://surfer.nmr.mgh.harvard.edu/fswiki/LongitudinalTwoStageModel for information on the table. That table
##  a space-separated, CSV-like text file with columns 'fsid', 'fsid-base' and 'year'. E.g., the first 5 lines could look like (without the bash comment signs '##' at the start):
##
## fsid fsid-base year
## OAS2_0001_MR1 OAS2_0001 0
## OAS2_0001_MR2 OAS2_0001 1.25
## OAS2_0002_MR1 OAS2_0001 0
## OAS2_0002_MR2 OAS2_0001 1.75
##
## More columns are allowed, but these columns (in that order!) must appear first with EXACTLY the column names given above.
##
## This takes about 1 minute per hemisphere per measure per subject (so 2 minutes per subject if you only want
##  the single measure 'thickness' in the loop below). It cannot be parallelized over the subjects though, because the
##  long_mris_slopes tool handles the whole qdec table and is sequential. We do at least parallelize over the 2 hemis below.
##
## IMPORTANT: A few words of warning regarding long_mris_slopes:
##  1) It cannot be run in parallel easily as it works on the whole list, so we only parallelize over hemis (see above).
##  2) It requires python2 and 'python' points to python3 on modern systems, so we manually call it with python2 and the full
##       path to the script below. You may need to adapt the paths to your system.
##  3) Most importantly: it will STOP if it encounters an issue with a single subject, so all subjects after that one in the list
##     will not be handled at all (for that hemi, as we run for the 2 hemis independently via GNU parallel).

if [ "${do_run_part3}" = "YES" ]; then
    #long_mris_slopes_command="long_mris_slopes"
    if [ -z "$FREESURFER_HOME" ]; then
      echo "$apptag Env var FREESURFER_HOME not set, please setup FreeSurfer properly."
      exit 0
    fi
    long_mris_slopes_bin="${FREESURFER_HOME}/bin/long_mris_slopes" # The full path to the 'long_mris_slopes' program that comes with FreeSurfer. If FreeSurfer is setup correctly for the bash shell on your system, you do not need to change anything.
    long_mris_slopes_command="${python2_command} ${long_mris_slopes_bin}"   # Typically evaluates to something like: python2 ${FREESURFER_HOME}/bin/long_mris_slopes


    echo "$apptag  Running part III: Computing slopes of measure data ($measures)."
    qdec_file_time_column="years" # This is the name of the inter-scan time column in the QDEC file. The unit is up to you, it depends on what you want to measure.
    ## ...                         Yearly change seems reasonable, so we assume inter-scan time is given in years by default, and listed in a column named 'year', as in the example above.

    if [ -f "${qdec_file}" ]; then

        qdec_subjects=$(awk '(NR>1)' ${qdec_file} | awk '{print $2}' | uniq | tr '\n' ' ')
        num_qdec_subjects=$(echo "${qdec_subjects}" | wc -w | tr -d '[:space:]')
        subjects_missing_input=""

        echo "$apptag  Handling QDEC file containing $num_qdec_subjects subjects."

        # Check whether the required input files exist to keep long_mris_slopes from crashing once it hits a subject which does not have them.
        has_errors="no"
        for subject in $qdec_subjects; do
          subject_has_errors="no"
          sjd_MR1_surf="${SUBJECTS_DIR}/${subject}_MR1.long.${subject}/surf"
          sjd_MR2_surf="${SUBJECTS_DIR}/${subject}_MR2.long.${subject}/surf"
          for measure in $measures; do
            for hemi in lh rh; do
                input_file_MR1="${sjd_MR1_surf}/${hemi}.${measure}"
                if [ ! -f "$input_file_MR1" ]; then
                    echo "$APPTAG ERROR: Subject $subject does not even have the expected $hemi hemi measure $measure MR1 input file '$input_file_MR1' for computing slopes."
                    has_errors="yes"
                    subject_has_errors="yes"
                fi
                input_file_MR2="${sjd_MR2_surf}/${hemi}.${measure}"
                if [ ! -f "$input_file_MR2" ]; then
                    echo "$APPTAG ERROR: Subject $subject does not even have the expected $hemi hemi measure $measure MR2 input file '$input_file_MR2' for computing slopes."
                    has_errors="yes"
                    subject_has_errors="yes"
                fi
            done
          done
          if [ "$subject_has_errors" = "yes" ]; then
            subjects_missing_input="$subjects_missing_input $subject"
          fi
        done
        if [ "$has_errors" = "yes" ]; then
          num_subjects_missing_input=$(echo "${subjects_missing_input}" | wc -w | tr -d '[:space:]')
          echo "$apptag  ERROR: Detected missing input files, see above. Running long_mris_slopes would fail. Not starting the run."
          echo "$apptag  There are $num_subjects_missing_input of $num_qdec_subjects subjects missing required input files: $subjects_missing_input"
          exit 1
        fi

        if [ "${do_run_part3_in_parallel}" = "YES" ]; then
          # Split the QDEC table into 1 table per subject to allow running slopes in parallel over subjects.
          exec_path_of_this_script=$(dirname $0)
          qdec_split_table_script="${exec_path_of_this_script}/qdec_split_table.bash"
          if [ ! -x "${qdec_split_table_script}" ]; then
            echo "ERROR: QDEC split table script not executable or cannot be read at '${qdec_split_table_script}'. Exiting."
            exit 1
          else # Run the table splitting. This produces one QDEC table per subject in the qdec_output_dir (see below).
            $qdec_split_table_script ${qdec_file}
          fi
          qdec_output_dir=$(dirname "$qdec_file") # This is where the qdec_split_table_script will put the split QDEC table files (one per subject).

          # Check whether all expected tables exist. They are required for the GNU parallel command below.
          for subject in $qdec_subjects; do
            subject_qdec_table_file="${qdec_output_dir}/qdec_subject_table_${subject}.dat"
            if [ ! -f "$subject_qdec_table_file" ]; then
              echo "ERROR: The QDEC table for subject ${subject} was not created at '${subject_qdec_table_file}', cannot run long_mris_slopes. Exiting."
              exit 1
            fi
          done
          for measure in $measures; do
            for hemi in lh rh; do
              echo "$apptag  - Part III: Computing slopes for $num_qdec_subjects subjects and hemi $hemi in parallel over subjects ($nodes cores) for measure '$measure' (of all measures '$measures')."
              echo "$apptag    * Using QDEC tables based on '$qdec_file' with time column '$qdec_file_time_column' (split into 1 table per subject)."
              echo "$qdec_subjects" | tr ' ' '\n' | parallel -S ${nodes}/: --workdir . --joblog long_mris_slopes_${measure}_${hemi}.log "${long_mris_slopes_command} --qdec ${qdec_output_dir}/qdec_subject_table_{}.dat --meas $measure --hemi $hemi --do-avg --do-rate --do-pc1 --do-spc --do-stack --do-label --time ${qdec_file_time_column} --qcache fsaverage --sd $SUBJECTS_DIR"
            done
          done
        else # NOT in parallel over subjects.
          # We compute the 2 hemispheres in parallel for each measure, so we do not need to loop over hemis here.
          for measure in $measures; do
              echo "$apptag  - Part III: Computing slopes for $num_qdec_subjects subjects and both hemis in parallel over hemis (using 2 cores) for measure '$measure' (of all measures '$measures')."
              echo "$apptag    * Using QDEC table '$qdec_file' with time column '$qdec_file_time_column'."
              echo "lh rh" | tr ' ' '\n' | parallel -S ${nodes}/: --workdir . --joblog long_mris_slopes_$measure.log "${long_mris_slopes_command} --qdec ${qdec_file} --meas $measure --hemi {} --do-avg --do-rate --do-pc1 --do-spc --do-stack --do-label --time ${qdec_file_time_column} --qcache fsaverage --sd $SUBJECTS_DIR"
          done
        fi

    else
        echo "$apptag ERROR: The QDEC table file '${qdec_file}' does not exist or cannot be read: cannot produce measure data. Please create it and manually re-run step III of the script only."
        echo "$apptag Note: one can use the fsbrain R package to create the file from a demographics data.frame, see functions qdec.table.skeleton() and demographics.to.qdec.table.dat()."
        exit 0
    fi

else
  echo "$apptag SKIPPING part III as requested"
fi


exit 1
