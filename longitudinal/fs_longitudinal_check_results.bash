#!/bin/bash
#
# This scripts checks for all given subjects whether the computation of measure differences between
#  timepoints (Part III of the longitudinal pipeline script) finished and the expected files were written to disk.
#
# Written by Tim Schaefer, 2021-10-06

apptag="[CHECK_LONG_OUTPUT]"
subjects_file="$1"
measure="$2"
subjects_dir="$3"

start_time=$(date "+%Y-%m-%d_%H-%M-%S")

if [ -z "$measure" ]; then
  echo "USAGE: $0 <subjects_file> <measure> [<subjects_dir>]"
  echo "  <subjects_file> : path to a text file containing one subject per line."
  echo "  <measure>       : the neuroanatomical measure, e.g., 'thickness' or 'area'."
  echo "  <subjects_dir>  : optional, the subjects directory. Default to current directory if omitted."
  echo "Example: $0 subjects.txt thickness ~/data/study1"
  exit 0
fi

if [ -z "$subjects_dir" ]; then
  subjects_dir=$(pwd)
fi

if [ ! -f "$subjects_file" ]; then
    echo "$APPTAG ERROR: Subjects file '$subjects_file' not found."
    exit 1
fi

if [ ! -d "$subjects_dir" ]; then
    echo "$APPTAG ERROR: Subjects dir '$subjects_dir' not found."
    exit 1
fi


# Check for borken line endings (Windows line endings, '\r\n') in subjects.txt file, a very common error.
# This script can cope with these line endings, but we still warn the user because other scripts may choke on them.
num_broken_line_endings=$(grep -U $'\015' "${subjects_file}" | wc -l | tr -d '[:space:]')
if [ $num_broken_line_endings -gt 0 ]; then
    echo "$apptag WARNING: Your subjects file '${subjects_file}' contains $num_broken_line_endings incorrect line endings (Windows style line endings)."
    echo "$apptag WARNING: (cont.) While this script can work with them, you will run into trouble sooner or later, and you should definitely fix them (use  the 'tr' command or a proper text editor)."
fi

subjects=$(cat "${subjects_file}" | tr -d '\r' | tr '\n' ' ')    # fix potential windows line endings (delete '\r') and replace newlines by spaces as we want a list
num_subjects=$(echo "${subjects}" | wc -w | tr -d '[:space:]')

echo "$apptag Checking FreeSurfer longitudinal output for $num_subjects subjects: measure '$measure' in directory '$subjects_dir'."

outtypes="spc pc1 rate avg"
fwhms="0 5 10 15 20 25"

echo "$apptag  - Expected output types : '$outtypes'"
echo "$apptag  - Expected fwhms        : '$fwhms'"

subjects_missing_something=""
subjects_missing_input=""
subjects_missing_output=""

for subject in $subjects; do

  subject_is_missing_input="no"
  subject_num_input_files_missing=0
  ## Check the required input files.
  sjd_MR1_surf="${subjects_dir}/${subject}_MR1.long.${subject}/surf"
  sjd_MR2_surf="${subjects_dir}/${subject}_MR2.long.${subject}/surf"
  for hemi in lh rh; do
    input_file_MR1="${sjd_MR1_surf}/${hemi}.${measure}"
    if [ ! -f "$input_file_MR1" ]; then
        echo "$APPTAG WARNING: Subject $subject does not even have the expected MR1 input file '$input_file_MR1' for computing slopes."
        subject_is_missing_input="yes"
        subject_num_input_files_missing=$((subject_num_input_files_missing+1))
    fi
    input_file_MR2="${sjd_MR2_surf}/${hemi}.${measure}"
    if [ ! -f "$input_file_MR2" ]; then
        echo "$APPTAG WARNING: Subject $subject does not even have the expected MR2 input file '$input_file_MR2' for computing slopes."
        subject_is_missing_input="yes"
        subject_num_input_files_missing=$((subject_num_input_files_missing+1))
    fi
  done

  if [ "$subject_is_missing_input" = "yes" ]; then
    num_missing_input=$(echo $subjects_missing_input | wc -w | tr -d '[:space:]') # so far, before the current one.
    if [ $num_missing_input -gt 0 ]; then # avoid extra space for first subject so we can properly split at the end. should use array instead.
      num_missing_input="${num_missing_input} ${subject}"
    else
      num_missing_input="${subject}" # no space here
    fi
  fi

  ## Check the final output files.
  sjd_surf="${subjects_dir}/${subject}/surf"
  if [ ! -d "$sjd_surf" ]; then
      echo "$APPTAG ERROR: Subject $subject does not even have a surf/ directory at '$sjd_surf'. Wrong subjects file?"
      exit 1
  fi
  subject_is_missing_output="no"
  subject_num_output_files_missing=0
  for hemi in lh rh; do
    for outtype in $outtypes; do
      for fwhm in $fwhms; do
        expected_file="${sjd_surf}/${hemi}.long.${measure}-${outtype}.fwhm${fwhm}.mgh"
        if [ ! -f "${expected_file}" ]; then
          #echo "$APPTAG Info: Subject ${subject} is missing expected file ${expected_file}."
          subject_is_missing_output="yes"
          subject_num_output_files_missing=$((subject_num_output_files_missing+1))
        fi
      done
    done
  done
  if [ "$subject_is_missing_output" = "yes" -o "$subject_is_missing_input" = "yes" ]; then
    echo "$apptag Subject $subject is missing $subject_num_output_files_missing output files and $subject_num_input_files_missing input files."
    subjects_missing_something="${subjects_missing_something} ${subject}"
    if [ "$subject_is_missing_output" = "yes" ]; then
        num_missing_output=$(echo $subjects_missing_output | wc -w | tr -d '[:space:]') # so far, before the current one.
        if [ $num_missing_output -gt 0 ]; then # avoid extra space for first subject so we can properly split at the end. should use array instead.
            subjects_missing_output="${subjects_missing_output} ${subject}"
        else
            subjects_missing_output="${subject}" # no space here
        fi
    fi
  else
    echo "$apptag Subject $subject is okay."
  fi
done

num_missing=$(echo $subjects_missing_something | wc -w | tr -d '[:space:]')
num_missing_input=$(echo $subjects_missing_input | wc -w | tr -d '[:space:]')
num_missing_output=$(echo $subjects_missing_output | wc -w | tr -d '[:space:]')

echo "$apptag There are $num_missing of $num_subjects subjects missing some file: '$subjects_missing_something'."
echo "$apptag There are $num_missing_input of $num_subjects subjects missing some required input file: '$subjects_missing_input'."

if [ $num_missing_output -gt 0 ]; then
    subject_missing_output_filename="subjects_missing_output_${measure}_${start_time}.txt"
    echo "$subjects_missing_output" | tr ' ' '\n' > "${subject_missing_output_filename}"
    echo "$apptag The $num_missing_output subjects missing output files are listed in file '$subject_missing_output_filename'."
fi

if [ $num_missing_input -gt 0 ]; then
  echo "$apptag WARNING: You have subjects missing required input files!"
  echo "$apptag Notes for your $num_missing_input subjects missing input files:"
  echo "$apptag  * For subjects which are missing input files, there is no point in trying to re-run the pipeline."
  echo "$apptag  * Keep in mind that the input files for the long pipeline are the native space files in the"
  echo "$apptag    long subject folders (e.g., 'subject1_MR1.long.subject1/surf/lh.thickness' and the respective rh file, and"
  echo "$apptag    the respective 2 files for the MR2 timepoint in the 'subject1_MR2.long.subject1/surf' folder."
  echo "$apptag  * The slopes computation will stop if a subject fails, so if you have subjects missing input files"
  echo "$apptag    in the QDEC table, the pipeline WILL definitely fail as soon as it hits the first of these subjects."
  echo "$apptag    You will have to exclude the subjects or generate the input files before running slopes computation."
  subject_missing_input_filename="subjects_missing_input_${measure}_${start_time}.txt"
  echo "$subjects_missing_input" | tr ' ' '\n' > "${subject_missing_input_filename}"
  echo "$apptag The $num_missing_input subjects missing input files are listed in file '$subject_missing_input_filename'."
fi
end_time=$(date "+%Y-%m-%d_%H-%M-%S")
echo "$apptag Started at $start_time, done at $end_time."
exit 1
